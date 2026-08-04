import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/audio_playback.dart';
import 'package:meettrace/domain/ports/audio_share.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/use_cases/run_final_transcription.dart';
import 'package:meettrace/domain/use_cases/run_speaker_diarization.dart';
import 'package:meettrace/domain/use_cases/share_meeting_audio.dart';
import 'package:meettrace/ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';
import 'package:meettrace/ui/features/meetings/views/detail/meeting_detail_view.dart';

import '../../../../../support/final_transcription_fakes.dart';

void main() {
  testWidgets('完成页显示最终事实文本并可用锁定 SenseVoice 生成独立快照', (tester) async {
    final old = _snapshot(id: 'old');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: old.id,
      ),
      active: old,
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
            text: 'SenseVoice 新最终文本',
          );
          final meeting = fixture.meetings.value!
              .beginFinalTranscription()
              .activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('最终事实文本'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('segment-text-old-segment')),
      findsNothing,
    );
    await tester.tap(find.text('录音'));
    await tester.pumpAndSettle();
    expect(find.textContaining('本场锁定的 SenseVoice'), findsOneWidget);
    final retranscribe = find.text('使用本场锁定模型重新转录');
    await tester.ensureVisible(retranscribe);
    await tester.tap(retranscribe);
    await tester.pumpAndSettle();

    expect(fixture.runner.calls.single.modelId, senseVoiceDefaultModelId);
    expect(fixture.runner.calls.single.retrySnapshotId, isNull);
    final transcriptTab = find.text('转录');
    await tester.ensureVisible(transcriptTab);
    await tester.pumpAndSettle();
    await tester.tap(transcriptTab);
    await tester.pumpAndSettle();
    expect(find.textContaining('SenseVoice 新最终文本'), findsOneWidget);
    expect(find.textContaining('来源模型：SenseVoice'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('处理失败显示保留事实提示并以同一快照重试', (tester) async {
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
          final completed = _snapshot(id: failed.id, text: '重试后的最终文本');
          final meeting = fixture.meetings.value!
              .beginFinalTranscription()
              .activateFinalTranscript(completed);
          fixture.meetings.value = meeting;
          fixture.transcripts.records[completed.id] = completed;
          return FinalTranscriptionResult(
            meeting: meeting,
            snapshot: completed,
          );
        };

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最终转录未完成'), findsOneWidget);
    expect(find.textContaining('事实音频和旧结果均已保留'), findsOneWidget);

    await tester.tap(find.text('重试最终转录'));
    await tester.pumpAndSettle();

    expect(fixture.runner.calls.last.retrySnapshotId, failed.id);
    expect(find.textContaining('重试后的最终文本'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('未配置分离模型时仍可手工保存说话人标签', (tester) async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.disabled,
      ),
      available: false,
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: diarization,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('当前构建未配置已验证'), findsOneWidget);
    expect(find.textContaining('说话人 1 · 00:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-transcript')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('speaker-label-speaker-1'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '张三');
    final save = find.byKey(const ValueKey('save-speaker-label-speaker-1'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(diarization.renameCalls.single, ('speaker-1', '张三'));
    expect(find.textContaining('张三 · 00:00'), findsOneWidget);
    expect(find.text('说话人标签已保存'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('分离失败提示降级但继续显示最终转录', (tester) async {
    final active = _snapshot(id: 'active');
    final degraded = _snapshot(id: 'active', speakerId: 'speaker-1');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      diarization: _DiarizationRunner(
        result: SpeakerDiarizationResult(
          snapshot: degraded,
          status: SpeakerDiarizationStatus.degraded,
          errorCode: 'speaker_diarization.timeout',
        ),
      ),
      diarizationEnabled: true,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('最终事实文本'), findsOneWidget);
    expect(find.text('说话人分离已降级'), findsOneWidget);
    expect(find.textContaining('最终转录不受影响'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('录音页播放完整事实音频区间', (tester) async {
    final active = _snapshot(id: 'active');
    final playback = _Playback();
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      playback: playback,
    );
    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('录音'));
    await tester.pumpAndSettle();
    final playButton = find.byKey(const ValueKey('toggle-audio-playback'));
    await tester.ensureVisible(playButton);
    await tester.tap(playButton);
    await tester.pump(const Duration(milliseconds: 200));

    expect(playback.calls, [('/audio/fact.pcm', 0, 2000)]);
    await fixture.dispose();
  });

  testWidgets('音频分享先展示元数据和敏感提醒，二次确认后才调用独立分享', (tester) async {
    final active = _snapshot(id: 'active');
    final audioShare = _AudioShare();
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      audioShare: audioShare,
    );
    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('录音'));
    await tester.pumpAndSettle();
    final request = find.byKey(const ValueKey('request-share-audio'));
    await tester.ensureVisible(request);
    await tester.tap(request);
    await tester.pumpAndSettle();

    expect(audioShare.shareCalls, 0);
    expect(find.text('确认单独分享音频？'), findsOneWidget);
    expect(find.textContaining('会议：周会'), findsOneWidget);
    expect(find.textContaining('时长：00:02'), findsOneWidget);
    expect(find.textContaining('31.3 KiB WAV'), findsOneWidget);
    expect(find.textContaining('敏感或私密信息'), findsOneWidget);
    expect(find.textContaining('不会附带转录文本'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-share-audio')));
    await tester.pumpAndSettle();

    expect(audioShare.inspectCalls, 1);
    expect(audioShare.shareCalls, 1);
    expect(find.text('音频分享操作已完成，临时文件已清理'), findsOneWidget);
    await fixture.dispose();
  });

  testWidgets('音频分享空间不足显示精确差额且不显示确认操作', (tester) async {
    final active = _snapshot(id: 'active');
    final audioShare = _AudioShare(freeBytes: 32000);
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      audioShare: audioShare,
    );
    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('录音'));
    await tester.pumpAndSettle();
    final request = find.byKey(const ValueKey('request-share-audio'));
    await tester.ensureVisible(request);
    await tester.tap(request);
    await tester.pumpAndSettle();

    expect(find.text('可用空间不足'), findsOneWidget);
    expect(find.textContaining('还缺少 44 B'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-share-audio')), findsNothing);
    expect(audioShare.shareCalls, 0);
    await fixture.dispose();
  });

  testWidgets('插件缓存清理失败时不显示已清理', (tester) async {
    final active = _snapshot(id: 'active');
    final audioShare = _AudioShare(
      shareError: const AudioShareException('audio_share.cleanup_failed'),
    );
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      audioShare: audioShare,
    );
    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('录音'));
    await tester.pumpAndSettle();
    final request = find.byKey(const ValueKey('request-share-audio'));
    await tester.ensureVisible(request);
    await tester.tap(request);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-share-audio')));
    await tester.pumpAndSettle();

    expect(find.text('音频分享临时文件清理失败，请重启应用后重试'), findsOneWidget);
    expect(find.textContaining('临时文件已清理'), findsNothing);
    await fixture.dispose();
  });

  testWidgets('处理中只显示真实阶段，不伪造百分比进度', (tester) async {
    final fixture = _fixture(_meeting());
    final completion = Completer<FinalTranscriptionResult>();
    fixture.runner.onCall =
        ({
          required meetingId,
          required modelId,
          required modelVersion,
          required retrySnapshotId,
          required onProgress,
        }) => completion.future;

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('正在生成联合最终结果'), findsOneWidget);
    expect(find.text('最终转录'), findsOneWidget);
    expect(find.text('说话人整理'), findsOneWidget);
    expect(find.textContaining('全部结束后才会发布结果'), findsOneWidget);
    expect(find.textContaining('单一说话人发布最终文本'), findsOneWidget);
    expect(find.text('AI 总结'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('事实音频'), findsWidgets);

    final snapshot = _snapshot(id: 'completed');
    final meeting = fixture.meetings.value!.activateFinalTranscript(snapshot);
    fixture.meetings.value = meeting;
    completion.complete(
      FinalTranscriptionResult(meeting: meeting, snapshot: snapshot),
    );
    await tester.pumpAndSettle();
    await fixture.dispose();
  });

  testWidgets('转录默认只读，用户主动进入编辑后才显示输入框', (tester) async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最终事实文本'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('segment-text-active-segment')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('speaker-label-speaker-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('edit-transcript')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('segment-text-active-segment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('speaker-label-speaker-1')),
      findsOneWidget,
    );
    await fixture.dispose();
  });

  testWidgets('320 宽度和 2.0 字体缩放下结果三视图不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final active = _snapshot(id: 'active');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('转录'), findsWidgets);
    expect(find.text('录音'), findsOneWidget);
    expect(find.text('总结'), findsNothing);
    expect(tester.takeException(), isNull);
    await fixture.dispose();
  });

  for (final width in [375.0, 414.0, 768.0, 1024.0]) {
    testWidgets('${width.round()} 宽度下结果阅读视图不溢出', (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final active = _snapshot(id: 'active');
      final fixture = _fixture(
        _meeting(
          status: MeetingState.completed,
          activeTranscriptSnapshotId: active.id,
        ),
        active: active,
      );

      await tester.pumpWidget(
        Application(
          home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('最终事实文本'), findsOneWidget);
      expect(find.byKey(const ValueKey('meeting-result-tabs')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meeting-detail-audio-workbench')),
        width >= 840 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await fixture.dispose();
    });
  }
}

_Fixture _fixture(
  Meeting meeting, {
  TranscriptSnapshot? active,
  SpeakerDiarizationRunner? diarization,
  bool diarizationEnabled = false,
  AudioPlaybackService? playback,
  AudioShareService? audioShare,
}) {
  final meetings = DetailMeetingRepository(meeting);
  final transcripts = DetailTranscriptRepository();
  if (active != null) {
    transcripts.records[active.id] = active;
  }
  final tasks = DetailProcessingTaskRepository();
  final runner = DetailTranscriptionRunner(
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
      processingTasks: tasks,
      playback: playback,
      audioSharing: audioShare == null
          ? null
          : ShareMeetingAudioUseCase(audioShare),
    ),
  );
}

final class _Playback implements AudioPlaybackService {
  final List<(String, int, int)> calls = [];

  @override
  Stream<AudioPlaybackState> get states => const Stream.empty();

  @override
  Future<void> play({
    required String audioPath,
    required int startMs,
    required int endMs,
  }) async {
    calls.add((audioPath, startMs, endMs));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _AudioShare implements AudioShareService {
  _AudioShare({this.freeBytes = 1024 * 1024, this.shareError});

  final int freeBytes;
  final Object? shareError;
  int inspectCalls = 0;
  int shareCalls = 0;

  @override
  Future<AudioShareStorageSnapshot> inspect({required String audioPath}) async {
    inspectCalls++;
    return AudioShareStorageSnapshot(
      pcmBytes: 32000,
      wavBytes: 32044,
      freeBytes: freeBytes,
    );
  }

  @override
  Future<AudioShareOutcome> share({
    required String meetingId,
    required String meetingTitle,
    required String audioPath,
    required int expectedPcmBytes,
  }) async {
    shareCalls++;
    if (shareError case final error?) {
      throw error;
    }
    return AudioShareOutcome.completed;
  }
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
  MeetingState status = MeetingState.processing,
  String? activeTranscriptSnapshotId,
}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
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
  String text = '最终事实文本',
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
              text: text,
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
  _DiarizationRunner({required this.result, this.available = true});

  SpeakerDiarizationResult result;
  final bool available;
  final List<(String?, String)> renameCalls = [];

  @override
  SpeakerDiarizationCapability get capability => available
      ? const SpeakerDiarizationCapability.available()
      : const SpeakerDiarizationCapability.unavailable(
          reasonCode: 'speaker_diarization.model_unavailable',
        );

  @override
  Future<SpeakerDiarizationResult> process({
    required String meetingId,
    required String snapshotId,
    required bool enabled,
  }) async {
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
