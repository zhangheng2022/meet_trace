import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/final_transcription.dart';
import 'package:meettrace/domain/use_cases/build_meeting_share.dart';
import 'package:meettrace/ui/features/meetings/view_models/detail/meeting_detail_view_model.dart';
import 'package:meettrace/ui/features/meetings/views/detail/meeting_detail_view.dart';
import 'package:meettrace/l10n/l10n.dart';

import '../../../../../support/final_transcription_fakes.dart';

void main() {
  for (final language in [
    AppLanguageMode.simplifiedChinese,
    AppLanguageMode.english,
  ]) {
    testWidgets('在线窗口时间戳在 ${language.name} 详情明确显示约值与未知版本', (tester) async {
      final fixture = _Fixture(
        active: _snapshot(
          'coarse',
          _remote,
          timingPrecision: TranscriptTimingPrecision.audioWindow,
        ),
      );
      final locale = ValueNotifier(language);
      addTearDown(locale.dispose);
      addTearDown(fixture.vm.dispose);
      await tester.pumpWidget(
        Application(
          languageMode: locale,
          home: MeetingDetailView(viewModel: fixture.vm, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(MeetingDetailView)).l10n;
      expect(find.text(l10n.sourceTimingWindow), findsOneWidget);
      expect(find.textContaining(l10n.sourceVersionUnknown), findsOneWidget);
      expect(find.text('≈00:00'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('当前在线最终稿的普通重转录沿用该稿冻结配置', () async {
    final old = _snapshot('online-active', _remote);
    final fixture = _Fixture(active: old);
    addTearDown(fixture.vm.dispose);
    fixture.runner.onSelection = (profile) async {
      final completed = _snapshot('online-next', profile);
      final meeting = fixture.meetings.value!
          .beginFinalTranscription()
          .activateFinalTranscript(completed);
      fixture.meetings.value = meeting;
      fixture.transcripts.records[completed.id] = completed;
      return FinalTranscriptionResult(meeting: meeting, snapshot: completed);
    };
    await fixture.vm.load();

    await fixture.vm.retranscribe();

    expect(fixture.runner.selectedProfiles, [same(_remote)]);
    expect(fixture.runner.retryIds, isEmpty);
    expect(fixture.vm.snapshot?.id, 'online-next');
    expect(fixture.vm.meeting.transcriptionProfile, same(_local));
    expect(fixture.transcripts.records[old.id], same(old));
  });

  test('在线最终稿使用自己的来源和分离配置，不查本地模型注册表', () async {
    final active = _snapshot('online-active', _remote);
    final fixture = _Fixture(active: active);
    addTearDown(fixture.vm.dispose);

    await fixture.vm.load();

    expect(fixture.vm.errorMessage, isNull);
    expect(fixture.vm.sourceModel.modelId, 'custom-online-model');
    expect(fixture.vm.sourceModel.installationType, AsrInstallationType.remote);
    expect(fixture.vm.sourceProfile, same(_remote));
    expect(fixture.vm.diarizationEnabled, isFalse);
    expect(fixture.vm.canChooseSource, isTrue);
  });

  test('原本本地会议的在线失败稿重试保留该稿 ID', () async {
    final old = _snapshot('old-local', _local);
    final fixture = _Fixture(active: old);
    addTearDown(fixture.vm.dispose);
    fixture.transcripts.records['online-failed'] = _snapshot(
      'online-failed',
      _remote,
      status: TranscriptSnapshotStatus.failed,
    );
    fixture.runner.onRetry = (id) async {
      final completed = _snapshot(id!, _remote);
      final meeting = fixture.meetings.value!
          .beginFinalTranscription()
          .activateFinalTranscript(completed);
      fixture.meetings.value = meeting;
      fixture.transcripts.records[id] = completed;
      return FinalTranscriptionResult(meeting: meeting, snapshot: completed);
    };
    await fixture.vm.load();

    await fixture.vm.retry();

    expect(fixture.runner.retryIds, ['online-failed']);
    expect(fixture.runner.selectedProfiles, isEmpty);
    expect(fixture.vm.snapshot?.id, 'online-failed');
    expect(fixture.vm.sourceModel.modelId, _remote.modelId);
    expect(fixture.vm.meeting.transcriptionProfile, same(_local));
    expect(fixture.transcripts.records[old.id], same(old));
  });

  test('用户明确换来源生成新稿，失败后旧稿和原录音锁定均保留', () async {
    final old = _snapshot('old-local', _local);
    final fixture = _Fixture(active: old);
    addTearDown(fixture.vm.dispose);
    fixture.runner.onSelection = (profile) async {
      fixture.transcripts.records['new-failed'] = _snapshot(
        'new-failed',
        profile,
        status: TranscriptSnapshotStatus.failed,
      );
      throw StateError('remote offline');
    };
    await fixture.vm.load();

    await fixture.vm.retranscribeWithProfile(_remote);

    expect(fixture.runner.selectedProfiles, [same(_remote)]);
    expect(fixture.runner.retryIds, isEmpty);
    expect(fixture.vm.snapshot, same(old));
    expect(fixture.vm.meeting.activeTranscriptSnapshotId, old.id);
    expect(fixture.vm.meeting.transcriptionProfile, same(_local));
    expect(fixture.vm.canRetry, isTrue);
    expect(fixture.vm.canChooseSource, isTrue);
    expect(fixture.vm.errorMessage, isNotNull);
  });

  test('恢复在线 processing 稿时按该稿 ID 恢复，保留原录音来源', () async {
    final fixture = _Fixture();
    addTearDown(fixture.vm.dispose);
    fixture.transcripts.records['online-processing'] = _snapshot(
      'online-processing',
      _remote,
      status: TranscriptSnapshotStatus.processing,
    );
    fixture.runner.onRetry = (id) async {
      final completed = _snapshot(id!, _remote);
      final meeting = fixture.meetings.value!.activateFinalTranscript(
        completed,
      );
      fixture.meetings.value = meeting;
      fixture.transcripts.records[id] = completed;
      return FinalTranscriptionResult(meeting: meeting, snapshot: completed);
    };

    await fixture.vm.load();

    expect(fixture.runner.retryIds, ['online-processing']);
    expect(fixture.vm.snapshot?.id, 'online-processing');
    expect(fixture.vm.meeting.transcriptionProfile, same(_local));
    expect(fixture.vm.sourceModel.modelId, _remote.modelId);
  });
}

final _local = TranscriptionProfile.local();
final _remote = TranscriptionProfile(
  id: 'remote-history',
  name: 'Online history',
  revision: 3,
  protocol: TranscriptionProtocol.audioTranscriptions,
  endpoint: Uri.parse('https://speech.example.test/transcribe'),
  modelId: 'custom-online-model',
  credentialRef: 'credential-version-3',
);

TranscriptSnapshot _snapshot(
  String id,
  TranscriptionProfile profile, {
  TranscriptSnapshotStatus status = TranscriptSnapshotStatus.complete,
  TranscriptTimingPrecision timingPrecision = TranscriptTimingPrecision.segment,
}) => TranscriptSnapshot(
  id: id,
  meetingId: 'meeting-1',
  kind: TranscriptSnapshotKind.finalTranscript,
  actualModelId: profile.modelId,
  actualModelVersion: profile.identityVersion,
  transcriptionProfile: profile,
  timingPrecision: timingPrecision,
  createdAt: DateTime.utc(2026, 9, 8),
  status: status,
  segments: status == TranscriptSnapshotStatus.complete
      ? [
          TranscriptSegment(
            id: '$id-segment',
            snapshotId: id,
            startMs: 0,
            endMs: 1000,
            text: '已确认的旧稿仍可查看',
            modelId: profile.modelId,
            modelVersion: profile.identityVersion,
          ),
        ]
      : [],
);

final class _Fixture {
  _Fixture({TranscriptSnapshot? active}) {
    final meeting = Meeting(
      id: 'meeting-1',
      title: '会议',
      createdAt: DateTime.utc(2026, 9, 8),
      startedAt: DateTime.utc(2026, 9, 8),
      endedAt: DateTime.utc(2026, 9, 8, 0, 0, 2),
      status: active == null ? MeetingState.processing : MeetingState.completed,
      audioPath: '/test-only/fact.pcm',
      audioDurationMs: 2000,
      recordingModelId: _local.modelId,
      recordingModelVersion: _local.identityVersion,
      transcriptionProfile: _local,
      activeTranscriptSnapshotId: active?.id,
    );
    meetings = DetailMeetingRepository(meeting);
    if (active != null) transcripts.records[active.id] = active;
    vm = MeetingDetailViewModel(
      meeting: meeting,
      meetings: meetings,
      transcripts: transcripts,
      transcription: runner,
      shareBuilderProvider: () => const BuildMeetingShareUseCase(),
      speakerLabelBuilder: (number) => '说话人 $number',
    );
  }
  late final DetailMeetingRepository meetings;
  final transcripts = DetailTranscriptRepository();
  final runner = _Runner();
  late final MeetingDetailViewModel vm;
}

final class _Runner implements ProfileFinalTranscriptionRunner {
  final retryIds = <String?>[];
  final selectedProfiles = <TranscriptionProfile>[];
  Future<FinalTranscriptionResult> Function(String?)? onRetry;
  Future<FinalTranscriptionResult> Function(TranscriptionProfile)? onSelection;
  @override
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  }) {
    retryIds.add(retrySnapshotId);
    return onRetry!(retrySnapshotId);
  }

  @override
  Future<FinalTranscriptionResult> transcribeWithProfile({
    required String meetingId,
    required TranscriptionProfile profile,
    FinalTranscriptionProgressCallback? onProgress,
  }) {
    selectedProfiles.add(profile);
    return onSelection!(profile);
  }
}
