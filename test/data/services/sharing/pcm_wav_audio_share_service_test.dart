import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/sharing/pcm_wav_audio_share_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/device_free_space_service.dart';
import 'package:meettrace/domain/ports/audio_share.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late File source;
  late Uint8List originalPcm;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-audio-share-');
    layout = AppFileLayout(rootPath: root.path);
    source = File(layout.meetingAudioPath('meeting-1'));
    await source.parent.create(recursive: true);
    originalPcm = Uint8List.fromList(
      List<int>.generate(32000, (index) => index % 251),
    );
    await source.writeAsBytes(originalPcm, flush: true);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  for (final outcome in AudioShareOutcome.values) {
    test('$outcome 时分享完整 WAV 并清理临时副本', () async {
      final systemShare = _SystemShare(outcome: outcome);
      final service = _service(
        layout: layout,
        systemShare: systemShare,
        freeBytes: 1024 * 1024,
      );

      final preview = await service.inspect(audioPath: source.path);
      final result = await service.share(
        meetingId: 'meeting-1',
        meetingTitle: '产品/周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      );

      expect(result, outcome);
      expect(preview.pcmBytes, 32000);
      expect(preview.wavBytes, 32044);
      expect(systemShare.fileName, '产品_周会.wav');
      expect(systemShare.title, '分享会议录音：产品/周会');
      expect(String.fromCharCodes(systemShare.bytes!.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(systemShare.bytes!.sublist(8, 12)), 'WAVE');
      expect(systemShare.bytes!.sublist(44), originalPcm);
      expect(await source.readAsBytes(), originalPcm);
      expect(
        await Directory(layout.meetingShareTempDirectory('meeting-1')).exists(),
        false,
      );
    });
  }

  test('系统分享标题和空文件名回退使用注入的语言', () async {
    final systemShare = _SystemShare();
    final service = PcmWavAudioShareService(
      layout: layout,
      systemShare: systemShare,
      freeSpace: DeviceFreeSpaceService(reader: () async => 1),
      shareTitleBuilder: (title) => 'Share meeting recording: $title',
      fileNameFallbackBuilder: () => 'Meeting/Recording',
    );
    final preview = await service.inspect(audioPath: source.path);

    await service.share(
      meetingId: 'meeting-1',
      meetingTitle: '...',
      audioPath: source.path,
      expectedPcmBytes: preview.pcmBytes,
    );

    expect(systemShare.title, 'Share meeting recording: ...');
    expect(systemShare.fileName, 'Meeting_Recording.wav');
  });

  test('空间不足时返回精确差额且不生成 WAV 或调用系统分享', () async {
    final systemShare = _SystemShare();
    final service = _service(
      layout: layout,
      systemShare: systemShare,
      freeBytes: 32000,
    );

    final preview = await service.inspect(audioPath: source.path);

    expect(preview.shortageBytes, 44);
    await expectLater(
      service.share(
        meetingId: 'meeting-1',
        meetingTitle: '周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      ),
      throwsA(
        isA<AudioShareException>()
            .having(
              (error) => error.code,
              'code',
              'audio_share.insufficient_space',
            )
            .having((error) => error.shortageBytes, 'shortageBytes', 44),
      ),
    );
    expect(systemShare.calls, 0);
    expect(await source.readAsBytes(), originalPcm);
  });

  test('确认后生成前再次校验空间并报告新的精确差额', () async {
    var reads = 0;
    final systemShare = _SystemShare();
    final service = PcmWavAudioShareService(
      layout: layout,
      systemShare: systemShare,
      freeSpace: DeviceFreeSpaceService(
        reader: () async {
          reads++;
          final bytes = reads == 1 ? 1024 * 1024 : 32000;
          return bytes / (1024 * 1024);
        },
      ),
    );

    final preview = await service.inspect(audioPath: source.path);
    expect(preview.hasEnoughSpace, true);

    await expectLater(
      service.share(
        meetingId: 'meeting-1',
        meetingTitle: '周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      ),
      throwsA(
        isA<AudioShareException>().having(
          (error) => error.shortageBytes,
          'shortageBytes',
          44,
        ),
      ),
    );
    expect(systemShare.calls, 0);
    expect(
      await Directory(layout.meetingShareTempDirectory('meeting-1')).exists(),
      false,
    );
  });

  test('系统分享异常时仍清理临时 WAV 并保留事实 PCM', () async {
    final systemShare = _SystemShare(error: StateError('share failed'));
    final service = _service(
      layout: layout,
      systemShare: systemShare,
      freeBytes: 1024 * 1024,
    );
    final preview = await service.inspect(audioPath: source.path);

    await expectLater(
      service.share(
        meetingId: 'meeting-1',
        meetingTitle: '周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      ),
      throwsA(
        isA<AudioShareException>().having(
          (error) => error.code,
          'code',
          'audio_share.failed',
        ),
      ),
    );

    expect(await source.readAsBytes(), originalPcm);
    expect(
      await Directory(layout.meetingShareTempDirectory('meeting-1')).exists(),
      false,
    );
  });

  test('清理失败不覆盖原始分享错误且仍尝试清理根目录', () async {
    var rootCleanupCalls = 0;
    final service = PcmWavAudioShareService(
      layout: layout,
      systemShare: _SystemShare(error: StateError('share failed')),
      freeSpace: DeviceFreeSpaceService(reader: () async => 1),
      removeSession: (_) async =>
          throw const AudioShareException('audio_share.cleanup_failed'),
      removeEmptyShareRoot: (_) async => rootCleanupCalls++,
    );
    final preview = await service.inspect(audioPath: source.path);

    await expectLater(
      service.share(
        meetingId: 'meeting-1',
        meetingTitle: '周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      ),
      throwsA(
        isA<AudioShareException>().having(
          (error) => error.code,
          'code',
          'audio_share.failed',
        ),
      ),
    );
    expect(rootCleanupCalls, 1);
  });

  test('同一会议并发分享使用独立临时目录且都能完成清理', () async {
    final systemShare = _SystemShare(delay: const Duration(milliseconds: 10));
    final service = _service(
      layout: layout,
      systemShare: systemShare,
      freeBytes: 1024 * 1024,
    );
    final preview = await service.inspect(audioPath: source.path);

    await Future.wait([
      service.share(
        meetingId: 'meeting-1',
        meetingTitle: '周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      ),
      service.share(
        meetingId: 'meeting-1',
        meetingTitle: '周会',
        audioPath: source.path,
        expectedPcmBytes: preview.pcmBytes,
      ),
    ]);

    expect(systemShare.calls, 2);
    expect(systemShare.paths.toSet(), hasLength(2));
    expect(
      await Directory(layout.meetingShareTempDirectory('meeting-1')).exists(),
      false,
    );
  });
}

PcmWavAudioShareService _service({
  required AppFileLayout layout,
  required _SystemShare systemShare,
  required int freeBytes,
}) {
  return PcmWavAudioShareService(
    layout: layout,
    systemShare: systemShare,
    freeSpace: DeviceFreeSpaceService(
      reader: () async => freeBytes / (1024 * 1024),
    ),
  );
}

final class _SystemShare implements SystemAudioFileSharer {
  _SystemShare({
    this.outcome = AudioShareOutcome.completed,
    this.error,
    this.delay = Duration.zero,
  });

  final AudioShareOutcome outcome;
  final Object? error;
  final Duration delay;
  int calls = 0;
  Uint8List? bytes;
  String? fileName;
  String? title;
  final List<String> paths = [];

  @override
  Future<AudioShareOutcome> share({
    required String path,
    required String fileName,
    required String title,
  }) async {
    calls++;
    paths.add(path);
    expect(await File(path).exists(), true);
    bytes = await File(path).readAsBytes();
    this.fileName = fileName;
    this.title = title;
    await Future<void>.delayed(delay);
    if (error case final error?) {
      throw error;
    }
    return outcome;
  }
}
