import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/audio/recording_continuity_event_store.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/models/recording.dart';
import 'package:meettrace/domain/models/recording_continuity_event.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/recording_session.dart';
import 'package:meettrace/domain/use_cases/lock_recording_input.dart';

import '../../../support/recording_fakes.dart';

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
    Duration captureStopTimeout = const Duration(milliseconds: 20),
    Duration factCommitInterval = Duration.zero,
    Duration checkpointSaveInterval = defaultRecordingCheckpointSaveInterval,
    int checkpointSaveBytesThreshold =
        defaultRecordingCheckpointSaveBytesThreshold,
    DateTime Function()? now,
    bool enableInputRecovery = false,
    LockedRecordingInput initialInput =
        const LockedRecordingInput.systemDefault(),
  }) {
    return ReliableRecordingService(
      capture: capture,
      layout: layout,
      checkpoints: checkpointStore ?? checkpoints,
      continuityEvents: JsonRecordingContinuityEventStore(layout),
      storageCapacity: FixedRecordingStorageCapacity(freeBytes),
      initialInput: initialInput,
      inputRecoveryPlanner: enableInputRecovery
          ? const PlanRecordingInputRecoveryUseCase()
          : null,
      foreground: foreground,
      previewSink: preview,
      audioLevelMeter: PcmAudioLevelMeter(),
      captureStopTimeout: captureStopTimeout,
      factCommitInterval: factCommitInterval,
      checkpointSaveInterval: checkpointSaveInterval,
      checkpointSaveBytesThreshold: checkpointSaveBytesThreshold,
      now: now ?? () => DateTime.utc(2026, 7, 24, 8),
    );
  }

  test('每个 PCM 块完成文件 flush 后才投递预览', () async {
    final observed = <RecordingPcmChunk>[];
    final preview = TestRecordingPreviewSink((chunk) async {
      final file = File(layout.meetingAudioTempPath('meeting-1'));
      expect(await file.length(), chunk.endByteOffset);
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

  test('生产提交窗口将同批 PCM 合并为一个连续预览块', () async {
    const chunkCount = 20;
    const chunkBytes = 3200;
    final persistedAtFirstPreview = Completer<int>();
    final previewChunks = <RecordingPcmChunk>[];
    late final ReliableRecordingService service;
    service = createService(
      factCommitInterval: defaultRecordingFactCommitInterval,
      preview: TestRecordingPreviewSink((chunk) async {
        previewChunks.add(chunk);
        if (!persistedAtFirstPreview.isCompleted) {
          persistedAtFirstPreview.complete(service.persistedBytes);
        }
      }),
    );

    await service.start(meetingId: 'meeting-batched-fact-commit');
    for (var index = 0; index < chunkCount; index++) {
      capture.add(_pcmBytes(chunkBytes));
    }
    await _waitFor(() => service.persistedBytes == chunkCount * chunkBytes);
    await _waitFor(() => previewChunks.isNotEmpty);
    final result = await service.stop();

    expect(await persistedAtFirstPreview.future, chunkCount * chunkBytes);
    expect(previewChunks, hasLength(1));
    expect(previewChunks.single.startByteOffset, 0);
    expect(previewChunks.single.bytes, hasLength(chunkCount * chunkBytes));
    expect(result.bytes, chunkCount * chunkBytes);
  });

  test('ASR 预览阻塞时音量派生仍处理后续已持久化批次', () async {
    final firstPreview = Completer<void>();
    var previewCalls = 0;
    final service = createService(
      preview: TestRecordingPreviewSink((_) {
        previewCalls++;
        return firstPreview.future;
      }),
    );
    final levels = <RecordingAudioLevel>[];
    final subscription = service.audioLevelChanges.listen(levels.add);

    await service.start(meetingId: 'meeting-independent-levels');
    capture.add(_pcmBytes(recordingBytesPerSecond ~/ 10));
    await _waitFor(() => levels.length == 1 && previewCalls == 1);
    capture.add(_pcmBytes(recordingBytesPerSecond ~/ 10));
    await _waitFor(() => levels.length == 2);

    expect(previewCalls, 1);
    expect(levels.map((sample) => sample.capturedThrough), [
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 200),
    ]);

    firstPreview.complete();
    await service.stop();
    await subscription.cancel();
  });

  test('preview sink 阻塞或抛错都不阻塞后续事实音频写入', () async {
    final firstPreview = Completer<void>();
    var previewCalls = 0;
    final preview = TestRecordingPreviewSink((_) {
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
      preview: TestRecordingPreviewSink((chunk) async {
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

  test('进度 checkpoint 未到节流间隔时不落盘，暂停等状态点强制落盘', () async {
    final clock = _FakeClock(DateTime.utc(2026, 7, 24, 8));
    final trackingCheckpoints = _TrackingRecordingCheckpointStore(checkpoints);
    final service = createService(
      now: clock.read,
      checkpointStore: trackingCheckpoints,
    );

    await service.start(meetingId: 'meeting-throttle');
    capture.add(_pcmBytes(16000));
    await _waitFor(() => service.persistedBytes == 16000);

    // 时钟未推进且字节量未达阈值：checkpoint 仍停留在启动时的初始记录。
    var checkpoint = await checkpoints.load('meeting-throttle');
    expect(checkpoint?.persistedBytes, 0);
    expect(checkpoint?.state, RecordingCheckpointState.recording);

    clock.advance(const Duration(seconds: 5));
    capture.add(_pcmBytes(16000));
    await _waitFor(() => service.persistedBytes == 32000);
    await _waitFor(() => trackingCheckpoints.completedSaves == 2);
    checkpoint = await checkpoints.load('meeting-throttle');
    expect(checkpoint?.persistedBytes, 32000);

    // 暂停不受节流约束，立即记录最新进度与状态。
    await service.pause();
    checkpoint = await checkpoints.load('meeting-throttle');
    expect(checkpoint?.persistedBytes, 32000);
    expect(checkpoint?.state, RecordingCheckpointState.paused);

    final result = await service.stop();
    expect(result.bytes, 32000);
    checkpoint = await checkpoints.load('meeting-throttle');
    expect(checkpoint?.state, RecordingCheckpointState.finalized);
    expect(checkpoint?.persistedBytes, 32000);
  });

  test('累计字节达到阈值时提前落盘进度 checkpoint', () async {
    final clock = _FakeClock(DateTime.utc(2026, 7, 24, 8));
    final trackingCheckpoints = _TrackingRecordingCheckpointStore(checkpoints);
    final service = createService(
      now: clock.read,
      checkpointStore: trackingCheckpoints,
      checkpointSaveBytesThreshold: 32000,
    );

    await service.start(meetingId: 'meeting-bytes');
    capture.add(_pcmBytes(16000));
    await _waitFor(() => service.persistedBytes == 16000);
    expect((await checkpoints.load('meeting-bytes'))?.persistedBytes, 0);

    capture.add(_pcmBytes(16000));
    await _waitFor(() => service.persistedBytes == 32000);
    await _waitFor(() => trackingCheckpoints.completedSaves == 2);
    expect((await checkpoints.load('meeting-bytes'))?.persistedBytes, 32000);

    await service.stop();
  });

  test('后台写入失败不会产生未处理异步异常且封存返回稳定失败', () async {
    final uncaught = <Object>[];
    final bodyDone = Completer<void>();
    Object? stopError;

    runZonedGuarded(() async {
      try {
        final service = createService();
        await service.start(meetingId: 'meeting-write-failure');
        capture.add(Uint8List(1));
        await _waitFor(() => service.state == RecordingState.failed);
        await service.stop();
      } on Object catch (error) {
        stopError = error;
      } finally {
        bodyDone.complete();
      }
    }, (error, _) => uncaught.add(error));
    await bodyDone.future;
    await Future<void>.delayed(Duration.zero);

    expect(uncaught, isEmpty);
    expect(
      stopError,
      isA<ReliableRecordingException>().having(
        (error) => error.code,
        'code',
        'recording.pcm_alignment_invalid',
      ),
    );
  });

  test('恢复订阅前先进入 recording 以处理暂停期间缓存的流错误', () async {
    final service = createService(enableInputRecovery: true);
    await service.start(meetingId: 'meeting-buffered-error');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);
    await service.pause();
    capture.addError(StateError('buffered microphone error'));

    await service.resume();

    await _waitFor(
      () =>
          capture.startInputs.length == 2 &&
          service.state == RecordingState.recording,
    );
    expect(service.state, RecordingState.recording);
    await service.stop();
  });

  test('落盘和 checkpoint 节流参数非法时拒绝创建录音服务', () {
    expect(
      () => createService(factCommitInterval: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
    expect(
      () =>
          createService(factCommitInterval: const Duration(milliseconds: 1001)),
      throwsArgumentError,
    );
    expect(
      () => createService(checkpointSaveInterval: Duration.zero),
      throwsArgumentError,
    );
    expect(
      () => createService(checkpointSaveBytesThreshold: -1),
      throwsArgumentError,
    );
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
      await File(layout.meetingAudioTempPath('meeting-checkpoint-failure'))
          .exists(),
      isFalse,
    );
  });

  test('采集启动时没有输入设备会保留稳定错误码', () async {
    capture.startError = const PcmAudioCaptureException(
      failure: PcmAudioCaptureFailure.inputUnavailable,
    );
    final service = createService();

    await expectLater(
      service.start(meetingId: 'meeting-no-input'),
      throwsA(
        isA<ReliableRecordingException>().having(
          (error) => error.code,
          'code',
          'recording.input_unavailable',
        ),
      ),
    );

    expect(service.state, RecordingState.failed);
    expect(
      await File(layout.meetingAudioTempPath('meeting-no-input')).exists(),
      isFalse,
    );
  });

  test('采集流异步报错后刷新事实并仅一次切到系统默认输入', () async {
    final service = createService(
      enableInputRecovery: true,
      factCommitInterval: const Duration(milliseconds: 20),
    );
    await service.start(meetingId: 'meeting-capture-error');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    capture.addError(StateError('microphone interrupted'));
    await _waitFor(() => capture.startInputs.length == 2);
    await _waitFor(() => service.state == RecordingState.recording);
    expect(capture.startInputs, hasLength(2));
    expect(service.state, RecordingState.recording);
    expect(capture.startInputs.last.usesSystemDefault, isTrue);
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond * 2);

    expect(service.canFinalize, isTrue);
    final result = await service.stop();

    expect(result.bytes, recordingBytesPerSecond * 2);
    expect(result.duration, const Duration(seconds: 2));
    expect(await File(result.audioPath).exists(), isTrue);
    expect(service.state, RecordingState.completed);
    expect(foreground.events.last, 'stop');
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-capture-error');
    expect(continuity.map((event) => event.kind), [
      RecordingContinuityEventKind.interruptionStarted,
      RecordingContinuityEventKind.switchedToSystemDefault,
    ]);
    expect(continuity.first.incidentId, continuity.last.incidentId);
    expect(continuity.first.persistedBytes, recordingBytesPerSecond);
    expect(continuity.last.inputLabel, '系统默认麦克风');
  });

  test('默认输入回退后的第二次流中断进入真实 interrupted 且可封存', () async {
    final service = createService(enableInputRecovery: true);
    await service.start(meetingId: 'meeting-capture-interrupted');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);

    capture.addError(StateError('selected microphone disconnected'));
    await _waitFor(() => capture.startInputs.length == 2);
    capture.addError(StateError('default microphone disconnected'));
    await _waitFor(() => service.state == RecordingState.interrupted);

    expect(capture.startInputs, hasLength(2));
    expect(service.canFinalize, isTrue);
    final result = await service.stop();
    expect(result.bytes, recordingBytesPerSecond);
    expect(service.state, RecordingState.completed);
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-capture-interrupted');
    expect(continuity.map((event) => event.kind), [
      RecordingContinuityEventKind.interruptionStarted,
      RecordingContinuityEventKind.switchedToSystemDefault,
      RecordingContinuityEventKind.interruptionStarted,
      RecordingContinuityEventKind.recordingInterrupted,
    ]);
    expect(continuity[2].incidentId, continuity[3].incidentId);
  });

  test('设备中断时平台 stop 超时不复用 recorder 并进入 interrupted', () async {
    final service = createService(enableInputRecovery: true);
    await service.start(meetingId: 'meeting-recovery-stop-timeout');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);
    final stopBlocker = Completer<void>();
    capture.stopBlocker = stopBlocker;
    addTearDown(() {
      if (!stopBlocker.isCompleted) {
        stopBlocker.complete();
      }
    });

    capture.addError(StateError('microphone disconnected'));
    await _waitFor(() => service.state == RecordingState.interrupted);

    expect(capture.startInputs, hasLength(1));
    stopBlocker.complete();
    await _waitFor(() => !capture.isStarted);
    final result = await service.stop();
    expect(result.bytes, recordingBytesPerSecond);
    expect(service.state, RecordingState.completed);
  });

  test('系统挂起先排空事实 PCM 并在同一字节偏移保存检查点和缺口起点', () async {
    final service = createService(
      factCommitInterval: const Duration(milliseconds: 20),
    );
    await service.start(meetingId: 'meeting-system-suspend');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await Future<void>.delayed(Duration.zero);

    await service.handleSystemSuspending();

    expect(service.state, RecordingState.recovering);
    expect(capture.streamPaused, isTrue);
    expect(service.persistedBytes, recordingBytesPerSecond);
    final checkpoint = await checkpoints.load('meeting-system-suspend');
    expect(checkpoint?.state, RecordingCheckpointState.recording);
    expect(checkpoint?.persistedBytes, recordingBytesPerSecond);
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-system-suspend');
    expect(
      continuity.single.kind,
      RecordingContinuityEventKind.systemSuspended,
    );
    expect(continuity.single.persistedBytes, recordingBytesPerSecond);

    await service.handleSystemResumed();
    await service.stop();
  });

  test('系统恢复后重开同一锁定输入并继续同一会议事实音频', () async {
    const selectedInput = LockedRecordingInput.device(
      RecordingInputDevice(id: 'usb-mic', label: 'USB 麦克风'),
    );
    final service = createService(initialInput: selectedInput);
    await service.start(meetingId: 'meeting-system-resume');
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond);

    await service.handleSystemSuspending();
    await service.handleSystemResumed();

    expect(service.state, RecordingState.recording);
    expect(capture.startInputs, [selectedInput, selectedInput]);
    capture.add(_pcmBytes(recordingBytesPerSecond));
    await _waitFor(() => service.persistedBytes == recordingBytesPerSecond * 2);
    final result = await service.stop();
    expect(result.bytes, recordingBytesPerSecond * 2);
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-system-resume');
    expect(continuity.map((event) => event.kind), [
      RecordingContinuityEventKind.systemSuspended,
      RecordingContinuityEventKind.systemResumed,
    ]);
    expect(continuity.first.incidentId, continuity.last.incidentId);
    expect(continuity.last.inputLabel, 'USB 麦克风');
  });

  test('系统恢复时锁定设备失效仅一次降级到系统默认输入', () async {
    const selectedInput = LockedRecordingInput.device(
      RecordingInputDevice(id: 'dock-mic', label: '扩展坞麦克风'),
    );
    final service = createService(
      initialInput: selectedInput,
      enableInputRecovery: true,
    );
    await service.start(meetingId: 'meeting-system-fallback');
    capture.add(_pcmBytes(3200));
    await _waitFor(() => service.persistedBytes == 3200);
    await service.handleSystemSuspending();
    capture.remainingStartFailures = 1;

    await service.handleSystemResumed();

    expect(service.state, RecordingState.recording);
    expect(capture.startInputs, [
      selectedInput,
      selectedInput,
      const LockedRecordingInput.systemDefault(),
    ]);
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-system-fallback');
    expect(continuity.map((event) => event.kind), [
      RecordingContinuityEventKind.systemSuspended,
      RecordingContinuityEventKind.switchedToSystemDefault,
      RecordingContinuityEventKind.systemResumed,
    ]);
    expect(continuity.map((event) => event.incidentId).toSet(), hasLength(1));
    await service.stop();
  });

  test('系统恢复关闭旧 recorder 超时后进入可封存的真实中断状态', () async {
    final service = createService(enableInputRecovery: true);
    await service.start(meetingId: 'meeting-system-resume-timeout');
    capture.add(_pcmBytes(3200));
    await _waitFor(() => service.persistedBytes == 3200);
    await service.handleSystemSuspending();
    final stopBlocker = Completer<void>();
    capture.stopBlocker = stopBlocker;
    addTearDown(() {
      if (!stopBlocker.isCompleted) {
        stopBlocker.complete();
      }
    });

    await service.handleSystemResumed();

    expect(service.state, RecordingState.interrupted);
    expect(service.canFinalize, isTrue);
    expect(capture.startInputs, hasLength(1));
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-system-resume-timeout');
    expect(continuity.map((event) => event.kind), [
      RecordingContinuityEventKind.systemSuspended,
      RecordingContinuityEventKind.systemResumeFailed,
    ]);
    stopBlocker.complete();
    await _waitFor(() => !capture.isStarted);
    final result = await service.stop();
    expect(result.bytes, 3200);
  });

  test('系统会话结束通知排空写入并更新可恢复检查点', () async {
    final tracking = _TrackingRecordingCheckpointStore(checkpoints);
    final service = createService(
      checkpointStore: tracking,
      factCommitInterval: const Duration(milliseconds: 20),
    );
    await service.start(meetingId: 'meeting-session-ending');
    capture.add(_pcmBytes(6400));
    await Future<void>.delayed(Duration.zero);
    final savesBefore = tracking.completedSaves;

    await service.prepareForSystemExit();

    expect(service.persistedBytes, 6400);
    expect(tracking.completedSaves, greaterThan(savesBefore));
    final checkpoint = await checkpoints.load('meeting-session-ending');
    expect(checkpoint?.persistedBytes, 6400);
    expect(checkpoint?.state, RecordingCheckpointState.recording);
    await service.stop();
  });

  test('用户封存会等待正在执行的系统挂起检查点完成', () async {
    final service = createService(
      factCommitInterval: const Duration(milliseconds: 20),
    );
    await service.start(meetingId: 'meeting-stop-during-suspend');
    capture.add(_pcmBytes(6400));
    await Future<void>.delayed(Duration.zero);

    final suspending = service.handleSystemSuspending();
    final stopping = service.stop();
    await suspending;
    final result = await stopping;

    expect(result.bytes, 6400);
    expect(service.state, RecordingState.completed);
    final continuity = await JsonRecordingContinuityEventStore(layout)
        .read('meeting-stop-during-suspend');
    expect(
      continuity.single.kind,
      RecordingContinuityEventKind.systemSuspended,
    );
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

    final result = await service.stop().timeout(const Duration(seconds: 2));

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

final class _FakeClock {
  _FakeClock(this.current);

  DateTime current;

  DateTime read() => current;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

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
  StreamController<Uint8List>? _controller;

  bool permissionGranted = true;
  bool _started = false;
  bool get isStarted => _started;
  bool get streamPaused => _controller?.isPaused ?? false;
  final List<LockedRecordingInput> startInputs = [];
  int stopCalls = 0;
  int disposeCalls = 0;
  Object? disposeError;
  Completer<void>? stopBlocker;
  int remainingStartFailures = 0;
  Object? startError;

  void add(Uint8List bytes) {
    if (!_started) {
      throw StateError('capture has not started');
    }
    _controller!.add(Uint8List.fromList(bytes));
  }

  void addError(Object error) {
    if (!_started) {
      throw StateError('capture has not started');
    }
    _controller!.addError(error);
  }

  @override
  Future<bool> hasPermission({bool request = true}) async {
    return permissionGranted;
  }

  @override
  Future<Stream<Uint8List>> start({
    LockedRecordingInput input = const LockedRecordingInput.systemDefault(),
  }) async {
    startInputs.add(input);
    final configuredStartError = startError;
    if (configuredStartError != null) {
      throw configuredStartError;
    }
    if (remainingStartFailures > 0) {
      remainingStartFailures--;
      throw StateError('configured capture start failure');
    }
    _controller = StreamController<Uint8List>();
    _started = true;
    return _controller!.stream;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    await stopBlocker?.future;
    final controller = _controller;
    if (_started && controller != null && !controller.isClosed) {
      await controller.close();
    }
    _started = false;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      final closing = controller.close();
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

final class _TrackingRecordingCheckpointStore
    implements RecordingCheckpointStore {
  _TrackingRecordingCheckpointStore(this.delegate);

  final RecordingCheckpointStore delegate;
  int completedSaves = 0;

  @override
  Future<void> delete(String meetingId) => delegate.delete(meetingId);

  @override
  Future<RecordingCheckpoint?> load(String meetingId) =>
      delegate.load(meetingId);

  @override
  Future<void> save(RecordingCheckpoint checkpoint) async {
    await delegate.save(checkpoint);
    completedSaves++;
  }
}
