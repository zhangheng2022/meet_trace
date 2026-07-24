import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/audio/recording_checkpoint_store.dart';
import 'package:meetily_ai/data/services/audio/recording_ports.dart';
import 'package:meetily_ai/data/services/audio/reliable_recording_service.dart';
import 'package:meetily_ai/data/services/storage/app_file_layout.dart';
import 'package:meetily_ai/domain/models/recording.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late JsonRecordingCheckpointStore checkpoints;
  late FakePcmAudioCapture capture;
  late FakeRecordingForegroundLifecycle foreground;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meetily-recording-');
    layout = AppFileLayout(rootPath: root.path);
    checkpoints = JsonRecordingCheckpointStore(layout);
    capture = FakePcmAudioCapture();
    foreground = FakeRecordingForegroundLifecycle();
  });

  tearDown(() async {
    await capture.dispose();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  ReliableRecordingService createService({
    RecordingPreviewSink preview = const DiscardingRecordingPreviewSink(),
    int freeBytes = 512 * 1024 * 1024,
  }) {
    return ReliableRecordingService(
      capture: capture,
      layout: layout,
      checkpoints: checkpoints,
      storageCapacity: FixedRecordingStorageCapacity(freeBytes),
      foreground: foreground,
      previewSink: preview,
      now: () => DateTime.utc(2026, 7, 24, 8),
    );
  }

  test('每个 PCM 块完成文件 flush 和 checkpoint 后才投递预览', () async {
    final observed = <RecordingPcmChunk>[];
    final preview = CallbackRecordingPreviewSink((chunk) async {
      final file = File(layout.meetingAudioTempPath('meeting-1'));
      final checkpoint = await checkpoints.load('meeting-1');
      expect(await file.length(), chunk.endByteOffset);
      expect(checkpoint?.persistedBytes, chunk.endByteOffset);
      observed.add(chunk);
    });
    final service = createService(preview: preview);

    await service.start(meetingId: 'meeting-1');
    capture.add(_pcmBytes(16000));
    await _waitFor(() => observed.length == 1);
    final result = await service.stop();

    expect(result.audioPath, layout.meetingAudioPath('meeting-1'));
    expect(result.bytes, 16000);
    expect(result.duration, const Duration(milliseconds: 500));
    expect(await File(result.audioPath).length(), 16000);
    expect(
      await File(layout.meetingAudioTempPath('meeting-1')).exists(),
      false,
    );
    expect(foreground.events, ['start:meeting-1', 'stop']);
  });

  test('preview sink 阻塞或抛错都不阻塞后续事实音频写入', () async {
    final firstPreview = Completer<void>();
    var previewCalls = 0;
    final preview = CallbackRecordingPreviewSink((_) {
      previewCalls++;
      if (previewCalls == 1) {
        return firstPreview.future;
      }
      throw StateError('preview failed');
    });
    final service = createService(preview: preview);

    await service.start(meetingId: 'meeting-1');
    capture
      ..add(_pcmBytes(3200))
      ..add(_pcmBytes(3200))
      ..add(_pcmBytes(3200));

    await _waitFor(() => service.persistedBytes == 9600);
    final result = await service.stop();

    expect(result.bytes, 9600);
    expect(await File(result.audioPath).length(), 9600);
    expect(previewCalls, 1);
    firstPreview.complete();
  });

  test('暂停和恢复只按已持久化样本累计连续时间轴', () async {
    final chunks = <RecordingPcmChunk>[];
    final service = createService(
      preview: CallbackRecordingPreviewSink((chunk) async {
        chunks.add(chunk);
      }),
    );

    await service.start(meetingId: 'meeting-1');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);
    await service.pause();
    expect(service.state.name, 'paused');
    await service.resume();
    capture.add(_pcmBytes(recordingBytesPerSecond ~/ 2));
    await _waitFor(
      () => service.persistedBytes == recordingBytesPerSecond * 3 ~/ 2,
    );

    final result = await service.stop();

    expect(result.duration, const Duration(milliseconds: 1500));
    expect(chunks.map((chunk) => chunk.start).toList(), [
      Duration.zero,
      const Duration(seconds: 1),
    ]);
    expect(chunks.map((chunk) => chunk.end).toList(), [
      const Duration(seconds: 1),
      const Duration(milliseconds: 1500),
    ]);
    expect(foreground.events, [
      'start:meeting-1',
      'paused:true',
      'paused:false',
      'stop',
    ]);
  });

  test('权限拒绝或空间不足时不创建临时事实音频', () async {
    capture.permissionGranted = false;
    final permissionService = createService();

    await expectLater(
      permissionService.start(meetingId: 'meeting-1'),
      throwsA(
        isA<ReliableRecordingException>().having(
          (error) => error.code,
          'code',
          'recording.permission_denied',
        ),
      ),
    );
    expect(
      await File(layout.meetingAudioTempPath('meeting-1')).exists(),
      false,
    );

    capture.permissionGranted = true;
    final capacityService = createService(freeBytes: 1);
    await expectLater(
      capacityService.start(meetingId: 'meeting-2'),
      throwsA(
        isA<ReliableRecordingException>().having(
          (error) => error.code,
          'code',
          'recording.storage_insufficient',
        ),
      ),
    );
    expect(
      await File(layout.meetingAudioTempPath('meeting-2')).exists(),
      false,
    );
  });

  test('合成 30 分钟 PCM 的事实文件完整率为 100%', () async {
    final service = createService();
    await service.start(meetingId: 'meeting-30m');

    final oneMinute = _pcmBytes(recordingBytesPerSecond * 60);
    for (var minute = 0; minute < 30; minute++) {
      capture.add(oneMinute);
      final expected = oneMinute.length * (minute + 1);
      await _waitFor(
        () => service.persistedBytes == expected,
        timeout: const Duration(seconds: 10),
      );
    }

    final result = await service.stop();
    expect(result.duration, const Duration(minutes: 30));
    expect(result.bytes, recordingBytesPerSecond * 60 * 30);
    expect(await File(result.audioPath).length(), result.bytes);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Uint8List _pcmBytes(int length) => Uint8List(length);

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      fail('等待条件超时');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final class FakePcmAudioCapture implements PcmAudioCapture {
  final StreamController<Uint8List> _controller = StreamController<Uint8List>();

  bool permissionGranted = true;
  bool _started = false;

  void add(Uint8List bytes) {
    if (!_started) {
      throw StateError('capture has not started');
    }
    _controller.add(Uint8List.fromList(bytes));
  }

  @override
  Future<bool> hasPermission({bool request = true}) async {
    return permissionGranted;
  }

  @override
  Future<Stream<Uint8List>> start() async {
    _started = true;
    return _controller.stream;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
    _started = false;
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      final closing = _controller.close();
      if (_started) {
        await closing;
      }
    }
  }
}

final class FixedRecordingStorageCapacity
    implements RecordingStorageCapacityProvider {
  const FixedRecordingStorageCapacity(this.freeBytes);

  final int freeBytes;

  @override
  Future<int> getFreeBytes() async => freeBytes;
}

final class FakeRecordingForegroundLifecycle
    implements RecordingForegroundLifecycle {
  final List<String> events = [];

  @override
  Future<void> start({required String meetingId}) async {
    events.add('start:$meetingId');
  }

  @override
  Future<void> setPaused(bool paused) async {
    events.add('paused:$paused');
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }
}
