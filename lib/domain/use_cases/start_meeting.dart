import '../models/asr_model_registry.dart';
import '../models/meeting.dart';
import '../models/meeting_readiness.dart';
import '../models/recording_input.dart';
import '../models/workflow_states.dart';
import '../ports/asr_engine.dart';
import '../ports/repositories.dart';
import 'check_meeting_readiness.dart';
import 'lock_recording_input.dart';

final class StartedMeetingSession {
  const StartedMeetingSession({
    required this.meeting,
    required this.engine,
    required this.recordingInput,
  });

  final Meeting meeting;
  final AsrEngine engine;
  final LockedRecordingInput recordingInput;
}

enum StartMeetingBlockReason { readiness, recordingInputUnavailable }

final class StartMeetingBlocked implements Exception {
  const StartMeetingBlocked(
    this.reason, {
    this.readiness,
    this.inputUnavailableReason,
  });

  final StartMeetingBlockReason reason;
  final MeetingReadiness? readiness;
  final RecordingInputUnavailableReason? inputUnavailableReason;
}

/// 校验真实启动条件、锁定模型并持久化会议的单一业务入口。
final class StartMeetingUseCase {
  StartMeetingUseCase({
    required this.meetings,
    required this.engineFactory,
    required this.readinessChecker,
    required this.meetingIdFactory,
    required this.now,
    required this.recordingInputLock,
    this.meetingTitleFactory = meetingTitleForStartTime,
    AsrModelRegistry? registry,
  }) : registry = registry ?? AsrModelRegistry.alpha;

  final MeetingRepository meetings;
  final AsrEngineFactory engineFactory;
  final MeetingReadinessChecker readinessChecker;
  final String Function() meetingIdFactory;
  final DateTime Function() now;
  final LockRecordingInputUseCase recordingInputLock;
  final String Function(DateTime) meetingTitleFactory;
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
      final recordingInput = await _lockRecordingInput();
      engine = await engineFactory.create(
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
        language: descriptor.language,
        useInverseTextNormalization: descriptor.useInverseTextNormalization,
      );
      final timestamp = now();
      final created = Meeting(
        id: meetingIdFactory(),
        title: meetingTitleFactory(timestamp),
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
      return StartedMeetingSession(
        meeting: started,
        engine: engine,
        recordingInput: recordingInput,
      );
    } on Object {
      await engine?.dispose();
      rethrow;
    }
  }

  Future<LockedRecordingInput> _lockRecordingInput() async {
    try {
      return await recordingInputLock.execute();
    } on RecordingInputUnavailableException catch (error) {
      throw StartMeetingBlocked(
        StartMeetingBlockReason.recordingInputUnavailable,
        inputUnavailableReason: error.reason,
      );
    }
  }
}
