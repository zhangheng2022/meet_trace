// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5
// Hallmark · page: start-meeting · macrostructure: Workbench · theme: Shadcn Neutral
// States: loading · ready · busy · advanced-unavailable · locked · error

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model.dart';
import '../../../../theme/theme.dart';
import '../../../core/app_bottom_action_bar.dart';
import '../../../core/app_back_icon.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_state_panel.dart';
import '../../../core/app_status_notice.dart';
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
              icon: const AppBackIcon(semanticsLabel: '返回会议列表'),
              onPress: widget.onBack,
            ),
          ],
        ),
        childPad: false,
        footer: _footer(context),
        child: _body(context),
      ),
    );
  }

  Widget? _footer(BuildContext context) {
    final viewModel = widget.viewModel;
    if (viewModel.isLoading ||
        viewModel.isModelLocked ||
        viewModel.requiresAdvancedModelAction) {
      return null;
    }

    return AppBottomActionBar(
      supportingText: viewModel.isBusy
          ? '正在检查权限、存储空间和模型；尚未开始录音。'
          : '开始后本场模型锁定；实时转录变慢不会中断本机录音。',
      child: FButton(
        key: const ValueKey('start-recording-action'),
        size: FButtonSizeVariant.lg,
        prefix: const Icon(FLucideIcons.mic),
        onPress: viewModel.isBusy ? null : _start,
        child: Text(viewModel.isBusy ? '正在准备录音' : '开始录音', maxLines: 1),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final viewModel = widget.viewModel;
    final theme = context.theme;
    final appStyle = theme.style.app;
    if (viewModel.isLoading) {
      return const AppStatePanel.loading(label: '正在准备会议设置');
    }

    return AppPageBody(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppStatusNotice(
              tone: AppStatusTone.info,
              title: '事实音频优先保存在本机',
              message: '实时转录变慢或失败时，录音仍会继续；结束后再基于完整音频处理。',
              liveRegion: false,
            ),
            SizedBox(height: appStyle.spaceLg),
            if (viewModel.startedSession case final session?)
              LockedRecordingModelView(
                descriptor: viewModel.registry.requireById(
                  session.meeting.recordingModelId,
                ),
                modelVersion: session.meeting.recordingModelVersion,
              )
            else ...[
              FTextField(
                control: FTextFieldControl.managed(
                  onChange: (value) => viewModel.updateTitle(value.text),
                ),
                label: const Text('会议标题'),
                hint: '例如：产品周会',
              ),
              SizedBox(height: appStyle.spaceXs),
              Text(
                '不填写时保存为“未命名会议”。',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              SizedBox(height: appStyle.spaceLg),
              _ModelSelection(viewModel: viewModel),
              if (viewModel.errorMessage case final message?) ...[
                SizedBox(height: appStyle.spaceMd),
                AppStatusNotice(
                  tone: AppStatusTone.error,
                  title: message,
                  message: '尚未开始录音，本机已有会议和事实音频不受影响；请按提示重试。',
                ),
              ],
              if (viewModel.isBusy) ...[
                SizedBox(height: appStyle.spaceMd),
                const AppStatusNotice(
                  tone: AppStatusTone.info,
                  title: '正在准备录音',
                  message: '正在检查权限、存储空间和模型，请稍候。',
                ),
              ],
              if (viewModel.requiresAdvancedModelAction) ...[
                SizedBox(height: appStyle.spaceLg),
                _AdvancedUnavailableActions(
                  viewModel: viewModel,
                  onStarted: widget.onStarted,
                ),
              ],
            ],
          ],
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
    final selectionScope = viewModel.selectedModelId == viewModel.defaultModelId
        ? '使用全局默认'
        : '仅本场覆盖全局默认';
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
        SizedBox(height: appStyle.spaceXs),
        Text(
          '$selectionScope · ${selected.statusLabel} · 开始后不可切换',
          key: const ValueKey('meeting-model-scope'),
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        if (selected.descriptor.tier == AsrModelTier.advanced) ...[
          SizedBox(height: appStyle.spaceMd),
          const AppStatusNotice(
            tone: AppStatusTone.warning,
            title: '高级模型资源占用较高',
            message: '准确率优先，但会增加内存、耗电和发热；开始后本场不可切换。',
            liveRegion: false,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStatusNotice(
          tone: AppStatusTone.warning,
          title: '高级模型尚不可用',
          message: viewModel.actions.download == null
              ? '当前没有可用的下载入口；可明确改用标准模型并开始，或取消本次选择。'
              : '完成下载和校验后再开始，或明确改用标准模型并开始。',
        ),
        SizedBox(height: appStyle.spaceMd),
        FButton(
          size: FButtonSizeVariant.lg,
          prefix: const Icon(FLucideIcons.download),
          onPress: viewModel.actions.download == null
              ? null
              : () => unawaited(viewModel.downloadAdvanced()),
          child: const Text('下载高级模型', maxLines: 1),
        ),
        SizedBox(height: appStyle.spaceSm),
        FButton(
          variant: FButtonVariant.outline,
          size: FButtonSizeVariant.lg,
          onPress: () => unawaited(_useStandard()),
          child: const Text('改用标准模型并开始', maxLines: 1),
        ),
        SizedBox(height: appStyle.spaceSm),
        FButton(
          variant: FButtonVariant.ghost,
          size: FButtonSizeVariant.lg,
          onPress: viewModel.cancelAdvancedAction,
          child: const Text('取消本次选择', maxLines: 1),
        ),
      ],
    );
  }

  Future<void> _useStandard() async {
    final session = await viewModel.useStandardAndStart();
    if (session != null) {
      onStarted?.call(session);
    }
  }
}
