import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/speaker_diarization.dart';
import '../../../../../../domain/models/transcript.dart';
import '../../../../../../domain/use_cases/revise_final_transcript.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_sheet.dart';
import '../../../../../core/app_text_field.dart';
import '../../../view_models/detail/meeting_detail_view_model.dart';
import '../../../view_models/detail/meeting_speaker_labels.dart';
import '../widgets/meeting_detail_formatters.dart';

final class TranscriptSection extends StatefulWidget {
  const TranscriptSection({
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
  State<TranscriptSection> createState() => TranscriptSectionState();
}

final class TranscriptSectionState extends State<TranscriptSection> {
  late Map<String, TextEditingController> _texts;
  late Map<String, TextEditingController> _speakers;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  @override
  void didUpdateWidget(covariant TranscriptSection oldWidget) {
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
              '${meetingTimestampLabel(segment.startMs)}',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            SizedBox(height: appStyle.spaceXs),
            AppTextField(
              key: ValueKey('segment-speaker-${segment.id}'),
              controller: _speakers[segment.id]!,
              label: '说话人',
            ),
            SizedBox(height: appStyle.spaceSm),
            AppTextField(
              key: ValueKey('segment-text-${segment.id}'),
              controller: _texts[segment.id]!,
              label: '转录内容',
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
                  meetingTimestampLabel(segment.startMs),
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

final class DiarizationSection extends StatelessWidget {
  const DiarizationSection({
    required this.viewModel,
    required this.editing,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final groups = viewModel.speakerGroups;
    final segmentCount = groups.fold<int>(
      0,
      (total, group) => total + group.segmentCount,
    );
    final status = _speakerOverviewStatus(viewModel, groups.length);
    return DecoratedBox(
      key: const ValueKey('speaker-overview-section'),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: appStyle.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '说话人',
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: appStyle.space2Xs),
                      Text(
                        groups.isEmpty
                            ? '暂无说话人片段'
                            : '${groups.length} 位说话人 · $segmentCount 个片段',
                        key: const ValueKey('speaker-overview-count'),
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                      if (status != null) ...[
                        SizedBox(height: appStyle.space2Xs),
                        Text(
                          status,
                          key: const ValueKey('speaker-overview-status'),
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: appStyle.spaceSm),
                FButton(
                  key: const ValueKey('manage-speakers'),
                  variant: FButtonVariant.ghost,
                  mainAxisSize: MainAxisSize.min,
                  suffix: const Icon(FLucideIcons.chevronRight, size: 16),
                  onPress: editing || viewModel.isProcessing
                      ? null
                      : () => unawaited(_showSpeakerManagement(context)),
                  child: const Text('管理'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSpeakerManagement(BuildContext context) => showFSheet<void>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    mainAxisMaxRatio: 0.84,
    barrierLabel: '关闭说话人管理面板',
    builder: (context) => _SpeakerManagementSheet(viewModel: viewModel),
  );
}

String? _speakerOverviewStatus(
  MeetingDetailViewModel viewModel,
  int speakerCount,
) {
  if (viewModel.isDiarizing) {
    return '正在重新区分说话人，最终转录仍可查看。';
  }
  if (!viewModel.diarizationAvailable) {
    return speakerCount == 0 ? '本机说话人模型不可用。' : '本机说话人模型不可用，可手工修改标签。';
  }
  if (!viewModel.diarizationEnabled) {
    return '自动区分已关闭，现有标签保持不变。';
  }
  if (viewModel.diarizationStatus == SpeakerDiarizationStatus.degraded) {
    return speakerCount == 1 ? '自动区分未完成，当前按单一说话人显示。' : '自动区分未完成，当前标签仍可查看和修改。';
  }
  return null;
}

final class _SpeakerManagementSheet extends StatefulWidget {
  const _SpeakerManagementSheet({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  State<_SpeakerManagementSheet> createState() =>
      _SpeakerManagementSheetState();
}

final class _SpeakerManagementSheetState
    extends State<_SpeakerManagementSheet> {
  TextEditingController? _controller;
  String? _editingSpeakerId;
  bool _editing = false;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final appStyle = context.theme.style.app;
        final keyId = _editingSpeakerId ?? 'unlabeled';
        return AppSheetSurface(
          surfaceKey: const ValueKey('speaker-management-sheet'),
          title: _editing ? '修改说话人标签' : '说话人管理',
          description: _editing
              ? '只修改显示标签，不会改变事实音频、转录内容或时间轴。'
              : '自动区分和标签修改不会改变事实音频或转录时间轴。',
          semanticsLabel: '说话人管理',
          footer: _editing
              ? Row(
                  children: [
                    Expanded(
                      child: FButton(
                        key: const ValueKey('cancel-speaker-label-edit'),
                        variant: FButtonVariant.outline,
                        onPress: viewModel.isProcessing || _saving
                            ? null
                            : _finishEditing,
                        child: const Text('取消'),
                      ),
                    ),
                    SizedBox(width: appStyle.spaceSm),
                    Expanded(
                      child: FButton(
                        key: ValueKey('save-speaker-label-$keyId'),
                        onPress: viewModel.isProcessing || _saving
                            ? null
                            : () => unawaited(_saveLabel()),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                )
              : null,
          child: _editing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      key: ValueKey('speaker-label-$keyId'),
                      controller: _controller!,
                      label: '显示名称',
                      hint: '输入说话人名称',
                    ),
                    if (_saveFailed) ...[
                      SizedBox(height: appStyle.spaceSm),
                      Text(
                        '标签保存未完成，请检查名称后重试。',
                        key: const ValueKey('speaker-label-save-error'),
                        style: context.theme.typography.body.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                )
              : _managementContent(context, viewModel),
        );
      },
    );
  }

  Widget _managementContent(
    BuildContext context,
    MeetingDetailViewModel viewModel,
  ) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final groups = viewModel.speakerGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.diarizationAvailable)
          FSwitch(
            key: const ValueKey('speaker-diarization-switch'),
            value: viewModel.diarizationEnabled,
            enabled: !viewModel.isProcessing,
            onChange: (enabled) =>
                unawaited(viewModel.setDiarizationEnabled(enabled)),
            label: const Text('自动区分说话人'),
            description: const Text('关闭后不再自动处理；现有标签保持不变。'),
          )
        else
          Text(
            groups.isEmpty ? '本机说话人模型不可用，暂无可管理的标签。' : '本机说话人模型不可用，仍可手工修改现有标签。',
            key: const ValueKey('diarization-unavailable-reason'),
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        if (viewModel.isDiarizing) ...[
          SizedBox(height: appStyle.spaceLg),
          const FProgress(semanticsLabel: '说话人分离处理中'),
          SizedBox(height: appStyle.spaceSm),
          Text(
            '正在重新区分说话人，最终转录仍可查看。',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ] else if (viewModel.diarizationMessage case final message?) ...[
          SizedBox(height: appStyle.spaceLg),
          Text('状态', style: theme.typography.body.sm),
          SizedBox(height: appStyle.space2Xs),
          Text(
            message,
            key: const ValueKey('speaker-management-status'),
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
        if (viewModel.diarizationStatus == SpeakerDiarizationStatus.degraded &&
            viewModel.canRetryDiarization) ...[
          SizedBox(height: appStyle.spaceMd),
          Align(
            alignment: Alignment.centerLeft,
            child: FButton(
              key: const ValueKey('retry-speaker-diarization'),
              variant: FButtonVariant.outline,
              mainAxisSize: MainAxisSize.min,
              onPress: () => unawaited(viewModel.retryDiarization()),
              child: const Text('重新处理'),
            ),
          ),
        ],
        SizedBox(height: appStyle.spaceLg),
        Text('标签', style: theme.typography.body.sm),
        SizedBox(height: appStyle.spaceSm),
        if (groups.isEmpty)
          Text(
            '暂无可修改的说话人标签。',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          )
        else
          FTileGroup(
            semanticsLabel: '说话人标签',
            children: [
              for (final group in groups)
                FTile(
                  key: ValueKey(
                    'speaker-label-row-${group.speakerId ?? 'unlabeled'}',
                  ),
                  enabled: !viewModel.isProcessing,
                  title: Text(group.displayLabel),
                  subtitle: Text('${group.segmentCount} 个片段'),
                  suffix: const Icon(FLucideIcons.pencil, size: 16),
                  onPress: () => _beginEditing(group),
                ),
            ],
          ),
      ],
    );
  }

  void _beginEditing(SpeakerLabelGroup group) {
    _controller?.dispose();
    setState(() {
      _editing = true;
      _editingSpeakerId = group.speakerId;
      _controller = TextEditingController(text: group.displayLabel);
      _saving = false;
      _saveFailed = false;
    });
  }

  void _finishEditing() {
    _controller?.dispose();
    setState(() {
      _editing = false;
      _editingSpeakerId = null;
      _controller = null;
      _saving = false;
      _saveFailed = false;
    });
  }

  Future<void> _saveLabel() async {
    final controller = _controller;
    if (controller == null || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await widget.viewModel.renameSpeaker(
      _editingSpeakerId,
      controller.text,
    );
    if (!mounted) {
      return;
    }
    if (saved) {
      _finishEditing();
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }
}
