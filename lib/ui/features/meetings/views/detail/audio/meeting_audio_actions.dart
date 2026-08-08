import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/ports/audio_playback.dart';
import '../../../../../../domain/use_cases/build_meeting_share.dart';
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
      child: Text(playing ? '停止播放' : '播放录音'),
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
                      Text('本地事实录音', style: theme.typography.body.lg),
                      SizedBox(height: appStyle.space2Xs),
                      Text(
                        '录音仅保存在本机 · '
                        '${meetingDurationLabel(viewModel.meeting.audioDurationMs)}',
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
                    child: const Text('取消'),
                  );
                  final save = FButton(
                    key: const ValueKey('save-transcript-revision'),
                    size: FButtonSizeVariant.lg,
                    onPress: saving ? null : onSave,
                    child: Text(saving ? '正在保存' : '保存修订'),
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
      semanticsLabel: '分享会议',
      semanticsTooltip: '分享会议',
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
      barrierLabel: '关闭分享会议面板',
      builder: (context) => _MeetingActionSheet(
        title: '分享会议',
        description: '文本只包含最终转录；事实音频需要单独确认。',
        semanticsLabel: '会议分享方式',
        actions: [
          FTile(
            key: const ValueKey('share-plain-text'),
            enabled: viewModel.canShare,
            prefix: const Icon(FLucideIcons.fileText),
            title: const Text('纯文本'),
            subtitle: const Text('适合消息和邮件正文'),
            onPress: () =>
                Navigator.of(context).pop(_MeetingShareAction.plainText),
          ),
          FTile(
            key: const ValueKey('share-markdown'),
            enabled: viewModel.canShare,
            prefix: const Icon(FLucideIcons.fileCode2),
            title: const Text('Markdown'),
            subtitle: const Text('保留标题、时间戳和结构'),
            onPress: () =>
                Navigator.of(context).pop(_MeetingShareAction.markdown),
          ),
          FTile(
            key: const ValueKey('share-audio'),
            enabled: viewModel.canShareAudio,
            prefix: const Icon(FLucideIcons.fileAudio),
            title: const Text('单独分享音频'),
            subtitle: const Text('生成临时 WAV，并再次确认隐私风险'),
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
        semanticsLabel: '音频分享空间不足',
        title: '可用空间不足',
        message:
            '生成临时 WAV 还缺少 '
            '${formatStorageBytes(preparation.storage.shortageBytes)}，未创建任何文件。',
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: '确认分享会议音频',
      title: '确认单独分享音频？',
      message:
          '会议：${preparation.meetingTitle}\n'
          '时长：${meetingDurationLabel(preparation.durationMs)}\n'
          '文件：${formatStorageBytes(preparation.storage.wavBytes)} WAV\n\n'
          '录音可能包含敏感或私密信息。确认后才会生成临时副本并打开系统分享面板；不会附带转录文本。',
      cancelLabel: '取消',
      confirmLabel: '生成并分享',
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
        semanticsLabel: '更多会议操作',
        semanticsTooltip: '更多会议操作',
        onPress: viewModel.isProcessing
            ? null
            : () => unawaited(_showActionSheet(viewModel)),
      );
    }
    return FPopoverMenu.tiles(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      semanticsLabel: '更多会议操作',
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
        semanticsLabel: '更多会议操作',
        semanticsTooltip: '更多会议操作',
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
      barrierLabel: '关闭更多会议操作',
      builder: (context) => _MeetingActionSheet(
        title: '更多操作',
        description: '低频操作集中在这里；删除会议后无法恢复。',
        semanticsLabel: '更多会议操作',
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
        title: const Text('重新生成转录'),
        subtitle: Text('继续使用本场锁定的 ${viewModel.sourceModel.displayName}'),
        onPress: () => onSelected(_MeetingMoreAction.retranscribe),
      ),
    FTile(
      key: const ValueKey('request-delete-meeting'),
      variant: FItemVariant.destructive,
      prefix: const Icon(FLucideIcons.trash2),
      title: const Text('删除会议'),
      subtitle: const Text('同时删除事实录音和全部派生结果'),
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
      semanticsLabel: '确认永久删除会议',
      title: '永久删除这场会议？',
      message: '将删除本场事实录音、转录、说话人标签和处理记录，无法撤销。',
      cancelLabel: '取消',
      confirmLabel: '删除全部数据',
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
