import '../models/asr_model_registry.dart';
import '../models/meeting.dart';
import '../models/meeting_readiness.dart';
import '../models/workflow_states.dart';
import '../ports/asr_engine.dart';
import '../ports/repositories.dart';
import 'check_meeting_readiness.dart';

final class StartedMeetingSession {
  const StartedMeetingSession({required this.meeting, required this.engine});

  final Meeting meeting;
  final AsrEngine engine;
}

enum StartMeetingBlockReason { readiness }

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
  }) : registry = registry ?? AsrModelRegistry.alpha;

  final MeetingRepository meetings;
  final AsrEngineFactory engineFactory;
  final MeetingReadinessChecker readinessChecker;
  final String Function() meetingIdFactory;
  final DateTime Function() now;
  final AsrModelRegistry registry;

  Future<StartedMeetingSession> execute() async {
    final readiness = await readinessChecker.check(
      requestMicrophonePermission: true,
    );
    if (!readiness.canStart) {
      throw StartMeetingBlocked(
        StartMeetingBlockReason.readiness,
        readiness: readiness,
      );
    }
    final descriptor = registry.requireById(readiness.defaultModelId);
    if (readiness.defaultModelVersion != descriptor.version) {
      throw StateError(
        '就绪检查返回的模型版本与 Registry 不一致：'
        '${readiness.defaultModelId}@${readiness.defaultModelVersion}',
      );
    }
    AsrEngine? engine;
    try {
      engine = await engineFactory.create(
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        language: descriptor.language,
        useInverseTextNormalization: descriptor.useInverseTextNormalization,
      );
      await engine.initialize();
      final timestamp = now();
      final created = Meeting(
        id: meetingIdFactory(),
        title: meetingTitleForStartTime(timestamp),
        createdAt: timestamp,
        status: MeetingState.created,
        audioDurationMs: 0,
        recordingModelId: descriptor.modelId,
        recordingModelVersion: descriptor.version,
        recordingModelLanguage: descriptor.language,
        recordingModelUseInverseTextNormalization:
            descriptor.useInverseTextNormalization,
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
