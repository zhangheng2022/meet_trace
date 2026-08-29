import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/speaker_diarization.dart';
import '../../../../../../domain/models/transcript.dart';
import '../../../../../../domain/use_cases/revise_final_transcript.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../l10n/ui_message_localizations.dart';
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
  late Map<String, String> _automaticSpeakerLabels;
  String? _localeName;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = context.l10n.localeName;
    if (_localeName != null && _localeName != localeName) {
      for (final segment in widget.snapshot.segments) {
        final controller = _speakers[segment.id];
        final previous = _automaticSpeakerLabels[segment.id];
        if (controller == null ||
            previous == null ||
            controller.text != previous) {
          continue;
        }
        final current = _speakerLabel(segment.speakerId);
        controller.text = current;
        _automaticSpeakerLabels[segment.id] = current;
      }
    }
    _localeName = localeName;
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
    _automaticSpeakerLabels = {
      for (final segment in widget.snapshot.segments)
        segment.id: _speakerLabel(segment.speakerId),
    };
    _speakers = {
      for (final segment in widget.snapshot.segments)
        segment.id: TextEditingController(
          text: _automaticSpeakerLabels[segment.id],
        ),
    };
  }

  String _speakerLabel(String? speakerId) => displaySpeakerLabel(
    speakerId,
    speakerLabelBuilder: widget.viewModel.speakerLabelBuilder,
  );

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
            Expanded(
              child: Text(
                context.l10n.finalTranscriptTitle,
                style: theme.typography.display.lg,
              ),
            ),
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
                child: Text(
                  widget.editing ? context.l10n.cancel : context.l10n.edit,
                ),
              ),
          ],
        ),
        if (widget.editing) ...[
          SizedBox(height: appStyle.spaceSm),
          Text(
            context.l10n.transcriptRevisionDescription,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
        SizedBox(height: appStyle.spaceSm),
        if (widget.snapshot.segments.isEmpty)
          Text(context.l10n.noRecognizedSpeech)
        else if (widget.editing)
          for (final segment in widget.snapshot.segments) ...[
            Text(
              '${_speakerLabel(segment.speakerId)} · '
              '${meetingTimestampLabel(segment.startMs)}',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            SizedBox(height: appStyle.spaceXs),
            AppTextField(
              key: ValueKey('segment-speaker-${segment.id}'),
              controller: _speakers[segment.id]!,
              label: context.l10n.speaker,
            ),
            SizedBox(height: appStyle.spaceSm),
            AppTextField(
              key: ValueKey('segment-text-${segment.id}'),
              controller: _texts[segment.id]!,
              label: context.l10n.transcriptContent,
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
              speakerLabelBuilder: widget.viewModel.speakerLabelBuilder,
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
    required this.speakerLabelBuilder,
  });

  final TranscriptSegment segment;
  final bool first;
  final bool last;
  final String Function(int number) speakerLabelBuilder;

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
                      displaySpeakerLabel(
                        segment.speakerId,
                        speakerLabelBuilder: speakerLabelBuilder,
                      ),
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
    final status = _speakerOverviewStatus(
      context.l10n,
      viewModel,
      groups.length,
    );
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
                        context.l10n.speakersTitle,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: appStyle.space2Xs),
                      Text(
                        groups.isEmpty
                            ? context.l10n.noSpeakerSegments
                            : context.l10n.speakerSegmentCount(
                                groups.length,
                                segmentCount,
                              ),
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
                  child: Text(context.l10n.manage),
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
    barrierLabel: context.l10n.closeSpeakerManagement,
    builder: (context) => _SpeakerManagementSheet(viewModel: viewModel),
  );
}

String? _speakerOverviewStatus(
  AppLocalizations l10n,
  MeetingDetailViewModel viewModel,
  int speakerCount,
) {
  if (viewModel.isDiarizing) {
    return l10n.speakerReprocessing;
  }
  if (!viewModel.diarizationAvailable) {
    return speakerCount == 0
        ? l10n.speakerModelUnavailable
        : l10n.speakerModelUnavailableManual;
  }
  if (!viewModel.diarizationEnabled) {
    return l10n.speakerAutoDisabled;
  }
  if (viewModel.diarizationStatus == SpeakerDiarizationStatus.degraded) {
    return speakerCount == 1
        ? l10n.speakerDegradedSingle
        : l10n.speakerDegradedEditable;
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
          title: _editing
              ? context.l10n.editSpeakerLabel
              : context.l10n.speakerManagement,
          description: _editing
              ? context.l10n.editSpeakerDescription
              : context.l10n.speakerManagementDescription,
          semanticsLabel: context.l10n.speakerManagement,
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
                        child: Text(context.l10n.cancel),
                      ),
                    ),
                    SizedBox(width: appStyle.spaceSm),
                    Expanded(
                      child: FButton(
                        key: ValueKey('save-speaker-label-$keyId'),
                        onPress: viewModel.isProcessing || _saving
                            ? null
                            : () => unawaited(_saveLabel()),
                        child: Text(context.l10n.save),
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
                      label: context.l10n.displayName,
                      hint: context.l10n.speakerNameHint,
                    ),
                    if (_saveFailed) ...[
                      SizedBox(height: appStyle.spaceSm),
                      Text(
                        context.l10n.speakerLabelSaveFailed,
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
            label: Text(context.l10n.automaticSpeakerSeparation),
            description: Text(
              context.l10n.automaticSpeakerSeparationDescription,
            ),
          )
        else
          Text(
            groups.isEmpty
                ? context.l10n.speakerUnavailableNoLabels
                : context.l10n.speakerUnavailableExistingLabels,
            key: const ValueKey('diarization-unavailable-reason'),
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        if (viewModel.isDiarizing) ...[
          SizedBox(height: appStyle.spaceLg),
          FProgress(semanticsLabel: context.l10n.speakerSeparationProcessing),
          SizedBox(height: appStyle.spaceSm),
          Text(
            context.l10n.speakerReprocessing,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ] else if (viewModel.diarizationMessage case final message?) ...[
          SizedBox(height: appStyle.spaceLg),
          Text(context.l10n.status, style: theme.typography.body.sm),
          SizedBox(height: appStyle.space2Xs),
          Text(
            context.l10n.localizeUiMessage(message),
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
              child: Text(context.l10n.reprocess),
            ),
          ),
        ],
        SizedBox(height: appStyle.spaceLg),
        Text(context.l10n.labels, style: theme.typography.body.sm),
        SizedBox(height: appStyle.spaceSm),
        if (groups.isEmpty)
          Text(
            context.l10n.noEditableSpeakerLabels,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          )
        else
          FTileGroup(
            semanticsLabel: context.l10n.speakerLabelsSemantics,
            children: [
              for (final group in groups)
                FTile(
                  key: ValueKey(
                    'speaker-label-row-${group.speakerId ?? 'unlabeled'}',
                  ),
                  enabled: !viewModel.isProcessing,
                  title: Text(group.displayLabel),
                  subtitle: Text(context.l10n.segmentCount(group.segmentCount)),
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
