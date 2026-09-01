import '../../../domain/models/audio_source.dart';
import '../../../domain/models/speaker_diarization.dart';
import '../../../domain/ports/speaker_diarization.dart';
import '../monitoring/sentry_monitoring.dart';
import 'sherpa_onnx_speaker_diarization_worker.dart';
import 'speaker_diarization_worker.dart';

export '../../../domain/ports/speaker_diarization.dart';
export 'speaker_diarization_worker.dart';

/// 通过官方 sherpa_onnx Dart API 运行 Pyannote + 3D-Speaker 离线分离。
///
/// 每次任务创建独立 worker/isolate。取消或超时时直接终止 worker，确保同步的
/// 原生推理不会在 Domain 已经降级后继续占用内存和 CPU。
final class SherpaOnnxSpeakerDiarizationService
    implements SpeakerDiarizationService, SpeakerDiarizationServiceLifecycle {
  SherpaOnnxSpeakerDiarizationService({
    required this.config,
    this.workerFactory = const OfficialSpeakerDiarizationWorkerFactory(),
  });

  final SherpaOnnxSpeakerDiarizationConfig config;
  final SpeakerDiarizationWorkerFactory workerFactory;

  SpeakerDiarizationWorker? _activeWorker;
  var _operationActive = false;
  var _cancellationGeneration = 0;
  var _disposed = false;

  @override
  SpeakerDiarizationCapability get capability => _disposed
      ? const SpeakerDiarizationCapability.unavailable(
          reasonCode: 'speaker_diarization.disposed',
        )
      : const SpeakerDiarizationCapability.available();

  @override
  Future<List<SpeakerTurn>> diarize(AudioSource source) =>
      SentryMonitoring.trace(
        name: 'speaker.diarization',
        operation: 'speaker.diarization',
        isCancellation: (error) =>
            error is SpeakerDiarizationException &&
            error.code == 'speaker_diarization.cancelled',
        run: () => _diarize(source),
      );

  Future<List<SpeakerTurn>> _diarize(AudioSource source) async {
    _validateSource(source);
    if (_disposed) {
      throw const SpeakerDiarizationException('speaker_diarization.disposed');
    }
    if (_operationActive) {
      throw const SpeakerDiarizationException('speaker_diarization.busy');
    }

    _operationActive = true;
    final generation = _cancellationGeneration;
    SpeakerDiarizationWorker? worker;
    Object? failure;
    StackTrace? failureStackTrace;
    List<SpeakerDiarizationWorkerSegment>? segments;
    try {
      worker = await workerFactory.create(config);
      if (_disposed || generation != _cancellationGeneration) {
        await worker.cancel();
        throw const SpeakerDiarizationException(
          'speaker_diarization.cancelled',
        );
      }
      _activeWorker = worker;
      segments = await worker.diarize(source);
    } on Object catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    } finally {
      if (identical(_activeWorker, worker)) {
        _activeWorker = null;
      }
      _operationActive = false;
      if (worker != null) {
        try {
          await worker.dispose();
        } on Object catch (error, stackTrace) {
          failure ??= error;
          failureStackTrace ??= stackTrace;
        }
      }
    }

    if (failure case final error?) {
      Error.throwWithStackTrace(
        _mapFailure(error),
        failureStackTrace ?? StackTrace.current,
      );
    }
    return _mapSegments(segments!, source.durationMs);
  }

  @override
  Future<void> cancelActive() async {
    _cancellationGeneration++;
    final worker = _activeWorker;
    if (worker != null) {
      await worker.cancel();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await cancelActive();
  }

  void _validateSource(AudioSource source) {
    if (source.sampleRate != config.sampleRate || source.channelCount != 1) {
      throw const SpeakerDiarizationException(
        'speaker_diarization.invalid_audio',
      );
    }
  }

  List<SpeakerTurn> _mapSegments(
    List<SpeakerDiarizationWorkerSegment> segments,
    int audioDurationMs,
  ) {
    final turns = <SpeakerTurn>[];
    for (final segment in segments) {
      if (!segment.startSeconds.isFinite ||
          !segment.endSeconds.isFinite ||
          segment.startSeconds < 0 ||
          segment.endSeconds <= segment.startSeconds ||
          segment.speakerIndex < 0) {
        throw const SpeakerDiarizationException(
          'speaker_diarization.invalid_result',
        );
      }
      final startMs = (segment.startSeconds * 1000).round();
      final endMs = (segment.endSeconds * 1000).round();
      if (endMs <= startMs || endMs > audioDurationMs) {
        throw const SpeakerDiarizationException(
          'speaker_diarization.invalid_result',
        );
      }
      turns.add(
        SpeakerTurn(
          startMs: startMs,
          endMs: endMs,
          speakerId: 'speaker-${segment.speakerIndex + 1}',
        ),
      );
    }
    turns.sort((left, right) {
      final byStart = left.startMs.compareTo(right.startMs);
      return byStart != 0 ? byStart : left.speakerId.compareTo(right.speakerId);
    });
    return List.unmodifiable(turns);
  }

  SpeakerDiarizationException _mapFailure(Object error) {
    return switch (error) {
      SpeakerDiarizationException() => error,
      SpeakerDiarizationWorkerException(:final code) =>
        SpeakerDiarizationException(code),
      _ => const SpeakerDiarizationException('speaker_diarization.unexpected'),
    };
  }
}
