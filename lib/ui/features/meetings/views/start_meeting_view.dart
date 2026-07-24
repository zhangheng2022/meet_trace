import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model.dart';
import '../../../../theme/theme.dart';
import '../view_models/start_meeting_view_model.dart';
import 'locked_recording_model_view.dart';

final class StartMeetingView extends StatefulWidget {
  const StartMeetingView({
    required this.viewModel,
    this.onStarted,
    this.onBack,
    super.key,
  });

  final StartMeetingViewModel viewModel;
  final ValueChanged<StartedMeetingSession>? onStarted;
  final VoidCallback? onBack;

  @override
  State<StartMeetingView> createState() => _StartMeetingViewState();
}

final class _StartMeetingViewState extends State<StartMeetingView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => FScaffold(
        header: FHeader.nested(
          title: const Text('开始会议'),
          prefixes: [
            FHeaderAction(
              icon: context.theme.icons.arrowLeft(
                context,
                semanticsLabel: '返回会议列表',
              ),
              onPress: widget.onBack,
            ),
          ],
        ),
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final viewModel = widget.viewModel;
    final theme = context.theme;
    final appStyle = theme.style.app;
    if (viewModel.isLoading) {
      return const Center(child: FProgress(semanticsLabel: '准备会议模型'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(appStyle.spaceMd),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FTextField(
                control: FTextFieldControl.managed(
                  onChange: (value) => viewModel.updateTitle(value.text),
                ),
                label: const Text('会议标题'),
                hint: '可选',
              ),
              SizedBox(height: appStyle.spaceMd),
              if (viewModel.startedSession case final session?)
                LockedRecordingModelView(
                  descriptor: viewModel.registry.requireById(
                    session.meeting.recordingModelId,
                  ),
                  modelVersion: session.meeting.recordingModelVersion,
                )
              else
                _ModelSelection(viewModel: viewModel),
              if (viewModel.errorMessage case final message?) ...[
                SizedBox(height: appStyle.spaceMd),
                FAlert(
                  variant: FAlertVariant.destructive,
                  title: Text(message),
                ),
              ],
              if (viewModel.requiresAdvancedModelAction) ...[
                SizedBox(height: appStyle.spaceMd),
                _AdvancedUnavailableActions(
                  viewModel: viewModel,
                  onStarted: widget.onStarted,
                ),
              ],
              if (!viewModel.isModelLocked) ...[
                SizedBox(height: appStyle.spaceLg),
                FButton(
                  onPress: viewModel.isBusy ? null : _start,
                  child: Text(viewModel.isBusy ? '正在准备…' : '开始录音'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    final session = await widget.viewModel.start();
    if (session != null) {
      widget.onStarted?.call(session);
    }
  }
}

final class _ModelSelection extends StatelessWidget {
  const _ModelSelection({required this.viewModel});

  final StartMeetingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final selected = viewModel.selectedOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FAccordion(
          children: [
            FAccordionItem(
              initiallyExpanded: false,
              title: Text('转录模型：${selected.descriptor.displayName}'),
              child: Column(
                children: [
                  for (final option in viewModel.options)
                    Padding(
                      padding: EdgeInsets.only(bottom: appStyle.spaceMd),
                      child: FRadio(
                        key: ValueKey(
                          'meeting-model-${option.descriptor.modelId}',
                        ),
                        value:
                            option.descriptor.modelId ==
                            viewModel.selectedModelId,
                        onChange: (_) =>
                            viewModel.chooseModel(option.descriptor.modelId),
                        label: Text(option.descriptor.displayName),
                        description: Text(
                          '${option.positioningLabel} · ${option.statusLabel}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (selected.descriptor.tier == AsrModelTier.advanced) ...[
          SizedBox(height: appStyle.spaceMd),
          const FAlert(
            title: Text('高级模型资源提示'),
            subtitle: Text('准确率优先，但会增加内存、耗电和发热；开始后本场不可切换。'),
          ),
        ],
      ],
    );
  }
}

final class _AdvancedUnavailableActions extends StatelessWidget {
  const _AdvancedUnavailableActions({
    required this.viewModel,
    required this.onStarted,
  });

  final StartMeetingViewModel viewModel;
  final ValueChanged<StartedMeetingSession>? onStarted;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return FAlert(
      title: const Text('高级模型尚不可用'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('完成下载和校验后再开始，或明确确认本场改用标准模型。'),
          SizedBox(height: appStyle.spaceMd),
          Wrap(
            spacing: appStyle.spaceSm,
            runSpacing: appStyle.spaceSm,
            children: [
              FButton(
                onPress: viewModel.actions.download == null
                    ? null
                    : () => unawaited(viewModel.downloadAdvanced()),
                child: const Text('下载高级模型'),
              ),
              FButton(
                onPress: () => unawaited(_useStandard()),
                child: const Text('改用标准模型'),
              ),
              FButton(
                onPress: viewModel.cancelAdvancedAction,
                child: const Text('取消'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _useStandard() async {
    final session = await viewModel.useStandardAndStart();
    if (session != null) {
      onStarted?.call(session);
    }
  }
}
