part of '../meeting_detail_view.dart';

final class _TranscriptSection extends StatefulWidget {
  const _TranscriptSection({
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
  State<_TranscriptSection> createState() => _TranscriptSectionState();
}

final class _TranscriptSectionState extends State<_TranscriptSection> {
  late Map<String, TextEditingController> _texts;
  late Map<String, TextEditingController> _speakers;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  @override
  void didUpdateWidget(covariant _TranscriptSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.id != widget.snapshot.id) {
      _disposeControllers();
      _createControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _createControllers() {
    _texts = {
      for (final segment in widget.snapshot.segments)
        segment.id: TextEditingController(text: segment.text),
    };
    _speakers = {
      for (final segment in widget.snapshot.segments)
        segment.id: TextEditingController(
          text: displaySpeakerLabel(segment.speakerId),
        ),
    };
  }

  void _disposeControllers() {
    for (final controller in [..._texts.values, ..._speakers.values]) {
      controller.dispose();
    }
  }

  Future<void> saveRevision() async {
    if (widget.viewModel.isProcessing) {
      return;
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      key: const ValueKey('meeting-detail-continuous-ledger'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('最终转录', style: theme.typography.display.lg)),
            if (widget.snapshot.segments.isNotEmpty)
              FButton(
                key: ValueKey(
                  widget.editing ? 'cancel-transcript-edit' : 'edit-transcript',
                ),
                variant: FButtonVariant.ghost,
                mainAxisSize: MainAxisSize.min,
                onPress: widget.viewModel.isProcessing
                    ? null
                    : () => widget.onEditingChanged(!widget.editing),
                child: Text(widget.editing ? '取消' : '编辑'),
              ),
          ],
        ),
        if (widget.editing) ...[
          SizedBox(height: appStyle.spaceSm),
          Text(
            '保存后会生成新的最终转录版本，事实音频和时间轴保持不变。',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
        SizedBox(height: appStyle.spaceSm),
        if (widget.snapshot.segments.isEmpty)
          const Text('未识别到可显示的语音内容。')
        else if (widget.editing)
          for (final segment in widget.snapshot.segments) ...[
            Text(
              '${displaySpeakerLabel(segment.speakerId)} · '
              '${_timestamp(segment.startMs)}',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            SizedBox(height: appStyle.spaceXs),
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
          ]
        else
          for (var index = 0; index < widget.snapshot.segments.length; index++)
            _TranscriptLedgerRow(
              segment: widget.snapshot.segments[index],
              first: index == 0,
              last: index == widget.snapshot.segments.length - 1,
            ),
      ],
    );
  }
}

final class _TranscriptLedgerRow extends StatelessWidget {
  const _TranscriptLedgerRow({
    required this.segment,
    required this.first,
    required this.last,
  });

  final TranscriptSegment segment;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final timeWidth = largeText
        ? appStyle.ledgerTimeColumnWidth + appStyle.space2Xl
        : appStyle.ledgerTimeColumnWidth;
    return Stack(
      children: [
        Positioned(
          left: timeWidth,
          top: 0,
          bottom: 0,
          width: appStyle.spaceLg,
          child: CustomPaint(
            painter: _TranscriptTimelinePainter(
              first: first,
              last: last,
              lineColor: theme.colors.border,
              dotColor: theme.colors.mutedForeground,
              lineWidth: appStyle.dividerWidth,
              dotRadius: appStyle.spaceXs / 2,
              dotCenterY: appStyle.spaceMd,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: timeWidth,
              child: Padding(
                padding: EdgeInsets.only(top: appStyle.spaceXs),
                child: Text(
                  _timestamp(segment.startMs),
                  key: ValueKey('transcript-time-${segment.id}'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            SizedBox(width: appStyle.spaceLg),
            SizedBox(width: appStyle.spaceXs),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: appStyle.spaceXs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displaySpeakerLabel(segment.speakerId),
                      style: theme.typography.body.sm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: appStyle.space2Xs),
                    Text(
                      segment.text,
                      style: theme.typography.body.md.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _TranscriptTimelinePainter extends CustomPainter {
  const _TranscriptTimelinePainter({
    required this.first,
    required this.last,
    required this.lineColor,
    required this.dotColor,
    required this.lineWidth,
    required this.dotRadius,
    required this.dotCenterY,
  });

  final bool first;
  final bool last;
  final Color lineColor;
  final Color dotColor;
  final double lineWidth;
  final double dotRadius;
  final double dotCenterY;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = dotCenterY.clamp(dotRadius, size.height - dotRadius);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;
    if (!first) {
      canvas.drawLine(Offset(centerX, 0), Offset(centerX, centerY), linePaint);
    }
    if (!last) {
      canvas.drawLine(
        Offset(centerX, centerY),
        Offset(centerX, size.height),
        linePaint,
      );
    }
    canvas.drawCircle(
      Offset(centerX, centerY),
      dotRadius,
      Paint()..color = dotColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TranscriptTimelinePainter oldDelegate) =>
      first != oldDelegate.first ||
      last != oldDelegate.last ||
      lineColor != oldDelegate.lineColor ||
      dotColor != oldDelegate.dotColor ||
      lineWidth != oldDelegate.lineWidth ||
      dotRadius != oldDelegate.dotRadius ||
      dotCenterY != oldDelegate.dotCenterY;
}

final class _DiarizationSection extends StatelessWidget {
  const _DiarizationSection({required this.viewModel, required this.editing});

  final MeetingDetailViewModel viewModel;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: appStyle.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('说话人设置', style: theme.typography.display.lg),
            SizedBox(height: appStyle.spaceMd),
            FSwitch(
              key: const ValueKey('speaker-diarization-switch'),
              value: viewModel.diarizationEnabled,
              enabled:
                  viewModel.diarizationAvailable && !viewModel.isProcessing,
              onChange: (enabled) =>
                  unawaited(viewModel.setDiarizationEnabled(enabled)),
              label: const Text('自动说话人分离'),
              description: viewModel.diarizationAvailable
                  ? const Text('可随时关闭；失败时自动按单一说话人显示。')
                  : null,
            ),
            if (!viewModel.diarizationAvailable) ...[
              SizedBox(height: appStyle.spaceSm),
              Text(
                '当前构建未配置已验证的本地说话人模型，可继续手工标注。',
                key: const ValueKey('diarization-unavailable-reason'),
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
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
