import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/local_data_generation_gate.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late AppFileLayout layout;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-data-gate-');
    addTearDown(() => root.delete(recursive: true));
    layout = AppFileLayout(rootPath: p.join(root.path, 'meettrace'));
  });

  File markerFile() {
    return File(
      p.join(layout.rootPath, LocalDataGenerationGate.markerFileName),
    );
  }

  Future<LocalDataGenerationGate> gate({
    Future<String> Function(File marker)? readMarker,
  }) async {
    return LocalDataGenerationGate(
      layout: layout,
      now: () => DateTime.utc(2026, 8, 3),
      readMarker: readMarker ?? (marker) => marker.readAsString(),
    );
  }

  Future<void> seedLegacyInstallation() async {
    await layout.createBaseDirectories();
    await File(layout.databasePath).writeAsString('legacy-db');
    await File(
      p.join(layout.meetingsRoot, 'old-meeting', 'audio', 'fact.pcm'),
    ).create(recursive: true);
    await File(
      p.join(layout.modelsRoot, 'sense-voice', '1', 'model.int8.onnx'),
    ).create(recursive: true);
    await File(
      layout.meetingAudioCheckpointPath('old-meeting'),
    ).create(recursive: true);
  }

  test('首次安装没有标记时只建立基线，不清除任何内容', () async {
    final wiped = await (await gate()).ensureCurrent();

    expect(wiped, isFalse);
    final marker = jsonDecode(await markerFile().readAsString());
    expect(marker['schemaVersion'], 1);
    expect(marker['generation'], LocalDataGenerationGate.currentGeneration);
    expect(await Directory(layout.databaseDirectory).exists(), isTrue);
    expect(await Directory(layout.modelsRoot).exists(), isTrue);
  });

  test('标记与当前数据代一致时保持数据不动', () async {
    await seedLegacyInstallation();
    await markerFile().writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'generation': LocalDataGenerationGate.currentGeneration,
        'updatedAt': '2026-08-03T00:00:00.000Z',
      }),
    );

    final wiped = await (await gate()).ensureCurrent();

    expect(wiped, isFalse);
    expect(await File(layout.databasePath).exists(), isTrue);
    expect(
      await File(
        p.join(layout.modelsRoot, 'sense-voice', '1', 'model.int8.onnx'),
      ).exists(),
      isTrue,
    );
  });

  test('历史安装缺少标记时全清数据库、会议、模型与检查点', () async {
    await seedLegacyInstallation();

    final wiped = await (await gate()).ensureCurrent();

    expect(wiped, isTrue);
    expect(await File(layout.databasePath).exists(), isFalse);
    expect(await Directory(layout.meetingsRoot).list().toList(), isEmpty);
    expect(
      await File(
        p.join(layout.modelsRoot, 'sense-voice', '1', 'model.int8.onnx'),
      ).exists(),
      isFalse,
    );
    expect(
      await File(layout.meetingAudioCheckpointPath('old-meeting')).exists(),
      isFalse,
    );
    // 清场后重建基础目录并写入新标记，启动可直接继续。
    expect(await Directory(layout.databaseDirectory).exists(), isTrue);
    final marker = jsonDecode(await markerFile().readAsString());
    expect(marker['generation'], LocalDataGenerationGate.currentGeneration);
  });

  test('旧数据代标记触发全清', () async {
    await seedLegacyInstallation();
    await markerFile().writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'generation': LocalDataGenerationGate.currentGeneration - 1,
        'updatedAt': '2026-08-01T00:00:00.000Z',
      }),
    );

    final wiped = await (await gate()).ensureCurrent();

    expect(wiped, isTrue);
    expect(await File(layout.databasePath).exists(), isFalse);
  });

  test('标记损坏时按旧数据代处理并全清', () async {
    await seedLegacyInstallation();
    await markerFile().writeAsString('{not-json');

    final wiped = await (await gate()).ensureCurrent();

    expect(wiped, isTrue);
    expect(await File(layout.databasePath).exists(), isFalse);
  });

  test('标记读取发生文件系统异常时阻断启动且保留全部本地数据', () async {
    await seedLegacyInstallation();
    await markerFile().writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'generation': LocalDataGenerationGate.currentGeneration,
        'updatedAt': '2026-08-03T00:00:00.000Z',
      }),
    );
    final current = await gate(
      readMarker: (_) async => throw const FileSystemException('临时读取失败'),
    );

    await expectLater(
      current.ensureCurrent(),
      throwsA(isA<LocalDataGenerationMarkerReadException>()),
    );

    expect(await File(layout.databasePath).readAsString(), 'legacy-db');
    expect(await File(layout.meetingAudioPath('old-meeting')).exists(), isTrue);
    expect(
      await File(
        p.join(layout.modelsRoot, 'sense-voice', '1', 'model.int8.onnx'),
      ).exists(),
      isTrue,
    );
    expect(await markerFile().exists(), isTrue);
  });

  test('连续两次启动只在第一次清场', () async {
    await seedLegacyInstallation();
    final current = await gate();

    expect(await current.ensureCurrent(), isTrue);
    expect(await current.ensureCurrent(), isFalse);
  });
}
