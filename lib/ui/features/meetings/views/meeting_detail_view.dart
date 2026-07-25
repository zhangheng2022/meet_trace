import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../data/services/audio/pcm_evidence_playback_service.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/speaker_diarization.dart';
import '../../../../domain/models/summary.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../domain/use_cases/revise_final_transcript.dart';
import '../../../../theme/theme.dart';
import '../view_models/meeting_detail_view_model.dart';

final class MeetingDetailView extends StatefulWidget {
  const MeetingDetailView({
    required this.viewModel,
    required this.onBack,
    this.onDeleted,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final VoidCallback onBack;
  final VoidCallback? onDeleted;

  @override
  State<MeetingDetailView> createState() => _MeetingDetailViewState();
}

final class _MeetingDetailViewState extends State<MeetingDetailView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        return FScaffold(
          header: FHeader.nested(
            title: const Text('会议详情'),
            prefixes: [
              FHeaderAction(
                icon: context.theme.icons.arrowLeft(
                  context,
                  semanticsLabel: '返回会议列表',
                ),
                onPress: viewModel.isProcessing ? null : widget.onBack,
              ),
            ],
          ),
          child: _body(context, viewModel),
        );
      },
    );
  }

  Widget _body(BuildContext context, MeetingDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: FProgress(semanticsLabel: '加载最终转录'));
    }
    final theme = context.theme;
    final appStyle = theme.style.app;
    return SingleChildScrollView(
      padding: EdgeInsets.all(appStyle.spaceMd),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(viewModel.meeting.title, style: theme.typography.display.lg),
              SizedBox(height: appStyle.spaceSm),
              Text(
                '来源模型：${viewModel.sourceModel.displayName}',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              SizedBox(height: appStyle.spaceMd),
              if (viewModel.isTranscribing)
                _ProcessingCard(viewModel: viewModel),
              if (viewModel.errorMessage case final message?)
                _FailureCard(message: message, viewModel: viewModel),
              if (viewModel.snapshot case final snapshot?)
                _TranscriptCard(
                  key: ValueKey('transcript-${snapshot.id}'),
                  snapshot: snapshot,
                  viewModel: viewModel,
                ),
              if (viewModel.snapshot != null) ...[
                SizedBox(height: appStyle.spaceMd),
                _DiarizationCard(viewModel: viewModel),
                SizedBox(height: appStyle.spaceMd),
                _SummaryCard(viewModel: viewModel),
                SizedBox(height: appStyle.spaceMd),
                _AudioCard(viewModel: viewModel),
                SizedBox(height: appStyle.spaceMd),
                _ResultActionsCard(
                  viewModel: viewModel,
                  onDeleted: widget.onDeleted,
                ),
              ],
              if (viewModel.canRetranscribe) ...[
                SizedBox(height: appStyle.spaceMd),
                _RetranscriptionCard(viewModel: viewModel),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final percent = (viewModel.progress * 100).round();
    return FAlert(
      title: const Text('完整音频转录中'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('正在使用本场锁定模型重新读取事实音频，不会拼接会中临时文本。'),
          SizedBox(height: appStyle.spaceMd),
          FProgress(semanticsLabel: '最终转录进度 $percent%'),
          SizedBox(height: appStyle.spaceSm),
          Text('$percent%'),
        ],
      ),
    );
  }
}

final class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message, required this.viewModel});

  final String message;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return FAlert(
      variant: FAlertVariant.destructive,
      title: const Text('最终转录未完成'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message),
          if (viewModel.canRetry) ...[
            SizedBox(height: appStyle.spaceMd),
            FButton(
              onPress: () => unawaited(viewModel.retry()),
              child: const Text('重试最终转录'),
            ),
          ],
        ],
      ),
    );
  }
}

final class _TranscriptCard extends StatefulWidget {
  const _TranscriptCard({
    required this.snapshot,
    required this.viewModel,
    super.key,
  });

  final TranscriptSnapshot snapshot;
  final MeetingDetailViewModel viewModel;

  @override
  State<_TranscriptCard> createState() => _TranscriptCardState();
}

final class _TranscriptCardState extends State<_TranscriptCard> {
  late final Map<String, TextEditingController> _texts = {
    for (final segment in widget.snapshot.segments)
      segment.id: TextEditingController(text: segment.text),
  };
  late final Map<String, TextEditingController> _speakers = {
    for (final segment in widget.snapshot.segments)
      segment.id: TextEditingController(
        text: displaySpeakerLabel(segment.speakerId),
      ),
  };

  @override
  void dispose() {
    for (final controller in [..._texts.values, ..._speakers.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('最终转录', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceMd),
            if (widget.snapshot.segments.isEmpty)
              const Text('未识别到可显示的语音内容。')
            else
              for (final segment in widget.snapshot.segments) ...[
                if (widget.viewModel.selectedEvidenceSegmentId == segment.id)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FBadge(child: const Text('证据定位')),
                  ),
                Text(
                  '${displaySpeakerLabel(segment.speakerId)} · '
                  '${_timestamp(segment.startMs)}',
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                SizedBox(height: appStyle.spaceSm),
                FTextField(
                  key: ValueKey('segment-speaker-${segment.id}'),
                  control: FTextFieldControl.managed(
                    controller: _speakers[segment.id]!,
                  ),
                  label: const Text('说话人'),
                ),
                SizedBox(height: appStyle.spaceSm),
                FTextField(
                  key: ValueKey('segment-text-${segment.id}'),
                  control: FTextFieldControl.managed(
                    controller: _texts[segment.id]!,
                  ),
                  label: const Text('转录内容'),
                  maxLines: 4,
                ),
                SizedBox(height: appStyle.spaceMd),
              ],
            if (widget.snapshot.segments.isNotEmpty)
              FButton(
                key: const ValueKey('save-transcript-revision'),
                onPress: widget.viewModel.isProcessing
                    ? null
                    : () => unawaited(
                        widget.viewModel.reviseTranscript([
                          for (final segment in widget.snapshot.segments)
                            TranscriptSegmentRevision(
                              segmentId: segment.id,
                              text: _texts[segment.id]!.text,
                              speakerLabel: _speakers[segment.id]!.text,
                            ),
                        ]),
                      ),
                child: const Text('保存转录修订'),
              ),
          ],
        ),
      ),
    );
  }
}

final class _DiarizationCard extends StatelessWidget {
  const _DiarizationCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('说话人', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceMd),
            FSwitch(
              key: const ValueKey('speaker-diarization-switch'),
              value: viewModel.diarizationEnabled,
              enabled:
                  viewModel.diarizationAvailable && !viewModel.isProcessing,
              onChange: (enabled) =>
                  unawaited(viewModel.setDiarizationEnabled(enabled)),
              label: const Text('自动说话人分离'),
              description: Text(
                viewModel.diarizationAvailable
                    ? '可随时关闭；失败时自动按单一说话人显示。'
                    : '当前构建未配置已验证的本地说话人模型，可继续手工标注。',
              ),
            ),
            if (viewModel.isDiarizing) ...[
              SizedBox(height: appStyle.spaceMd),
              const FProgress(semanticsLabel: '说话人分离处理中'),
            ],
            if (viewModel.diarizationMessage case final message?) ...[
              SizedBox(height: appStyle.spaceMd),
              FAlert(
                variant:
                    viewModel.diarizationStatus ==
                        SpeakerDiarizationStatus.degraded
                    ? FAlertVariant.destructive
                    : FAlertVariant.primary,
                title: Text(
                  viewModel.diarizationStatus ==
                          SpeakerDiarizationStatus.degraded
                      ? '说话人分离已降级'
                      : '说话人标签',
                ),
                subtitle: Text(message),
              ),
            ],
            if (viewModel.diarizationStatus ==
                    SpeakerDiarizationStatus.degraded &&
                viewModel.canRetryDiarization) ...[
              SizedBox(height: appStyle.spaceMd),
              FButton(
                onPress: () => unawaited(viewModel.retryDiarization()),
                child: const Text('重试说话人分离'),
              ),
            ],
            if (viewModel.speakerGroups.isNotEmpty) ...[
              SizedBox(height: appStyle.spaceMd),
              const Text('人工标签'),
              SizedBox(height: appStyle.spaceSm),
              for (final group in viewModel.speakerGroups)
                Padding(
                  padding: EdgeInsets.only(bottom: appStyle.spaceMd),
                  child: _SpeakerLabelEditor(
                    key: ValueKey('speaker-editor-${group.speakerId}'),
                    group: group,
                    viewModel: viewModel,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _SpeakerLabelEditor extends StatefulWidget {
  const _SpeakerLabelEditor({
    required this.group,
    required this.viewModel,
    super.key,
  });

  final SpeakerLabelGroup group;
  final MeetingDetailViewModel viewModel;

  @override
  State<_SpeakerLabelEditor> createState() => _SpeakerLabelEditorState();
}

final class _SpeakerLabelEditorState extends State<_SpeakerLabelEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.group.displayLabel,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final keyId = widget.group.speakerId ?? 'unlabeled';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FTextField(
          key: ValueKey('speaker-label-$keyId'),
          control: FTextFieldControl.managed(controller: _controller),
          label: Text('${widget.group.segmentCount} 个片段'),
          hint: '输入说话人名称',
        ),
        SizedBox(height: appStyle.spaceSm),
        FButton(
          key: ValueKey('save-speaker-label-$keyId'),
          onPress: widget.viewModel.isProcessing
              ? null
              : () => unawaited(
                  widget.viewModel.renameSpeaker(
                    widget.group.speakerId,
                    _controller.text,
                  ),
                ),
          child: const Text('保存标签'),
        ),
      ],
    );
  }
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final summary = viewModel.summary;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI 总结', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceSm),
            Text(
              '只基于当前最终转录生成；不会上传音频或会中临时文本。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            if (!viewModel.summaryAvailable) ...[
              SizedBox(height: appStyle.spaceMd),
              const FAlert(
                title: Text('安全总结网关未配置'),
                subtitle: Text('当前构建已关闭云端总结，最终转录仍保留在本机且可正常查看。'),
              ),
            ],
            if (viewModel.isGeneratingSummary ||
                summary?.status == SummaryStatus.processing) ...[
              SizedBox(height: appStyle.spaceMd),
              const FProgress(semanticsLabel: 'AI 总结生成中'),
            ],
            if (viewModel.summaryMessage case final message?) ...[
              SizedBox(height: appStyle.spaceMd),
              FAlert(
                variant: summary?.status == SummaryStatus.failed
                    ? FAlertVariant.destructive
                    : FAlertVariant.primary,
                title: Text(
                  summary?.status == SummaryStatus.failed
                      ? 'AI 总结生成失败'
                      : 'AI 总结状态',
                ),
                subtitle: Text(message),
              ),
            ],
            if (summary?.status == SummaryStatus.stale) ...[
              SizedBox(height: appStyle.spaceMd),
              const FAlert(
                variant: FAlertVariant.destructive,
                title: Text('AI 总结已过期'),
                subtitle: Text('最终转录版本已变化，请基于当前版本重新生成总结。'),
              ),
            ],
            if (summary?.status == SummaryStatus.complete) ...[
              SizedBox(height: appStyle.spaceMd),
              Text('概览', style: theme.typography.display.sm),
              SizedBox(height: appStyle.spaceSm),
              Text(summary!.overview, style: theme.typography.body.md),
              if (summary.keyPoints.isNotEmpty)
                _SummarySection(
                  title: '关键结论',
                  items: summary.keyPoints,
                  viewModel: viewModel,
                ),
              if (summary.actionItems.isNotEmpty)
                _SummarySection(
                  title: '行动项',
                  items: summary.actionItems,
                  viewModel: viewModel,
                ),
            ],
            if (viewModel.canGenerateSummary) ...[
              SizedBox(height: appStyle.spaceMd),
              FButton(
                key: const ValueKey('generate-summary'),
                onPress: () => unawaited(viewModel.generateSummary()),
                child: Text(
                  summary == null
                      ? '生成 AI 总结'
                      : summary.status == SummaryStatus.failed
                      ? '重试 AI 总结'
                      : '重新生成 AI 总结',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.items,
    required this.viewModel,
  });

  final String title;
  final List<SummaryItem> items;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Padding(
      padding: EdgeInsets.only(top: appStyle.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.typography.display.sm),
          SizedBox(height: appStyle.spaceSm),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(bottom: appStyle.spaceMd),
              child: _SummaryItemView(item: item, viewModel: viewModel),
            ),
        ],
      ),
    );
  }
}

final class _SummaryItemView extends StatelessWidget {
  const _SummaryItemView({required this.item, required this.viewModel});

  final SummaryItem item;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('• ${item.text}', style: theme.typography.body.md),
        if (item.isPendingReview) ...[
          SizedBox(height: appStyle.spaceSm),
          Text(
            '待核对：未找到有效原文证据',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ] else
          for (final evidence in item.evidence) ...[
            SizedBox(height: appStyle.spaceSm),
            GestureDetector(
              key: ValueKey(
                'play-evidence-${evidence.segmentId}-${evidence.startMs}',
              ),
              onTap: () => unawaited(viewModel.playEvidence(evidence)),
              child: Text(
                '证据 ${_timestamp(evidence.startMs)}–'
                '${_timestamp(evidence.endMs)}：${evidence.quote}',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.primary,
                ),
              ),
            ),
          ],
      ],
    );
  }
}

final class _AudioCard extends StatelessWidget {
  const _AudioCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final playing =
        viewModel.playbackState.status == EvidencePlaybackStatus.playing;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('本地录音', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceSm),
            Text(
              '时长 ${_duration(viewModel.meeting.audioDurationMs)}；音频路径不会显示或分享。',
            ),
            SizedBox(height: appStyle.spaceMd),
            FButton(
              key: const ValueKey('toggle-audio-playback'),
              onPress: viewModel.meeting.audioPath == null
                  ? null
                  : () => unawaited(
                      playing
                          ? viewModel.stopPlayback()
                          : viewModel.playFullAudio(),
                    ),
              child: Text(playing ? '停止播放' : '播放完整录音'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ResultActionsCard extends StatefulWidget {
  const _ResultActionsCard({required this.viewModel, required this.onDeleted});

  final MeetingDetailViewModel viewModel;
  final VoidCallback? onDeleted;

  @override
  State<_ResultActionsCard> createState() => _ResultActionsCardState();
}

final class _ResultActionsCardState extends State<_ResultActionsCard> {
  late final TextEditingController _title = TextEditingController(
    text: widget.viewModel.meeting.title,
  );
  bool _confirmingDelete = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final viewModel = widget.viewModel;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('结果与数据', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceMd),
            FTextField(
              key: const ValueKey('meeting-title'),
              control: FTextFieldControl.managed(controller: _title),
              label: const Text('会议名称'),
            ),
            SizedBox(height: appStyle.spaceSm),
            FButton(
              onPress: viewModel.isProcessing
                  ? null
                  : () => unawaited(viewModel.renameMeeting(_title.text)),
              child: const Text('保存会议名称'),
            ),
            SizedBox(height: appStyle.spaceMd),
            FButton(
              key: const ValueKey('share-plain-text'),
              onPress: viewModel.canShare && !viewModel.isProcessing
                  ? () =>
                        unawaited(viewModel.share(MeetingShareFormat.plainText))
                  : null,
              child: const Text('分享纯文本'),
            ),
            SizedBox(height: appStyle.spaceSm),
            FButton(
              key: const ValueKey('share-markdown'),
              onPress: viewModel.canShare && !viewModel.isProcessing
                  ? () =>
                        unawaited(viewModel.share(MeetingShareFormat.markdown))
                  : null,
              child: const Text('分享 Markdown'),
            ),
            if (viewModel.resultMessage case final message?) ...[
              SizedBox(height: appStyle.spaceMd),
              FAlert(title: Text(message)),
            ],
            SizedBox(height: appStyle.spaceMd),
            if (!_confirmingDelete)
              FButton(
                key: const ValueKey('request-delete-meeting'),
                onPress: viewModel.isProcessing
                    ? null
                    : () => setState(() => _confirmingDelete = true),
                child: const Text('删除本场会议'),
              )
            else
              FAlert(
                variant: FAlertVariant.destructive,
                title: const Text('确认永久删除？'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('将删除本场录音、转录、总结和处理记录，无法撤销。'),
                    SizedBox(height: appStyle.spaceMd),
                    FButton(
                      key: const ValueKey('confirm-delete-meeting'),
                      onPress: () async {
                        await viewModel.deleteMeeting();
                        if (viewModel.isDeleted) {
                          widget.onDeleted?.call();
                        }
                      },
                      child: const Text('确认删除全部数据'),
                    ),
                    SizedBox(height: appStyle.spaceSm),
                    FButton(
                      onPress: () => setState(() => _confirmingDelete = false),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _RetranscriptionCard extends StatelessWidget {
  const _RetranscriptionCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('重新转录会生成独立快照；成功后才替换当前结果。'),
            SizedBox(height: appStyle.spaceMd),
            for (final model in viewModel.installedModels)
              Padding(
                padding: EdgeInsets.only(bottom: appStyle.spaceSm),
                child: FRadio(
                  key: ValueKey('retranscribe-model-${model.modelId}'),
                  value: model.modelId == viewModel.selectedModelId,
                  onChange: (_) => viewModel.selectModel(model.modelId),
                  label: Text(model.displayName),
                  description: Text(_modelPositioning(model)),
                ),
              ),
            SizedBox(height: appStyle.spaceSm),
            FButton(
              onPress: () => unawaited(viewModel.retranscribe()),
              child: const Text('使用所选模型重新转录'),
            ),
          ],
        ),
      ),
    );
  }
}

String _modelPositioning(AsrModelDescriptor model) =>
    model.tier == AsrModelTier.advanced ? '准确率优先，资源占用更高' : '速度与资源占用优先';

String _timestamp(int milliseconds) {
  final value = Duration(milliseconds: milliseconds);
  final minutes = value.inMinutes.toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _duration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
