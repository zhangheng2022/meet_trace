part of '../meeting_detail_view.dart';

final class _TranscriptCard extends StatefulWidget {
  const _TranscriptCard({
    required this.snapshot,
    required this.viewModel,
    required this.editing,
    required this.onEditingChanged,
    super.key,
  });

  final TranscriptSnapshot snapshot;
  final MeetingDetailViewModel viewModel;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;

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
  late final Map<String, GlobalKey> _evidenceKeys = {
    for (final segment in widget.snapshot.segments) segment.id: GlobalKey(),
  };
  String? _lastLocatedEvidenceId;

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
    _scheduleEvidenceLocation();
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('最终转录', style: theme.typography.display.md),
                ),
                if (widget.snapshot.segments.isNotEmpty)
                  FButton(
                    key: ValueKey(
                      widget.editing
                          ? 'cancel-transcript-edit'
                          : 'edit-transcript',
                    ),
                    variant: FButtonVariant.ghost,
                    mainAxisSize: MainAxisSize.min,
                    onPress: widget.viewModel.isProcessing
                        ? null
                        : () => widget.onEditingChanged(!widget.editing),
                    child: Text(widget.editing ? '取消编辑' : '编辑转录'),
                  ),
              ],
            ),
            SizedBox(height: appStyle.spaceSm),
            Text(
              widget.editing
                  ? '保存后会生成新的最终转录版本，已有 AI 总结将标记为过期。'
                  : '以下内容来自完整事实录音；点击“编辑转录”后才会进入修改状态。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            SizedBox(height: appStyle.spaceMd),
            if (widget.snapshot.segments.isEmpty)
              const Text('未识别到可显示的语音内容。')
            else
              for (final segment in widget.snapshot.segments) ...[
                if (widget.viewModel.selectedEvidenceSegmentId == segment.id)
                  Align(
                    key: _evidenceKeys[segment.id],
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
                if (widget.editing) ...[
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
                ] else
                  Text(segment.text, style: theme.typography.body.lg),
                SizedBox(height: appStyle.spaceMd),
              ],
            if (widget.snapshot.segments.isNotEmpty && widget.editing)
              FButton(
                key: const ValueKey('save-transcript-revision'),
                onPress: widget.viewModel.isProcessing
                    ? null
                    : () async {
                        await widget.viewModel.reviseTranscript([
                          for (final segment in widget.snapshot.segments)
                            TranscriptSegmentRevision(
                              segmentId: segment.id,
                              text: _texts[segment.id]!.text,
                              speakerLabel: _speakers[segment.id]!.text,
                            ),
                        ]);
                        if (mounted) {
                          widget.onEditingChanged(false);
                        }
                      },
                child: const Text('保存转录修订'),
              ),
          ],
        ),
      ),
    );
  }

  void _scheduleEvidenceLocation() {
    final selected = widget.viewModel.selectedEvidenceSegmentId;
    if (selected == null || selected == _lastLocatedEvidenceId) {
      return;
    }
    _lastLocatedEvidenceId = selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _evidenceKeys[selected]?.currentContext;
      if (targetContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            targetContext,
            duration: Duration.zero,
            alignment: 0.18,
          ),
        );
      }
    });
  }
}

final class _DiarizationCard extends StatelessWidget {
  const _DiarizationCard({required this.viewModel, required this.editing});

  final MeetingDetailViewModel viewModel;
  final bool editing;

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
            if (viewModel.speakerGroups.isNotEmpty && !editing) ...[
              SizedBox(height: appStyle.spaceMd),
              Text('当前标签', style: theme.typography.display.sm),
              SizedBox(height: appStyle.spaceSm),
              for (final group in viewModel.speakerGroups)
                Padding(
                  padding: EdgeInsets.only(bottom: appStyle.spaceSm),
                  child: Text(
                    '${group.displayLabel} · ${group.segmentCount} 个片段',
                    style: theme.typography.body.md,
                  ),
                ),
            ],
            if (viewModel.speakerGroups.isNotEmpty && editing) ...[
              SizedBox(height: appStyle.spaceMd),
              Text('人工标签', style: theme.typography.display.sm),
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
