import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../domain/models/recording.dart';
import '../../../domain/models/workflow_states.dart';
import '../storage/app_file_layout.dart';
import '../storage/durable_file_committer.dart';
import 'recording_checkpoint_store.dart';
import 'recording_ports.dart';

const minimumRecordingFreeBytes = 128 * 1024 * 1024;

final class ReliableRecordingException implements Exception {
  const ReliableRecordingException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ReliableRecordingException($code, $message)';
}

final class ReliableRecordingService {
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
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _preview = RecordingPreviewDispatcher(
         previewSink,
         maxPendingChunks: maxPendingPreviewChunks,
       ) {
    if (minimumFreeBytes <= 0) {
      throw ArgumentError.value(minimumFreeBytes, 'minimumFreeBytes', '必须大于 0');
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
  final DateTime Function() now;
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
  int _persistedBytes = 0;

  RecordingState get state => _state;
  int get persistedBytes => _persistedBytes;
  Duration get duration => recordingDurationForBytes(_persistedBytes);
  int get droppedPreviewChunks => _preview.droppedChunks;

  Future<void> start({required String meetingId}) async {
    if (_state != RecordingState.idle) {
      throw StateError('录音实例只能启动一次');
    }
    _state = RecordingState.starting;
    _meetingId = meetingId;

    if (!await capture.hasPermission()) {
      _state = RecordingState.failed;
      throw const ReliableRecordingException(
        code: 'recording.permission_denied',
        message: '未获得麦克风权限',
      );
    }
    final freeBytes = await storageCapacity.getFreeBytes();
    if (freeBytes < minimumFreeBytes) {
      _state = RecordingState.failed;
      throw ReliableRecordingException(
        code: 'recording.storage_insufficient',
        message: '可用空间不足，至少需要 $minimumFreeBytes 字节',
      );
    }

    final tempFile = File(layout.meetingAudioTempPath(meetingId));
    final finalFile = File(layout.meetingAudioPath(meetingId));
    if (await tempFile.exists() || await finalFile.exists()) {
      _state = RecordingState.failed;
      throw const ReliableRecordingException(
        code: 'recording.audio_already_exists',
        message: '目标会议已有事实音频，拒绝覆盖',
      );
    }

    await tempFile.parent.create(recursive: true);
    _output = await tempFile.open(mode: FileMode.write);
    await _saveCheckpoint(RecordingCheckpointState.recording);

    try {
      await foreground.start(meetingId: meetingId);
      final stream = await capture.start();
      _captureDone = Completer<void>();
      late final StreamSubscription<Uint8List> subscription;
      subscription = stream.listen(
        (bytes) => _queueChunk(subscription, bytes),
        onError: (Object error, StackTrace stackTrace) {
          _writeError ??= error;
          _writeStackTrace ??= stackTrace;
          _state = RecordingState.failed;
          _completeCapture();
        },
        onDone: _completeCapture,
        cancelOnError: false,
      );
      _audioSubscription = subscription;
      _state = RecordingState.recording;
    } on Object catch (error) {
      await _cleanupFailedStart(meetingId);
      _state = RecordingState.failed;
      throw ReliableRecordingException(
        code: 'recording.start_failed',
        message: '无法启动录音',
        cause: error,
      );
    }
  }

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

  Future<RecordingArtifact> stop() async {
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
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
      await capture.stop();
      await _captureDone!.future.timeout(const Duration(seconds: 10));
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
      await _saveCheckpoint(RecordingCheckpointState.finalized);
      _state = RecordingState.completed;
      return RecordingArtifact(
        meetingId: meetingId,
        audioPath: finalPath,
        bytes: _persistedBytes,
      );
    } on Object catch (error, stackTrace) {
      _state = RecordingState.failed;
      await _closeOutput();
      await _saveCheckpoint(RecordingCheckpointState.failed);
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
      _preview.close();
      await foreground.stop();
      await capture.dispose();
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
      if (!_userPaused && _writeError == null) {
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

  Future<void> _cleanupFailedStart(String meetingId) async {
    try {
      await capture.stop();
    } on Object {
      // start 失败时 recorder 可能尚无活动 session。
    }
    await _closeOutput();
    await foreground.stop();
    await capture.dispose();
    await checkpoints.delete(meetingId);
    final temp = File(layout.meetingAudioTempPath(meetingId));
    if (await temp.exists() && await temp.length() == 0) {
      await temp.delete();
    }
  }
}
