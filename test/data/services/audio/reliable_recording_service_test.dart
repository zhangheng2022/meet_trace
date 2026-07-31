import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late JsonRecordingCheckpointStore checkpoints;
  late FakePcmAudioCapture capture;
  late FakeRecordingForegroundLifecycle foreground;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-recording-');
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
    RecordingCheckpointStore? checkpointStore,
    PcmAudioCapture? captureOverride,
    Duration captureStopTimeout = const Duration(milliseconds: 20),
    Duration factCommitInterval = Duration.zero,
  }) {
    return ReliableRecordingService(
      capture: captureOverride ?? capture,
      layout: layout,
      checkpoints: checkpointStore ?? checkpoints,
      storageCapacity: FixedRecordingStorageCapacity(freeBytes),
      foreground: foreground,
      previewSink: preview,
      audioLevelMeter: PcmAudioLevelMeter(),
      captureStopTimeout: captureStopTimeout,
      factCommitInterval: factCommitInterval,
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
    expect(service.pcmDiagnostics.totalBytes, 16000);
    expect(service.pcmDiagnostics.sampleCount, 8000);
    expect(service.pcmDiagnostics.duration, const Duration(milliseconds: 500));
    expect(await File(result.audioPath).length(), 16000);
    expect(
      await File(layout.meetingAudioTempPath('meeting-1')).exists(),
      false,
    );
    expect(foreground.events, ['start:meeting-1', 'stop']);
  });

  test('事实音频写入成功后才发布可丢弃音量反馈', () async {
    final service = createService();
    final levels = <RecordingAudioLevel>[];
    final subscription = service.audioLevelChanges.listen(levels.add);

    await service.start(meetingId: 'meeting-level');
    capture.add(_pcmBytes(recordingBytesPerSecond ~/ 10));
    await _waitFor(() => levels.isNotEmpty);

    expect(service.persistedBytes, recordingBytesPerSecond ~/ 10);
    expect(levels.single.level, 0);
    expect(levels.single.capturedThrough, const Duration(milliseconds: 100));

    await service.stop();
    await subscription.cancel();
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

  test('ASR preview 阻塞时音量反馈仍独立消费已持久化 PCM', () async {
    final firstPreview = Completer<void>();
    var previewCalls = 0;
    final preview = CallbackRecordingPreviewSink((_) {
      previewCalls++;
      return firstPreview.future;
    });
    final service = createService(
      preview: preview,
      factCommitInterval: const Duration(milliseconds: 20),
    );
    final levels = <RecordingAudioLevel>[];
    final subscription = service.audioLevelChanges.listen(levels.add);

    await service.start(meetingId: 'meeting-independent-levels');
    for (var index = 0; index < 10; index++) {
      capture.add(_pcmBytes(320));
    }

    await _waitFor(() => service.persistedBytes == 3200);
    await _waitFor(() => levels.length == 1);

    expect(previewCalls, 1);
    expect(levels.map((sample) => sample.capturedThrough), [
      const Duration(milliseconds: 100),
    ]);

    firstPreview.complete();
    await service.stop();
    await subscription.cancel();
  });

  test('内部写盘排队不会暂停平台采集流', () async {
    final pauseAwareCapture = _PauseAwarePcmAudioCapture();
    addTearDown(pauseAwareCapture.dispose);
    final service = createService(captureOverride: pauseAwareCapture);

    await service.start(meetingId: 'meeting-no-capture-backpressure');
    for (var index = 0; index < 20; index++) {
      pauseAwareCapture.add(_pcmBytes(3200));
    }
    await _waitFor(() => service.persistedBytes == 64000);
    final result = await service.stop();

    expect(result.bytes, 64000);
    expect(pauseAwareCapture.subscriptionPauseCount, 0);
  });

  test('提交窗口内的 PCM 块合并为一次事实落盘 checkpoint', () async {
    final countingCheckpoints = _CountingRecordingCheckpointStore(checkpoints);
    final service = createService(
      checkpointStore: countingCheckpoints,
      factCommitInterval: const Duration(milliseconds: 20),
    );

    await service.start(meetingId: 'meeting-batched-fact-commit');
    for (var index = 0; index < 20; index++) {
      capture.add(_pcmBytes(3200));
    }
    await _waitFor(() => service.persistedBytes == 64000);

    expect(countingCheckpoints.saveCount, 2);
    final result = await service.stop();
    expect(result.bytes, 64000);
    expect(countingCheckpoints.saveCount, 3);
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

  test('首次 checkpoint 写入失败会回滚文件和平台录音资源', () async {
    final service = createService(
      checkpointStore: _FailingRecordingCheckpointStore(),
    );

    await expectLater(
      service.start(meetingId: 'meeting-checkpoint-failure'),
      throwsA(
        isA<ReliableRecordingException>().having(
          (error) => error.code,
          'code',
          'recording.start_failed',
        ),
      ),
    );

    expect(service.state, RecordingState.failed);
    expect(service.canFinalize, isFalse);
    expect(capture.stopCalls, 1);
    expect(capture.disposeCalls, 1);
    expect(foreground.events, ['stop']);
    expect(
      await File(
        layout.meetingAudioTempPath('meeting-checkpoint-failure'),
      ).exists(),
      isFalse,
    );
  });

  test('采集流异步报错后仍可封存已持久化事实音频', () async {
    final service = createService();
    await service.start(meetingId: 'meeting-capture-error');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);

    capture.addError(StateError('microphone interrupted'));
    await _waitFor(() => service.state == RecordingState.failed);

    expect(service.canFinalize, isTrue);
    final result = await service.stop();

    expect(result.bytes, recordingBytesPerSecond);
    expect(result.duration, const Duration(seconds: 1));
    expect(await File(result.audioPath).exists(), isTrue);
    expect(service.state, RecordingState.completed);
    expect(foreground.events.last, 'stop');
  });

  test('平台 recorder 停止不返回时仍封存已写盘事实音频', () async {
    final service = createService();
    await service.start(meetingId: 'meeting-stop-timeout');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);
    final stopBlocker = Completer<void>();
    capture.stopBlocker = stopBlocker;
    addTearDown(() {
      if (!stopBlocker.isCompleted) {
        stopBlocker.complete();
      }
    });

    final result = await service.stop().timeout(
      const Duration(milliseconds: 250),
    );

    expect(result.bytes, recordingBytesPerSecond);
    expect(result.duration, const Duration(seconds: 1));
    expect(await File(result.audioPath).length(), recordingBytesPerSecond);
    expect(service.state, RecordingState.completed);
  });

  test('封存提交后的前台服务和 recorder 清理异常不覆盖成功结果', () async {
    final service = createService();
    await service.start(meetingId: 'meeting-cleanup-failure');
    capture.add(_pcmBytes(3200));
    await _waitFor(() => service.persistedBytes == 3200);
    foreground.stopError = StateError('foreground stop failed');
    capture.disposeError = StateError('recorder dispose failed');

    final result = await service.stop();

    expect(result.bytes, 3200);
    expect(await File(result.audioPath).length(), 3200);
    expect(service.state, RecordingState.completed);
    expect(capture.disposeCalls, 1);
    expect(foreground.events.last, 'stop');
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
  int stopCalls = 0;
  int disposeCalls = 0;
  Object? disposeError;
  Completer<void>? stopBlocker;

  void add(Uint8List bytes) {
    if (!_started) {
      throw StateError('capture has not started');
    }
    _controller.add(Uint8List.fromList(bytes));
  }

  void addError(Object error) {
    if (!_started) {
      throw StateError('capture has not started');
    }
    _controller.addError(error);
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
    stopCalls++;
    await stopBlocker?.future;
    if (_started && !_controller.isClosed) {
      await _controller.close();
    }
    _started = false;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (!_controller.isClosed) {
      final closing = _controller.close();
      if (_started) {
        await closing;
      }
    }
    final error = disposeError;
    disposeError = null;
    if (error != null) {
      throw error;
    }
  }
}

final class _PauseAwarePcmAudioCapture implements PcmAudioCapture {
  _PauseAwarePcmAudioCapture() {
    _controller.onPause = () => subscriptionPauseCount++;
  }

  final StreamController<Uint8List> _controller = StreamController<Uint8List>();
  int subscriptionPauseCount = 0;
  bool _started = false;

  void add(Uint8List bytes) {
    if (!_started) {
      throw StateError('capture has not started');
    }
    _controller.add(Uint8List.fromList(bytes));
  }

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

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
      await _controller.close();
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
  Object? stopError;

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
    final error = stopError;
    stopError = null;
    if (error != null) {
      throw error;
    }
  }
}

final class _FailingRecordingCheckpointStore
    implements RecordingCheckpointStore {
  @override
  Future<void> delete(String meetingId) async {}

  @override
  Future<RecordingCheckpoint?> load(String meetingId) async => null;

  @override
  Future<void> save(RecordingCheckpoint checkpoint) async {
    throw FileSystemException('checkpoint write failed');
  }
}

final class _CountingRecordingCheckpointStore
    implements RecordingCheckpointStore {
  _CountingRecordingCheckpointStore(this.delegate);

  final RecordingCheckpointStore delegate;
  int saveCount = 0;

  @override
  Future<void> delete(String meetingId) => delegate.delete(meetingId);

  @override
  Future<RecordingCheckpoint?> load(String meetingId) =>
      delegate.load(meetingId);

  @override
  Future<void> save(RecordingCheckpoint checkpoint) {
    saveCount++;
    return delegate.save(checkpoint);
  }
}
