part of '../meeting_detail_view.dart';

final class _AudioCard extends StatelessWidget {
  const _AudioCard({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final playing =
        viewModel.playbackState.status == AudioPlaybackStatus.playing;
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
  bool _confirmingDelete = false;

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
            SizedBox(height: appStyle.spaceSm),
            FButton(
              key: const ValueKey('request-share-audio'),
              onPress:
                  viewModel.actions.canShareAudio && !viewModel.isProcessing
                  ? () => unawaited(_requestAudioShare(viewModel))
                  : null,
              child: const Text('单独分享音频'),
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
                    const Text('将删除本场录音、转录、说话人标签和处理记录，无法撤销。'),
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
            '${_byteLabel(preparation.storage.shortageBytes)}，未创建任何文件。',
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: '确认分享会议音频',
      title: '确认单独分享音频？',
      message:
          '会议：${preparation.meetingTitle}\n'
          '时长：${_duration(preparation.durationMs)}\n'
          '文件：${_byteLabel(preparation.storage.wavBytes)} WAV\n\n'
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
            Text(
              '使用本场锁定的 ${viewModel.sourceModel.displayName} 重新转录，'
              '生成独立快照；成功后才替换当前结果。',
            ),
            SizedBox(height: appStyle.spaceMd),
            FButton(
              onPress: () => unawaited(viewModel.retranscribe()),
              child: const Text('使用本场锁定模型重新转录'),
            ),
          ],
        ),
      ),
    );
  }
}

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

String _byteLabel(int bytes) {
  const kib = 1024;
  const mib = kib * 1024;
  if (bytes >= mib) {
    return '${(bytes / mib).toStringAsFixed(1)} MiB';
  }
  if (bytes >= kib) {
    return '${(bytes / kib).toStringAsFixed(1)} KiB';
  }
  return '$bytes B';
}
