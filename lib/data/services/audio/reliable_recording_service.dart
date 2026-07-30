import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../domain/models/meeting_readiness.dart';
import '../../../domain/models/recording.dart';
import '../../../domain/models/workflow_states.dart';
import '../storage/app_file_layout.dart';
import '../storage/durable_file_committer.dart';
import 'pcm_audio_level_meter.dart';
import 'recording_pcm_diagnostics.dart';
import 'recording_checkpoint_store.dart';
import 'recording_ports.dart';
import 'recording_session_service.dart';

export 'recording_session_service.dart';
export 'pcm_audio_level_meter.dart';

const defaultRecordingCaptureStopTimeout = Duration(seconds: 5);

final class ReliableRecordingService implements RecordingSessionService {
  ReliableRecordingService({
    required this.capture,
    required this.layout,
    required this.checkpoints,
    required this.storageCapacity,
    this.foreground = const NoopRecordingForegroundLifecycle(),
    RecordingPreviewSink previewSink = const DiscardingRecordingPreviewSink(),
    this.fileCommitter = const DurableFileCommitter(),
    this.minimumFreeBytes = minimumRecordingFreeBytes,
    this.maxPendingPreviewChunks = 4,
    this.captureStopTimeout = defaultRecordingCaptureStopTimeout,
    required PcmAudioLevelMeter audioLevelMeter,
    RecordingPcmDiagnostics? pcmDiagnostics,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _audioLevelMeter = audioLevelMeter,
       _pcmDiagnostics = pcmDiagnostics ?? RecordingPcmDiagnostics(),
       _preview = RecordingPreviewDispatcher(
         FanOutRecordingPreviewSink([audioLevelMeter, previewSink]),
         maxPendingChunks: maxPendingPreviewChunks,
       ) {
    if (minimumFreeBytes <= 0) {
      throw ArgumentError.value(minimumFreeBytes, 'minimumFreeBytes', '必须大于 0');
    }
    if (captureStopTimeout <= Duration.zero) {
      throw ArgumentError.value(
        captureStopTimeout,
        'captureStopTimeout',
        '必须大于 0',
      );
    }
  }

  final PcmAudioCapture capture;
  final AppFileLayout layout;
  final RecordingCheckpointStore checkpoints;
  final RecordingStorageCapacityProvider storageCapacity;
  final RecordingForegroundLifecycle foreground;
  final DurableFileCommitter fileCommitter;
  final int minimumFreeBytes;
  final int maxPendingPreviewChunks;
  final Duration captureStopTimeout;
  final DateTime Function() now;
  final PcmAudioLevelMeter _audioLevelMeter;
  final RecordingPcmDiagnostics _pcmDiagnostics;
  final RecordingPreviewDispatcher _preview;

  RecordingState _state = RecordingState.idle;
  String? _meetingId;
  RandomAccessFile? _output;
  StreamSubscription<Uint8List>? _audioSubscription;
  Completer<void>? _captureDone;
  Future<void> _writeTail = Future<void>.value();
  Object? _writeError;
  StackTrace? _writeStackTrace;
  bool _userPaused = false;
  bool _captureStopTimedOut = false;
  int _persistedBytes = 0;

  @override
  RecordingState get state => _state;
  int get persistedBytes => _persistedBytes;
  @override
  Duration get duration => recordingDurationForBytes(_persistedBytes);
  @override
  Stream<RecordingAudioLevel> get audioLevelChanges => _audioLevelMeter.changes;
  @override
  bool get canFinalize =>
      _state == RecordingState.recording ||
      _state == RecordingState.paused ||
      (_state == RecordingState.failed && _output != null);
  int get droppedPreviewChunks => _preview.droppedChunks;
  RecordingPcmDiagnosticsSnapshot get pcmDiagnostics =>
      _pcmDiagnostics.snapshot;

  @override
  Future<void> start({required String meetingId}) async {
    if (_state != RecordingState.idle) {
      throw StateError('录音实例只能启动一次');
    }
    _state = RecordingState.starting;
    _meetingId = meetingId;
    _pcmDiagnostics.reset(nextByteOffset: 0);

    try {
      if (!await capture.hasPermission()) {
        throw const ReliableRecordingException(
          code: 'recording.permission_denied',
          message: '未获得麦克风权限',
        );
      }
      final freeBytes = await storageCapacity.getFreeBytes();
      if (freeBytes < minimumFreeBytes) {
        throw ReliableRecordingException(
          code: 'recording.storage_insufficient',
          message: '可用空间不足，至少需要 $minimumFreeBytes 字节',
        );
      }

      final tempFile = File(layout.meetingAudioTempPath(meetingId));
      final finalFile = File(layout.meetingAudioPath(meetingId));
      if (await tempFile.exists() || await finalFile.exists()) {
        throw const ReliableRecordingException(
          code: 'recording.audio_already_exists',
          message: '目标会议已有事实音频，拒绝覆盖',
        );
      }

      await tempFile.parent.create(recursive: true);
      _output = await tempFile.open(mode: FileMode.write);
      await _saveCheckpoint(RecordingCheckpointState.recording);
      await foreground.start(meetingId: meetingId);
      final stream = await capture.start();
      _captureDone = Completer<void>();
      late final StreamSubscription<Uint8List> subscription;
      subscription = stream.listen(
        (bytes) => _queueChunk(subscription, bytes),
        onError: (Object error, StackTrace stackTrace) {
          _state = RecordingState.failed;
          if (!subscription.isPaused) {
            subscription.pause();
          }
          _completeCapture();
        },
        onDone: _completeCapture,
        cancelOnError: false,
      );
      _audioSubscription = subscription;
      _state = RecordingState.recording;
    } on Object catch (error, stackTrace) {
      await _cleanupFailedStart(meetingId);
      _state = RecordingState.failed;
      if (error is ReliableRecordingException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      Error.throwWithStackTrace(
        ReliableRecordingException(
          code: 'recording.start_failed',
          message: '无法启动录音',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> pause() async {
    if (_state != RecordingState.recording) {
      throw StateError('当前状态不能暂停录音：${_state.name}');
    }
    _userPaused = true;
    await capture.pause();
    final subscription = _audioSubscription;
    if (subscription != null && !subscription.isPaused) {
      subscription.pause();
    }
    await _writeTail;
    await _flushOutput();
    _state = RecordingState.paused;
    await _saveCheckpoint(RecordingCheckpointState.paused);
    await foreground.setPaused(true);
  }

  @override
  Future<void> resume() async {
    if (_state != RecordingState.paused) {
      throw StateError('当前状态不能恢复录音：${_state.name}');
    }
    await _saveCheckpoint(RecordingCheckpointState.recording);
    await foreground.setPaused(false);
    _userPaused = false;
    final subscription = _audioSubscription;
    if (subscription != null && subscription.isPaused) {
      subscription.resume();
    }
    await capture.resume();
    _state = RecordingState.recording;
  }

  Future<void> flush() async {
    await _writeTail;
    _throwWriteErrorIfAny();
    await _flushOutput();
    final checkpointState = _state == RecordingState.paused
        ? RecordingCheckpointState.paused
        : RecordingCheckpointState.recording;
    await _saveCheckpoint(checkpointState);
  }

  @override
  Future<RecordingArtifact> stop() async {
    if (!canFinalize) {
      throw StateError('当前状态不能结束录音：${_state.name}');
    }
    final meetingId = _meetingId!;
    _state = RecordingState.finalizing;
    _userPaused = false;
    final subscription = _audioSubscription;
    if (subscription != null && subscription.isPaused) {
      subscription.resume();
    }

    try {
      await _stopCaptureForFinalization();
      await _writeTail;
      _throwWriteErrorIfAny();
      if (_persistedBytes == 0) {
        throw const ReliableRecordingException(
          code: 'recording.audio_empty',
          message: '事实音频为空',
        );
      }

      await _flushOutput();
      await _closeOutput();
      final finalPath = layout.meetingAudioPath(meetingId);
      await fileCommitter.commit(
        tempPath: layout.meetingAudioTempPath(meetingId),
        finalPath: finalPath,
        persistReference: (_) async {},
      );
      _state = RecordingState.completed;
      await _saveCheckpointBestEffort(RecordingCheckpointState.finalized);
      return RecordingArtifact(
        meetingId: meetingId,
        audioPath: finalPath,
        bytes: _persistedBytes,
      );
    } on Object catch (error, stackTrace) {
      _state = RecordingState.failed;
      await _closeOutputBestEffort();
      await _saveCheckpointBestEffort(RecordingCheckpointState.failed);
      if (error is ReliableRecordingException) {
        rethrow;
      }
      Error.throwWithStackTrace(
        ReliableRecordingException(
          code: 'recording.finalize_failed',
          message: '事实音频封存失败',
          cause: error,
        ),
        stackTrace,
      );
    } finally {
      await _cleanupCaptureBestEffort();
    }
  }

  void _queueChunk(
    StreamSubscription<Uint8List> subscription,
    Uint8List bytes,
  ) {
    if (!subscription.isPaused) {
      subscription.pause();
    }
    final copy = Uint8List.fromList(bytes);
    _writeTail = _writeTail.then((_) => _persistChunk(copy)).then((_) {
      if (!_userPaused &&
          _writeError == null &&
          _state == RecordingState.recording) {
        subscription.resume();
      }
    });
  }

  Future<void> _persistChunk(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return;
    }
    if (bytes.length.isOdd) {
      final error = ReliableRecordingException(
        code: 'recording.pcm_alignment_invalid',
        message: '收到未对齐 PCM16 样本边界的音频块',
      );
      _writeError = error;
      _writeStackTrace = StackTrace.current;
      throw error;
    }
    final output = _output;
    if (output == null) {
      throw StateError('事实音频文件未打开');
    }

    try {
      final startByteOffset = _persistedBytes;
      await output.writeFrom(bytes);
      await output.flush();
      _persistedBytes += bytes.length;
      await _saveCheckpoint(
        _state == RecordingState.paused
            ? RecordingCheckpointState.paused
            : RecordingCheckpointState.recording,
      );
      _pcmDiagnostics.addChunk(bytes, startByteOffset: startByteOffset);
      _preview.offer(
        RecordingPcmChunk(bytes: bytes, startByteOffset: startByteOffset),
      );
    } on Object catch (error, stackTrace) {
      _writeError ??= error;
      _writeStackTrace ??= stackTrace;
      _state = RecordingState.failed;
      rethrow;
    }
  }

  Future<void> _saveCheckpoint(RecordingCheckpointState state) {
    return checkpoints.save(
      RecordingCheckpoint(
        meetingId: _meetingId!,
        state: state,
        persistedBytes: _persistedBytes,
        updatedAt: now().toUtc(),
      ),
    );
  }

  Future<void> _flushOutput() async {
    await _output?.flush();
  }

  Future<void> _closeOutput() async {
    final output = _output;
    _output = null;
    if (output != null) {
      await output.flush();
      await output.close();
    }
  }

  void _throwWriteErrorIfAny() {
    final error = _writeError;
    if (error != null) {
      Error.throwWithStackTrace(error, _writeStackTrace ?? StackTrace.current);
    }
  }

  void _completeCapture() {
    final done = _captureDone;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
  }

  Future<void> _stopCaptureForFinalization() async {
    try {
      await capture.stop().timeout(captureStopTimeout);
    } on TimeoutException {
      _captureStopTimedOut = true;
      await _detachAudioSubscriptionBestEffort();
      return;
    }

    try {
      await _captureDone!.future.timeout(captureStopTimeout);
    } on TimeoutException {
      await _detachAudioSubscriptionBestEffort();
    }
  }

  Future<void> _detachAudioSubscriptionBestEffort() async {
    final subscription = _audioSubscription;
    _audioSubscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel().timeout(captureStopTimeout);
      } on Object {
        // 平台流无法正常结束时只封存已经完成写盘的事实音频。
      }
    }
    _completeCapture();
  }

  Future<void> _cleanupFailedStart(String meetingId) async {
    await _closeOutputBestEffort();
    await _cleanupCaptureBestEffort();
    try {
      await checkpoints.delete(meetingId);
    } on Object {
      // 启动失败的原始错误优先；残留 checkpoint 由启动恢复收敛。
    }
    final temp = File(layout.meetingAudioTempPath(meetingId));
    try {
      if (await temp.exists() && await temp.length() == 0) {
        await temp.delete();
      }
    } on Object {
      // 空临时文件清理失败不会覆盖启动错误。
    }
  }

  Future<void> _cleanupCaptureBestEffort() async {
    _preview.close();
    await _audioLevelMeter.dispose();
    await _detachAudioSubscriptionBestEffort();
    if (_captureStopTimedOut) {
      unawaited(_releasePlatformCaptureBestEffort());
      return;
    }
    await _releasePlatformCaptureBestEffort();
  }

  Future<void> _releasePlatformCaptureBestEffort() async {
    try {
      await foreground.stop().timeout(captureStopTimeout);
    } on Object {
      // 事实音频状态已确定，前台服务清理失败只作为平台诊断。
    }
    if (!_captureStopTimedOut) {
      try {
        await capture.stop().timeout(captureStopTimeout);
      } on Object {
        // recorder 可能已经停止或启动尚未完成。
      }
    }
    try {
      await capture.dispose().timeout(captureStopTimeout);
    } on Object {
      // 资源释放失败不得覆盖已经封存的事实音频。
    }
    _completeCapture();
  }

  Future<void> _closeOutputBestEffort() async {
    try {
      await _closeOutput();
    } on Object {
      // 保留原始录音错误，启动恢复会重新检查临时文件。
    }
  }

  Future<void> _saveCheckpointBestEffort(RecordingCheckpointState state) async {
    try {
      await _saveCheckpoint(state);
    } on Object {
      // 最终文件或原始失败优先，checkpoint 可由启动恢复重建。
    }
  }
}
