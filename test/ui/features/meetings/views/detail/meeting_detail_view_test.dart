import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/domain/models/app_language.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/speaker_diarization.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/audio_playback.dart';
import 'package:meettrace/domain/ports/audio_share.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/ports/text_share.dart';
import 'package:meettrace/domain/use_cases/build_meeting_share.dart';
import 'package:meettrace/domain/use_cases/delete_meeting.dart';
import 'package:meettrace/domain/use_cases/run_final_transcription.dart';
import 'package:meettrace/domain/use_cases/run_speaker_diarization.dart';
import 'package:meettrace/domain/use_cases/share_meeting_audio.dart';
import 'package:meettrace/keys.dart';
import 'package:meettrace/theme/theme.dart';
import 'package:meettrace/ui/core/app_status_notice.dart';
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

    expect(find.byKey(keys.meetings.detailTitle), findsOneWidget);
    expect(find.byKey(keys.meetings.detailAudioDuration), findsOneWidget);
    expect(find.textContaining('最终事实文本'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('segment-text-old-segment')),
      findsNothing,
    );
    expect(find.text('重新生成结果'), findsNothing);
    expect(find.text('删除本场会议'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meeting-more-actions')));
    await tester.pumpAndSettle();
    expect(find.textContaining('本场锁定的 SenseVoice'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retranscribe-meeting')));
    await tester.pumpAndSettle();

    expect(fixture.runner.calls.single.modelId, senseVoiceDefaultModelId);
    expect(fixture.runner.calls.single.retrySnapshotId, isNull);
    expect(find.textContaining('SenseVoice 新最终文本'), findsOneWidget);
    expect(find.textContaining('SenseVoice'), findsWidgets);
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

    expect(find.textContaining('本机说话人模型不可用'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('speaker-diarization-switch')),
      findsNothing,
    );
    final unavailableReason = find.byKey(
      const ValueKey('diarization-unavailable-reason'),
    );
    expect(unavailableReason, findsNothing);
    final manage = find.byKey(const ValueKey('manage-speakers'));
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('speaker-management-sheet')),
      findsOneWidget,
    );
    expect(unavailableReason, findsOneWidget);
    expect(
      find.ancestor(of: unavailableReason, matching: find.byType(FSwitch)),
      findsNothing,
    );
    expect(find.text('说话人 1'), findsWidgets);
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('speaker-label-row-speaker-1')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('speaker-label-speaker-1'));
    await tester.enterText(field, '张三');
    final save = find.byKey(const ValueKey('save-speaker-label-speaker-1'));
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(diarization.renameCalls.single, ('speaker-1', '张三'));
    expect(find.text('张三'), findsWidgets);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('speaker-management-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
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
    expect(find.text('自动区分未完成，当前按单一说话人显示。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retry-speaker-diarization')),
      findsNothing,
    );

    final manage = find.byKey(const ValueKey('manage-speakers'));
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();

    expect(find.textContaining('最终转录不受影响'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retry-speaker-diarization')),
      findsOneWidget,
    );
    await fixture.dispose();
  });

  testWidgets('说话人标签保存失败时保留输入并允许重试', (tester) async {
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final diarization = _DiarizationRunner(
      result: SpeakerDiarizationResult(
        snapshot: active,
        status: SpeakerDiarizationStatus.disabled,
      ),
      available: false,
      renameError: StateError('rename failed'),
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

    final manage = find.byKey(const ValueKey('manage-speakers'));
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('speaker-label-row-speaker-1')));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('speaker-label-speaker-1'));
    await tester.enterText(field, '张三');
    await tester.tap(
      find.byKey(const ValueKey('save-speaker-label-speaker-1')),
    );
    await tester.pumpAndSettle();

    expect(field, findsOneWidget);
    expect(
      find.byKey(const ValueKey('speaker-label-save-error')),
      findsOneWidget,
    );
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, '张三');
    expect(diarization.renameCalls.single, ('speaker-1', '张三'));
    await fixture.dispose();
  });

  testWidgets('详情页直接播放完整事实音频区间', (tester) async {
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

    final playButton = find.byKey(const ValueKey('toggle-audio-playback'));
    await tester.ensureVisible(playButton);
    await tester.tap(playButton);
    await tester.pump(const Duration(milliseconds: 200));

    expect(playback.calls, [('/audio/fact.pcm', 0, 2000)]);
    await fixture.dispose();
  });

  testWidgets('分享文本先选择格式且不附带事实音频', (tester) async {
    final active = _snapshot(id: 'active');
    final textShare = _TextShare();
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      textShare: textShare,
    );
    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('request-share-text')), findsNothing);
    expect(find.byKey(const ValueKey('request-share-audio')), findsNothing);
    final requestShare = find.byKey(const ValueKey('request-share-meeting'));
    expect(tester.widget(requestShare), isA<FHeaderAction>());
    expect(tester.widget<FScaffold>(find.byType(FScaffold)).footer, isNull);
    await tester.tap(requestShare);
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('meeting-action-sheet-surface'));
    expect(surface, findsOneWidget);
    final decoration = tester.widget<DecoratedBox>(surface).decoration;
    expect(
      decoration,
      isA<BoxDecoration>()
          .having(
            (value) => value.color,
            'background color',
            tester.element(surface).theme.colors.card,
          )
          .having(
            (value) => value.borderRadius,
            'top corners',
            BorderRadius.only(
              topLeft: Radius.circular(
                tester.element(surface).theme.style.app.panelRadius,
              ),
              topRight: Radius.circular(
                tester.element(surface).theme.style.app.panelRadius,
              ),
            ),
          ),
    );
    expect(
      tester.getSize(surface).width,
      MediaQuery.sizeOf(tester.element(surface)).width,
    );
    expect(find.text('纯文本'), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.textContaining('事实音频需要单独确认'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('share-markdown')));
    await tester.pumpAndSettle();

    expect(textShare.documents, hasLength(1));
    expect(textShare.documents.single.text, contains('最终事实文本'));
    expect(textShare.documents.single.text, isNot(contains('/audio/fact.pcm')));
    await fixture.dispose();
  });

  testWidgets('低频操作收进更多面板且删除仍需危险确认', (tester) async {
    final active = _snapshot(id: 'active');
    var deleted = 0;
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
    );
    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(
          viewModel: fixture.viewModel,
          onBack: () {},
          onDeleted: () => deleted++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('重新生成转录'), findsNothing);
    expect(find.text('删除会议'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meeting-more-actions')));
    await tester.pumpAndSettle();

    expect(find.text('重新生成转录'), findsOneWidget);
    expect(find.text('删除会议'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('request-delete-meeting')));
    await tester.pumpAndSettle();

    expect(find.text('永久删除这场会议？'), findsOneWidget);
    expect(find.textContaining('事实录音、转录、说话人标签和处理记录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-delete-meeting')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-delete-meeting')));
    await tester.pumpAndSettle();

    expect(fixture.meetings.value, isNull);
    expect(deleted, 1);
    await fixture.dispose();
  });

  testWidgets('宽屏更多操作使用锚定浮层而不是底部面板', (tester) async {
    tester.view.physicalSize = const Size(1024, 760);
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

    expect(find.byType(FPopoverMenu), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-more-actions')));
    await tester.pumpAndSettle();

    expect(find.text('重新生成转录'), findsOneWidget);
    expect(find.text('删除会议'), findsOneWidget);
    expect(find.text('更多操作'), findsNothing);
    expect(tester.takeException(), isNull);
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

    final request = find.byKey(const ValueKey('request-share-meeting'));
    await tester.ensureVisible(request);
    await tester.tap(request);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-audio')));
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

    final request = find.byKey(const ValueKey('request-share-meeting'));
    await tester.ensureVisible(request);
    await tester.tap(request);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-audio')));
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

    final request = find.byKey(const ValueKey('request-share-meeting'));
    await tester.ensureVisible(request);
    await tester.tap(request);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-audio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-share-audio')));
    await tester.pumpAndSettle();

    expect(find.text('音频分享临时文件清理失败，请重启应用后重试'), findsOneWidget);
    expect(find.textContaining('临时文件已清理'), findsNothing);
    await fixture.dispose();
  });

  testWidgets('处理中只显示单一真实状态且允许返回', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fixture = _fixture(_meeting());
    final completion = Completer<FinalTranscriptionResult>();
    var backCalls = 0;
    fixture.runner.onCall = ({
      required meetingId,
      required modelId,
      required modelVersion,
      required retrySnapshotId,
      required onProgress,
    }) => completion.future;

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(
          viewModel: fixture.viewModel,
          onBack: () => backCalls++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('正在生成最终结果'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meeting-processing-ledger')),
      findsOneWidget,
    );
    expect(find.textContaining('SenseVoice 正在处理完整录音'), findsOneWidget);
    expect(find.text('说话人区分当前不可用；完成后将按单一说话人显示。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meeting-processing-audio-safety')),
      findsOneWidget,
    );
    expect(find.text('最终转录'), findsNothing);
    expect(find.text('说话人整理'), findsNothing);
    expect(find.byType(FProgress), findsOneWidget);
    expect(find.byType(AppStatusNotice), findsNothing);
    expect(find.text('AI 总结'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('返回会议列表'));
    await tester.pump();
    expect(backCalls, 1);

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
      find.byKey(const ValueKey('segment-speaker-active-segment')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('speaker-label-speaker-1')), findsNothing);
    expect(
      find.byKey(const ValueKey('save-transcript-revision')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cancel-transcript-revision')),
      findsOneWidget,
    );
    await fixture.dispose();
  });

  testWidgets('切换语言仅更新自动说话人标签并保留用户编辑', (tester) async {
    final language = ValueNotifier(AppLanguageMode.simplifiedChinese);
    addTearDown(language.dispose);
    final active = _snapshot(id: 'active', speakerId: 'speaker-1');
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
      ),
      active: active,
      speakerLabelBuilder: (number) => switch (language.value) {
        AppLanguageMode.english => 'Speaker $number',
        _ => '说话人 $number',
      },
    );

    await tester.pumpWidget(
      Application(
        languageMode: language,
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-transcript')));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('segment-speaker-active-segment'));
    expect(find.text('说话人 1'), findsWidgets);

    language.value = AppLanguageMode.english;
    await tester.pumpAndSettle();
    expect(find.text('Speaker 1'), findsWidgets);

    await tester.enterText(field, 'Alice');
    language.value = AppLanguageMode.simplifiedChinese;
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    await fixture.dispose();
  });

  testWidgets('长会议时长和时间戳使用小时格式', (tester) async {
    final active = _snapshot(id: 'active', startMs: 3723000);
    final fixture = _fixture(
      _meeting(
        status: MeetingState.completed,
        activeTranscriptSnapshotId: active.id,
        audioDurationMs: 3723000,
      ),
      active: active,
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1:02:03'), findsWidgets);
    expect(
      find.byKey(const ValueKey('transcript-time-active-segment')),
      findsOneWidget,
    );
    await fixture.dispose();
  });

  testWidgets('320 宽度和 2.0 字体缩放下连续结果视图不溢出', (tester) async {
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
      textShare: _TextShare(),
    );

    await tester.pumpWidget(
      Application(
        home: MeetingDetailView(viewModel: fixture.viewModel, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最终转录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meeting-audio-evidence-strip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meeting-detail-continuous-ledger')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('meeting-result-tabs')), findsNothing);
    final timestamp = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('transcript-time-active-segment')),
    );
    expect(timestamp.didExceedMaxLines, isFalse);
    expect(find.text('总结'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('request-share-meeting')));
    await tester.pumpAndSettle();
    expect(find.text('分享会议'), findsWidgets);
    expect(find.byKey(const ValueKey('share-plain-text')), findsOneWidget);
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
      expect(
        find.byKey(const ValueKey('meeting-detail-continuous-ledger')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('meeting-result-tabs')), findsNothing);
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
  TextShareService? textShare,
  String Function(int number)? speakerLabelBuilder,
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
      sharing: textShare,
      audioSharing: audioShare == null
          ? null
          : ShareMeetingAudioUseCase(audioShare),
      deletion: DeleteMeetingUseCase(
        meetings: meetings,
        files: const _MeetingFileDeletionService(),
      ),
      shareBuilderProvider: () => const BuildMeetingShareUseCase(),
      speakerLabelBuilder: speakerLabelBuilder ?? (number) => '说话人 $number',
    ),
  );
}

final class _MeetingFileDeletionService implements MeetingFileDeletionService {
  const _MeetingFileDeletionService();

  @override
  Future<StagedMeetingDeletion> stage(String meetingId) async =>
      const _StagedMeetingDeletion();
}

final class _StagedMeetingDeletion implements StagedMeetingDeletion {
  const _StagedMeetingDeletion();

  @override
  Future<void> commit() async {}

  @override
  Future<void> rollback() async {}
}

final class _TextShare implements TextShareService {
  final List<MeetingShareDocument> documents = [];

  @override
  Future<void> share(MeetingShareDocument document) async {
    documents.add(document);
  }
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
  int audioDurationMs = 2000,
}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
    createdAt: DateTime.utc(2026, 7, 25),
    startedAt: DateTime.utc(2026, 7, 25, 1),
    endedAt: DateTime.utc(2026, 7, 25, 1, 0, 2),
    status: status,
    audioPath: '/audio/fact.pcm',
    audioDurationMs: audioDurationMs,
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
  int startMs = 0,
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
              startMs: startMs,
              endMs: startMs + 1000,
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
  _DiarizationRunner({
    required this.result,
    this.available = true,
    this.renameError,
  });

  SpeakerDiarizationResult result;
  final bool available;
  final Object? renameError;
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
    if (renameError case final error?) {
      throw error;
    }
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
