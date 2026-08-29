import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/ports/audio_playback.dart';
import '../../../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_dialog.dart';
import '../../../../../core/app_sheet.dart';
import '../../../../../core/app_value_formatters.dart';
import '../../../view_models/detail/meeting_detail_view_model.dart';
import '../widgets/meeting_detail_formatters.dart';

final class AudioEvidenceStrip extends StatelessWidget {
  const AudioEvidenceStrip({
    required this.viewModel,
    this.compact = false,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final playing =
        viewModel.playbackState.status == AudioPlaybackStatus.playing;
    final control = FButton(
      key: const ValueKey('toggle-audio-playback'),
      variant: FButtonVariant.outline,
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      prefix: Icon(playing ? FLucideIcons.square : FLucideIcons.play),
      onPress: viewModel.meeting.audioPath == null
          ? null
          : () => unawaited(
              playing ? viewModel.stopPlayback() : viewModel.playFullAudio(),
            ),
      child: Text(
        playing ? context.l10n.stopPlayback : context.l10n.playRecording,
      ),
    );
    return DecoratedBox(
      key: const ValueKey('meeting-audio-evidence-strip'),
      decoration: BoxDecoration(
        color: theme.colors.card,
        border: Border.all(
          color: theme.colors.border,
          width: appStyle.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(appStyle.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceSm),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                compact ||
                constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4;
            final facts = Row(
              children: [
                Icon(
                  FLucideIcons.fileAudio,
                  size: 20,
                  color: theme.colors.mutedForeground,
                ),
                SizedBox(width: appStyle.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.localSourceRecording,
                        style: theme.typography.body.lg,
                      ),
                      SizedBox(height: appStyle.space2Xs),
                      Text(
                        context.l10n.recordingLocalDuration(
                          meetingDurationLabel(
                            viewModel.meeting.audioDurationMs,
                          ),
                        ),
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  facts,
                  SizedBox(height: appStyle.spaceSm),
                  control,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: facts),
                SizedBox(width: appStyle.spaceSm),
                control,
              ],
            );
          },
        ),
      ),
    );
  }
}

final class TranscriptEditBottomBar extends StatelessWidget {
  const TranscriptEditBottomBar({
    required this.saving,
    required this.onCancel,
    required this.onSave,
    super.key,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.card,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            appStyle.spaceMd,
            appStyle.spaceSm,
            appStyle.spaceMd,
            appStyle.spaceMd,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: appStyle.readingContentMaxWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = FButton(
                    key: const ValueKey('cancel-transcript-revision'),
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.lg,
                    onPress: saving ? null : onCancel,
                    child: Text(context.l10n.cancel),
                  );
                  final save = FButton(
                    key: const ValueKey('save-transcript-revision'),
                    size: FButtonSizeVariant.lg,
                    onPress: saving ? null : onSave,
                    child: Text(
                      saving ? context.l10n.saving : context.l10n.saveRevision,
                    ),
                  );
                  if (constraints.maxWidth < appStyle.dualActionMinWidth ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        save,
                        SizedBox(height: appStyle.spaceSm),
                        cancel,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cancel),
                      SizedBox(width: appStyle.spaceSm),
                      Expanded(child: save),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class MeetingShareActionButton extends StatefulWidget {
  const MeetingShareActionButton({required this.viewModel, super.key});

  final MeetingDetailViewModel viewModel;

  @override
  State<MeetingShareActionButton> createState() =>
      _MeetingShareActionButtonState();
}

final class _MeetingShareActionButtonState
    extends State<MeetingShareActionButton> {
  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return FHeaderAction(
      key: const ValueKey('request-share-meeting'),
      icon: const Icon(FLucideIcons.share2),
      semanticsLabel: context.l10n.shareMeeting,
      semanticsTooltip: context.l10n.shareMeeting,
      onPress:
          (viewModel.canShare || viewModel.canShareAudio) &&
              !viewModel.isProcessing
          ? () => unawaited(_requestShare(viewModel))
          : null,
    );
  }

  Future<void> _requestShare(MeetingDetailViewModel viewModel) async {
    final action = await showFSheet<_MeetingShareAction>(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.72,
      barrierLabel: context.l10n.closeShareMeeting,
      builder: (context) => _MeetingActionSheet(
        title: context.l10n.shareMeeting,
        description: context.l10n.shareMeetingDescription,
        semanticsLabel: context.l10n.meetingShareMethods,
        actions: [
          FTile(
            key: const ValueKey('share-plain-text'),
            enabled: viewModel.canShare,
            prefix: const Icon(FLucideIcons.fileText),
            title: Text(context.l10n.plainText),
            subtitle: Text(context.l10n.plainTextDescription),
            onPress: () =>
                Navigator.of(context).pop(_MeetingShareAction.plainText),
          ),
          FTile(
            key: const ValueKey('share-markdown'),
            enabled: viewModel.canShare,
            prefix: const Icon(FLucideIcons.fileCode2),
            title: const Text('Markdown'),
            subtitle: Text(context.l10n.markdownDescription),
            onPress: () =>
                Navigator.of(context).pop(_MeetingShareAction.markdown),
          ),
          FTile(
            key: const ValueKey('share-audio'),
            enabled: viewModel.canShareAudio,
            prefix: const Icon(FLucideIcons.fileAudio),
            title: Text(context.l10n.shareAudioSeparately),
            subtitle: Text(context.l10n.shareAudioSeparatelyDescription),
            onPress: () => Navigator.of(context).pop(_MeetingShareAction.audio),
          ),
        ],
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MeetingShareAction.plainText:
        await viewModel.share(MeetingShareFormat.plainText);
      case _MeetingShareAction.markdown:
        await viewModel.share(MeetingShareFormat.markdown);
      case _MeetingShareAction.audio:
        await _requestAudioShare(viewModel);
    }
  }

  Future<void> _requestAudioShare(MeetingDetailViewModel viewModel) async {
    final preparation = await viewModel.prepareAudioShare();
    if (!mounted || preparation == null) {
      return;
    }
    if (!preparation.canShare) {
      await showAppAlertDialog(
        context: context,
        semanticsLabel: context.l10n.audioShareInsufficientSpace,
        title: context.l10n.availableSpaceInsufficient,
        message: context.l10n.temporaryWavShortage(
          formatStorageBytes(preparation.storage.shortageBytes),
        ),
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: context.l10n.confirmShareMeetingAudio,
      title: context.l10n.confirmShareAudioQuestion,
      message: context.l10n.audioShareConfirmation(
        preparation.meetingTitle,
        meetingDurationLabel(preparation.durationMs),
        formatStorageBytes(preparation.storage.wavBytes),
      ),
      cancelLabel: context.l10n.cancel,
      confirmLabel: context.l10n.generateAndShare,
      confirmKey: const ValueKey('confirm-share-audio'),
    );
    if (confirmed == true && mounted) {
      await viewModel.shareAudio(preparation);
    }
  }
}

enum _MeetingShareAction { plainText, markdown, audio }

enum _MeetingMoreAction { retranscribe, delete }

final class MeetingMoreActionsButton extends StatefulWidget {
  const MeetingMoreActionsButton({
    required this.viewModel,
    required this.onDeleted,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final VoidCallback? onDeleted;

  @override
  State<MeetingMoreActionsButton> createState() =>
      _MeetingMoreActionsButtonState();
}

final class _MeetingMoreActionsButtonState
    extends State<MeetingMoreActionsButton> {
  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final expanded =
        MediaQuery.sizeOf(context).width >=
        context.theme.style.app.wideLayoutMinWidth;
    if (!expanded) {
      return FHeaderAction(
        key: const ValueKey('meeting-more-actions'),
        icon: const Icon(FLucideIcons.ellipsis),
        semanticsLabel: context.l10n.moreMeetingActions,
        semanticsTooltip: context.l10n.moreMeetingActions,
        onPress: viewModel.isProcessing
            ? null
            : () => unawaited(_showActionSheet(viewModel)),
      );
    }
    return FPopoverMenu.tiles(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      semanticsLabel: context.l10n.moreMeetingActions,
      menuBuilder: (context, controller, _) => [
        FTileGroup(
          children: _moreActionTiles(
            viewModel,
            onSelected: (action) =>
                unawaited(_selectPopoverAction(controller, action)),
          ),
        ),
      ],
      builder: (context, controller, child) => FHeaderAction(
        key: const ValueKey('meeting-more-actions'),
        icon: const Icon(FLucideIcons.ellipsis),
        semanticsLabel: context.l10n.moreMeetingActions,
        semanticsTooltip: context.l10n.moreMeetingActions,
        onPress: viewModel.isProcessing
            ? null
            : () => unawaited(controller.toggle()),
      ),
    );
  }

  Future<void> _showActionSheet(MeetingDetailViewModel viewModel) async {
    final action = await showFSheet<_MeetingMoreAction>(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.64,
      barrierLabel: context.l10n.closeMoreMeetingActions,
      builder: (context) => _MeetingActionSheet(
        title: context.l10n.moreActions,
        description: context.l10n.moreActionsDescription,
        semanticsLabel: context.l10n.moreMeetingActions,
        actions: _moreActionTiles(
          viewModel,
          onSelected: (action) => Navigator.of(context).pop(action),
        ),
      ),
    );
    if (mounted && action != null) {
      await _performAction(viewModel, action);
    }
  }

  List<FTileMixin> _moreActionTiles(
    MeetingDetailViewModel viewModel, {
    required ValueChanged<_MeetingMoreAction> onSelected,
  }) => [
    if (viewModel.canRetranscribe)
      FTile(
        key: const ValueKey('retranscribe-meeting'),
        prefix: const Icon(FLucideIcons.rotateCcw),
        title: Text(context.l10n.regenerateTranscript),
        subtitle: Text(
          context.l10n.useLockedModel(viewModel.sourceModel.displayName),
        ),
        onPress: () => onSelected(_MeetingMoreAction.retranscribe),
      ),
    FTile(
      key: const ValueKey('request-delete-meeting'),
      variant: FItemVariant.destructive,
      prefix: const Icon(FLucideIcons.trash2),
      title: Text(context.l10n.deleteMeeting),
      subtitle: Text(context.l10n.deleteMeetingAllDerived),
      onPress: () => onSelected(_MeetingMoreAction.delete),
    ),
  ];

  Future<void> _selectPopoverAction(
    FPopoverController controller,
    _MeetingMoreAction action,
  ) async {
    await controller.hide();
    if (mounted) {
      await _performAction(widget.viewModel, action);
    }
  }

  Future<void> _performAction(
    MeetingDetailViewModel viewModel,
    _MeetingMoreAction action,
  ) async {
    switch (action) {
      case _MeetingMoreAction.retranscribe:
        await viewModel.retranscribe();
      case _MeetingMoreAction.delete:
        await _confirmDelete(viewModel);
    }
  }

  Future<void> _confirmDelete(MeetingDetailViewModel viewModel) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: context.l10n.confirmPermanentDeleteMeeting,
      title: context.l10n.permanentlyDeleteThisMeeting,
      message: context.l10n.deleteThisMeetingMessage,
      cancelLabel: context.l10n.cancel,
      confirmLabel: context.l10n.deleteAllData,
      destructive: true,
      confirmKey: const ValueKey('confirm-delete-meeting'),
    );
    if (confirmed == true && mounted) {
      await viewModel.deleteMeeting();
      if (mounted && viewModel.isDeleted) {
        widget.onDeleted?.call();
      }
    }
  }
}

final class _MeetingActionSheet extends StatelessWidget {
  const _MeetingActionSheet({
    required this.title,
    required this.description,
    required this.semanticsLabel,
    required this.actions,
  });

  final String title;
  final String description;
  final String semanticsLabel;
  final List<FTileMixin> actions;

  @override
  Widget build(BuildContext context) {
    return AppSheetSurface(
      surfaceKey: const ValueKey('meeting-action-sheet-surface'),
      title: title,
      description: description,
      semanticsLabel: semanticsLabel,
      child: FTileGroup(semanticsLabel: semanticsLabel, children: actions),
    );
  }
}
