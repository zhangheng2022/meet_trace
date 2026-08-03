part of '../meeting_detail_view.dart';

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

String _modelPositioning(AsrModelDescriptor _) => '自动识别中、粤、英、日、韩语 · ITN 已开启';

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
