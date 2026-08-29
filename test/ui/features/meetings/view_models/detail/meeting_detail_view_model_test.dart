import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/build_meeting_share.dart';
import 'package:meettrace/domain/use_cases/run_final_transcription.dart';
import 'package:meettrace/domain/use_cases/run_speaker_diarization.dart';
import 'package:meettrace/ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';

import '../../../../../support/final_transcription_fakes.dart';

void main() {
  test('processing 会议自动使用锁定模型并接收完整音频进度', () async {
    final fixture = _fixture(_meeting());
    final completed = _snapshot(id: 'final-1');
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final meeting = fixture.meetings.value!.activateFinalTranscript(
            completed,
          );
          fixture.meetings.value = meeting;
          fixture.transcripts.records[completed.id] = completed;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();

    expect(fixture.runner.calls.single.modelId, senseVoiceDefaultModelId);
    expect(fixture.runner.calls.single.modelVersion, '2024-07-17');
    expect(fixture.viewModel.progress, 1);
    expect(fixture.viewModel.snapshot?.id, completed.id);
    expect(fixture.viewModel.meeting.status, MeetingState.completed);
    await fixture.dispose();
  });

  test('失败后重试复用失败 snapshot ID 和来源模型', () async {
    final fixture = _fixture(_meeting());
    final failed = _snapshot(
      id: 'failed-1',
      status: TranscriptSnapshotStatus.failed,
    );
    var attempt = 0;
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          attempt++;
          if (attempt == 1) {
            fixture.transcripts.records[failed.id] = failed;
            fixture.meetings.value = fixture.meetings.value!.fail(
              errorCode: 'asr.failed',
            );
            throw StateError('failed');
          }
          final completed = _snapshot(id: failed.id);
          final processing = fixture.meetings.value!.beginFinalTranscription();
          final meeting = processing.activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          fixture.transcripts.records[completed.id] = completed;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();
    expect(fixture.viewModel.canRetry, isTrue);

    await fixture.viewModel.retry();

    final retry = fixture.runner.calls.last;
    expect(retry.retrySnapshotId, failed.id);
    expect(retry.modelId, senseVoiceDefaultModelId);
    expect(retry.modelVersion, '2024-07-17');
    expect(
      fixture.viewModel.snapshot?.status,
      TranscriptSnapshotStatus.complete,
    );
    await fixture.dispose();
  });

  test('完成后使用本场锁定 SenseVoice 生成独立重转录', () async {
    final active = _snapshot(id: 'old');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
    );
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final completed = _snapshot(
            id: 'sense-voice-new',
            modelId: senseVoiceDefaultModelId,
            modelVersion: '2024-07-17',
          );
          final processing = fixture.meetings.value!.beginFinalTranscription();
          final meeting = processing.activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };
    await fixture.viewModel.load();

    await fixture.viewModel.retranscribe();

    expect(fixture.runner.calls.single.modelId, senseVoiceDefaultModelId);
    expect(fixture.runner.calls.single.retrySnapshotId, isNull);
    expect(fixture.viewModel.snapshot?.id, 'sense-voice-new');
    await fixture.dispose();
  });

  test('恢复 processing 快照时复用原 ID 和来源模型而不改回锁定模型', () async {
    final pending = _snapshot(
      id: 'sense-voice-pending',
      status: TranscriptSnapshotStatus.processing,
      modelId: senseVoiceDefaultModelId,
      modelVersion: '2024-07-17',
    );
    final fixture = _fixture(_meeting());
    fixture.transcripts.records[pending.id] = pending;
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final completed = _snapshot(
            id: pending.id,
            modelId: senseVoiceDefaultModelId,
            modelVersion: '2024-07-17',
          );
          final meeting = fixture.meetings.value!.activateFinalTranscript(
            completed,
          );
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();

    final resumed = fixture.runner.calls.single;
    expect(resumed.retrySnapshotId, pending.id);
    expect(resumed.modelId, senseVoiceDefaultModelId);
    expect(resumed.modelVersion, '2024-07-17');
    await fixture.dispose();
  });

  test('历史替代模型的 processing 快照不复用并改用本场锁定模型', () async {
    final pending = _snapshot(
      id: 'legacy-pending',
      status: TranscriptSnapshotStatus.processing,
      modelId: 'legacy-alternative-model',
      modelVersion: '2025-01-01',
    );
    final fixture = _fixture(_meeting());
    fixture.transcripts.records[pending.id] = pending;
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) async {
          final completed = _snapshot(id: 'locked-model-attempt');
          final meeting = fixture.meetings.value!.activateFinalTranscript(
            completed,
          );
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await fixture.viewModel.load();

    final resumed = fixture.runner.calls.single;
    expect(resumed.retrySnapshotId, isNull);
    expect(resumed.modelId, senseVoiceDefaultModelId);
    expect(resumed.modelVersion, '2024-07-17');
    await fixture.dispose();
  });

  test('说话人服务失败后最终转录仍可用并显示独立降级状态', () async {
    final active = _snapshot(id: 'active');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: _snapshot(id: 'active', speakerId: 'speaker-1'),
        status: SpeakerDiarizationStatus.degraded,
        errorCode: 'speaker_diarization.timeout',
      ),
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
      diarizationEnabled: true,
    );

    await fixture.viewModel.load();

    expect(diarization.processCalls, 1);
    expect(
      fixture.viewModel.snapshot?.status,
      TranscriptSnapshotStatus.complete,
    );
    expect(
      fixture.viewModel.diarizationStatus,
      SpeakerDiarizationStatus.degraded,
    );
    expect(fixture.viewModel.diarizationMessage, contains('单一说话人'));
    expect(fixture.viewModel.errorMessage, isNull);
    await fixture.dispose();
  });

  test('人工修改说话人标签后刷新最终快照', () async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-a');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.disabled,
      ),
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
    );
    await fixture.viewModel.load();

    await fixture.viewModel.renameSpeaker('speaker-a', ' 张三 ');

    expect(diarization.renameCalls.single, ('speaker-a', ' 张三 '));
    expect(fixture.viewModel.snapshot?.segments.single.speakerId, '张三');
    await fixture.dispose();
  });

  test('重新打开页面会从持久化失败任务恢复降级提示且不重复运行', () async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.degraded,
      ),
    );
    final tasks = _TaskRepository([
      ProcessingTask(
        id: 'speaker-diarization-active',
        kind: ProcessingTaskKind.speakerDiarization,
        meetingId: 'meeting-1',
        state: ProcessingState.failed,
        createdAt: DateTime.utc(2026, 7, 25, 3),
        updatedAt: DateTime.utc(2026, 7, 25, 3),
        lastErrorCode: 'speaker_diarization.timeout',
      ),
    ]);
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
      diarizationEnabled: true,
      processingTasks: tasks,
    );

    await fixture.viewModel.load();

    expect(diarization.processCalls, 0);
    expect(
      fixture.viewModel.diarizationStatus,
      SpeakerDiarizationStatus.degraded,
    );
    expect(fixture.viewModel.diarizationMessage, contains('最终转录不受影响'));
    await fixture.dispose();
  });

  test('详情 ViewModel 公开单一一致状态', () async {
    final active = _snapshot(id: 'active');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
    );

    await fixture.viewModel.load();

    final viewModel = fixture.viewModel;
    expect(viewModel.meeting.activeTranscriptSnapshotId, active.id);
    expect(viewModel.snapshot, same(active));
    expect(viewModel.sourceModel.modelId, senseVoiceDefaultModelId);
    expect(viewModel.speakerGroups, hasLength(1));
    expect(viewModel.canShare, isFalse);
    expect(viewModel.canShareAudio, isFalse);
    await fixture.dispose();
  });
}

_Fixture _fixture(
  Meeting meeting, {
  TranscriptSnapshot? active,
  SpeakerDiarizationRunner? diarization,
  bool diarizationEnabled = false,
  ProcessingTaskRepository? processingTasks,
}) {
  final meetings = DetailMeetingRepository(meeting);
  final transcripts = DetailTranscriptRepository();
  if (active != null) {
    transcripts.records[active.id] = active;
  }
  final taskRepository = DetailProcessingTaskRepository();
  final selectedTasks = processingTasks ?? taskRepository;
  late final DetailTranscriptionRunner runner;
  runner = DetailTranscriptionRunner(
    ({
      required meetingId,
      required modelId,
      required modelVersion,
      required retrySnapshotId,
      required onProgress,
    }) => throw UnimplementedError(),
  );
  return _Fixture(
    meetings: meetings,
    transcripts: transcripts,
    runner: runner,
    viewModel: MeetingDetailViewModel(
      meeting: meeting,
      meetings: meetings,
      transcripts: transcripts,
      transcription: runner,
      diarization: diarization,
      diarizationPreferences: _DiarizationPreference(diarizationEnabled),
      processingTasks: selectedTasks,
      shareBuilderProvider: () => const BuildMeetingShareUseCase(),
      speakerLabelBuilder: (number) => '说话人 $number',
    ),
  );
}

final class _Fixture {
  const _Fixture({
    required this.meetings,
    required this.transcripts,
    required this.runner,
    required this.viewModel,
  });

  final DetailMeetingRepository meetings;
  final DetailTranscriptRepository transcripts;
  final DetailTranscriptionRunner runner;
  final MeetingDetailViewModel viewModel;

  Future<void> dispose() async {
    viewModel.dispose();
  }
}

Meeting _meeting({
  String title = '周会',
  MeetingState status = MeetingState.processing,
  String? activeTranscriptSnapshotId,
}) {
  return Meeting(
    id: 'meeting-1',
    title: title,
    createdAt: DateTime.utc(2026, 7, 25),
    startedAt: DateTime.utc(2026, 7, 25, 1),
    endedAt: DateTime.utc(2026, 7, 25, 1, 0, 2),
    status: status,
    audioPath: '/audio/fact.pcm',
    audioDurationMs: 2000,
    recordingModelId: senseVoiceDefaultModelId,
    recordingModelVersion: '2024-07-17',
    activeTranscriptSnapshotId: activeTranscriptSnapshotId,
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
  String modelId = senseVoiceDefaultModelId,
  String modelVersion = '2024-07-17',
  String? speakerId,
}) {
  return TranscriptSnapshot(
    id: id,
    meetingId: 'meeting-1',
    kind: TranscriptSnapshotKind.finalTranscript,
    actualModelId: modelId,
    actualModelVersion: modelVersion,
    createdAt: DateTime.utc(2026, 7, 25, 2),
    status: status,
    segments: status == TranscriptSnapshotStatus.complete
        ? [
            TranscriptSegment(
              id: '$id-segment',
              snapshotId: id,
              startMs: 0,
              endMs: 1000,
              text: '最终事实文本',
              speakerId: speakerId,
              modelId: modelId,
              modelVersion: modelVersion,
            ),
          ]
        : const [],
  );
}

final class _DiarizationPreference implements DiarizationPreferenceRepository {
  _DiarizationPreference(this.enabled);

  bool enabled;

  @override
  Future<bool> getEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }
}

final class _DiarizationRunner implements SpeakerDiarizationRunner {
  _DiarizationRunner({required this.result});

  SpeakerDiarizationResult result;
  int processCalls = 0;
  final List<(String?, String)> renameCalls = [];

  @override
  SpeakerDiarizationCapability get capability =>
      const SpeakerDiarizationCapability.available();

  @override
  Future<SpeakerDiarizationResult> process({
    required String meetingId,
    required String snapshotId,
    required bool enabled,
  }) async {
    processCalls++;
    return result;
  }

  @override
  Future<TranscriptSnapshot> renameSpeaker({
    required String meetingId,
    required String snapshotId,
    required String? currentSpeakerId,
    required String newLabel,
  }) async {
    renameCalls.add((currentSpeakerId, newLabel));
    final source = result.snapshot;
    final updated = TranscriptSnapshot(
      id: source.id,
      meetingId: source.meetingId,
      kind: source.kind,
      actualModelId: source.actualModelId,
      actualModelVersion: source.actualModelVersion,
      createdAt: source.createdAt,
      status: source.status,
      segments: [
        for (final segment in source.segments)
          TranscriptSegment(
            id: segment.id,
            snapshotId: segment.snapshotId,
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
            speakerId: newLabel.trim(),
            confidence: segment.confidence,
            modelId: segment.modelId,
            modelVersion: segment.modelVersion,
          ),
      ],
    );
    result = SpeakerDiarizationResult(
      snapshot: updated,
      status: result.status,
      errorCode: result.errorCode,
    );
    return updated;
  }
}

final class _TaskRepository implements ProcessingTaskRepository {
  _TaskRepository(this.records);

  final List<ProcessingTask> records;

  @override
  Future<ProcessingTask?> getById(String taskId) async {
    for (final task in records) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  @override
  Future<List<ProcessingTask>> listByMeeting(String meetingId) async =>
      records.where((task) => task.meetingId == meetingId).toList();

  @override
  Future<void> save(ProcessingTask task) async {
    records.removeWhere((record) => record.id == task.id);
    records.add(task);
  }
}
