import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../theme/theme.dart';
import '../view_models/meeting_detail_view_model.dart';

final class MeetingDetailView extends StatefulWidget {
  const MeetingDetailView({
    required this.viewModel,
    required this.onBack,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final VoidCallback onBack;

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
              if (viewModel.isProcessing) _ProcessingCard(viewModel: viewModel),
              if (viewModel.errorMessage case final message?)
                _FailureCard(message: message, viewModel: viewModel),
              if (viewModel.snapshot case final snapshot?)
                _TranscriptCard(snapshot: snapshot),
              if (viewModel.canRetranscribe) ...[
                SizedBox(height: appStyle.spaceMd),
                _RetranscriptionCard(viewModel: viewModel),
              ],
              SizedBox(height: appStyle.spaceMd),
              FCard(
                child: Padding(
                  padding: EdgeInsets.all(appStyle.spaceMd),
                  child: Text(
                    '事实音频：${viewModel.meeting.audioPath ?? '尚未生成'}',
                    style: theme.typography.body.sm,
                  ),
                ),
              ),
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

final class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.snapshot});

  final TranscriptSnapshot snapshot;

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
            if (snapshot.segments.isEmpty)
              const Text('未识别到可显示的语音内容。')
            else
              for (final segment in snapshot.segments) ...[
                Text(
                  '${_timestamp(segment.startMs)}  ${segment.text}',
                  style: theme.typography.body.md,
                ),
                SizedBox(height: appStyle.spaceSm),
              ],
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
