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

enum StartMeetingBlockReason { readiness, modelUnavailable }

final class StartMeetingBlocked implements Exception {
  const StartMeetingBlocked(this.reason, {this.readiness});

  final StartMeetingBlockReason reason;
  final MeetingReadiness? readiness;
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
      throw const StartMeetingBlocked(StartMeetingBlockReason.modelUnavailable);
    }

    final selection = resolveSelection(
      globalDefaultModelId: defaultModelId,
      availableVersions: availableVersions,
    );
    AsrEngine? engine;
    try {
      engine = await engineFactory.create(
        modelId: selection.recordingModelId,
        modelVersion: selection.recordingModelVersion,
        language: selection.recordingModelLanguage,
        useInverseTextNormalization:
            selection.recordingModelUseInverseTextNormalization,
      );
      await engine.initialize();
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
        recordingModelLanguage: selection.recordingModelLanguage,
        recordingModelUseInverseTextNormalization:
            selection.recordingModelUseInverseTextNormalization,
        modelFallbackReason: selection.fallbackReason,
      );
      final started = created.startRecording(startedAt: timestamp);
      await meetings.save(started);
      return StartedMeetingSession(meeting: started, engine: engine);
    } on Object {
      await engine?.dispose();
      rethrow;
    }
  }
}
