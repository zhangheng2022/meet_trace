import '../models/app_failure.dart';
import '../models/asr_model_registry.dart';
import '../models/meeting.dart';
import '../models/meeting_readiness.dart';
import '../models/workflow_states.dart';
import '../ports/asr_engine.dart';
import '../ports/repositories.dart';
import 'check_meeting_readiness.dart';
import 'resolve_meeting_model_selection.dart';

final class StartedMeetingSession {
  const StartedMeetingSession({required this.meeting, required this.engine});

  final Meeting meeting;
  final AsrEngine engine;
}

enum StartMeetingBlockReason {
  readiness,
  standardModelUnavailable,
  advancedModelUnavailable,
}

final class StartMeetingBlocked implements Exception {
  const StartMeetingBlocked(this.reason, {this.readiness});

  final StartMeetingBlockReason reason;
  final MeetingReadiness? readiness;
}

final class StartMeetingException implements Exception {
  const StartMeetingException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'StartMeetingException(${failure.code})';
}

/// 校验真实启动条件、锁定模型并持久化会议的单一业务入口。
final class StartMeetingUseCase {
  StartMeetingUseCase({
    required this.meetings,
    required this.engineFactory,
    required this.readinessChecker,
    required this.meetingIdFactory,
    required this.now,
    AsrModelRegistry? registry,
    ResolveMeetingModelSelection? resolveSelection,
  }) : registry = registry ?? AsrModelRegistry.alpha,
       resolveSelection =
           resolveSelection ??
           ResolveMeetingModelSelection(
             registry: registry ?? AsrModelRegistry.alpha,
           );

  final MeetingRepository meetings;
  final AsrEngineFactory engineFactory;
  final MeetingReadinessChecker readinessChecker;
  final String Function() meetingIdFactory;
  final DateTime Function() now;
  final AsrModelRegistry registry;
  final ResolveMeetingModelSelection resolveSelection;

  Future<StartedMeetingSession> execute({
    required String defaultModelId,
    required Map<String, String> availableVersions,
  }) async {
    final readiness = await readinessChecker.check(
      requestMicrophonePermission: true,
    );
    if (!readiness.canStart) {
      throw StartMeetingBlocked(
        StartMeetingBlockReason.readiness,
        readiness: readiness,
      );
    }
    if (availableVersions[defaultModelId] == null) {
      throw StartMeetingBlocked(
        defaultModelId == whisperSmallAdvancedModelId
            ? StartMeetingBlockReason.advancedModelUnavailable
            : StartMeetingBlockReason.standardModelUnavailable,
      );
    }

    final selection = resolveSelection(
      globalDefaultModelId: defaultModelId,
      availableVersions: availableVersions,
    );
    AsrEngine engine;
    try {
      engine = await engineFactory.create(
        modelId: selection.recordingModelId,
        modelVersion: selection.recordingModelVersion,
        purpose: AsrEnginePurpose.preview,
      );
    } on AsrEngineException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _startFailure(
          code: 'meeting.start.asr_factory_failed',
          modelId: selection.recordingModelId,
          modelVersion: selection.recordingModelVersion,
          error: error,
        ),
        stackTrace,
      );
    }

    try {
      await engine.initialize();
    } on AsrEngineException {
      await _disposeBestEffort(engine);
      rethrow;
    } on Object catch (error, stackTrace) {
      await _disposeBestEffort(engine);
      Error.throwWithStackTrace(
        _startFailure(
          code: 'meeting.start.asr_initialization_failed',
          modelId: selection.recordingModelId,
          modelVersion: selection.recordingModelVersion,
          error: error,
        ),
        stackTrace,
      );
    }

    try {
      final timestamp = now();
      final created = Meeting(
        id: meetingIdFactory(),
        title: pendingMeetingTitle,
        createdAt: timestamp,
        status: MeetingState.created,
        audioDurationMs: 0,
        requestedModelId: selection.requestedModelId,
        recordingModelId: selection.recordingModelId,
        recordingModelVersion: selection.recordingModelVersion,
        modelFallbackReason: selection.fallbackReason,
      );
      final started = created.startRecording(startedAt: timestamp);
      await meetings.save(started);
      return StartedMeetingSession(meeting: started, engine: engine);
    } on Object catch (error, stackTrace) {
      await _disposeBestEffort(engine);
      Error.throwWithStackTrace(
        _startFailure(
          code: 'meeting.start.persistence_failed',
          modelId: selection.recordingModelId,
          modelVersion: selection.recordingModelVersion,
          error: error,
          stage: FailureStage.storage,
        ),
        stackTrace,
      );
    }
  }
}

StartMeetingException _startFailure({
  required String code,
  required String modelId,
  required String modelVersion,
  required Object error,
  FailureStage stage = FailureStage.asrInitialization,
}) {
  return StartMeetingException(
    AppFailure(
      code: code,
      stage: stage,
      modelId: modelId,
      modelVersion: modelVersion,
      recoverability: FailureRecoverability.retryable,
      userAction: FailureUserAction.retry,
      diagnosticContext: {'errorType': error.runtimeType.toString()},
    ),
  );
}

Future<void> _disposeBestEffort(AsrEngine engine) async {
  try {
    await engine.dispose();
  } on Object {
    // 启动失败的原始错误优先，释放失败不能覆盖可执行诊断。
  }
}
