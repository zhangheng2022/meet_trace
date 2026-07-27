import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model.dart';
import '../../../../theme/theme.dart';
import '../../../core/asr_model_option.dart';
import '../../../core/app_back_icon.dart';
import '../view_models/model_settings_view_model.dart';
import '../view_models/data_controls_view_model.dart';

final class ModelSettingsView extends StatefulWidget {
  const ModelSettingsView({
    required this.viewModel,
    this.dataControls,
    this.onBack,
    super.key,
  });

  final ModelSettingsViewModel viewModel;
  final DataControlsViewModel? dataControls;
  final VoidCallback? onBack;

  @override
  State<ModelSettingsView> createState() => _ModelSettingsViewState();
}

final class _ModelSettingsViewState extends State<ModelSettingsView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
    unawaited(widget.dataControls?.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => FScaffold(
        header: widget.onBack == null
            ? const FHeader(title: Text('设置'))
            : FHeader.nested(
                title: const Text('设置'),
                prefixes: [
                  FHeaderAction(
                    icon: const AppBackIcon(semanticsLabel: '返回会议列表'),
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
      return const Center(child: FProgress(semanticsLabel: '加载模型设置'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(appStyle.spaceMd),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('转录模型', style: theme.typography.display.lg),
              SizedBox(height: appStyle.spaceSm),
              Text(
                '这里的选择只影响后续新会议，历史会议不会改变。',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              if (viewModel.errorMessage case final message?) ...[
                SizedBox(height: appStyle.spaceMd),
                FAlert(
                  variant: FAlertVariant.destructive,
                  title: Text(message),
                ),
              ],
              SizedBox(height: appStyle.spaceMd),
              for (final option in viewModel.options) ...[
                _ModelSettingsCard(
                  option: option,
                  selected:
                      viewModel.defaultModelId == option.descriptor.modelId,
                  busy: viewModel.isBusy,
                  onSelect: () => unawaited(
                    viewModel.selectDefault(option.descriptor.modelId),
                  ),
                  onDownload: viewModel.actions.download == null
                      ? null
                      : () => unawaited(viewModel.downloadAdvanced()),
                  onCancel: viewModel.actions.cancel == null
                      ? null
                      : viewModel.cancelAdvanced,
                  onRetry: viewModel.actions.retry == null
                      ? null
                      : () => unawaited(viewModel.retryAdvanced()),
                  onDelete: viewModel.actions.delete == null
                      ? null
                      : () => unawaited(viewModel.deleteAdvanced()),
                ),
                SizedBox(height: appStyle.spaceMd),
              ],
              if (widget.dataControls case final controls?) ...[
                ListenableBuilder(
                  listenable: controls,
                  builder: (context, _) =>
                      _DataControlsCard(viewModel: controls),
                ),
                SizedBox(height: appStyle.spaceMd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _DataControlsCard extends StatelessWidget {
  const _DataControlsCard({required this.viewModel});

  final DataControlsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final usage = viewModel.usage;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('存储与隐私', style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceSm),
            const Text('会议录音、转录与模型只保存在本机；卸载应用可能永久删除这些数据。'),
            SizedBox(height: appStyle.spaceMd),
            if (viewModel.isLoading)
              const FProgress(semanticsLabel: '正在读取本地存储用量')
            else if (usage != null) ...[
              Text('会议数据：${_byteLabel(usage.meetingBytes)}'),
              Text('模型数据：${_byteLabel(usage.modelBytes)}'),
              Text('数据库：${_byteLabel(usage.databaseBytes)}'),
              Text('应用总计：${_byteLabel(usage.totalBytes)}'),
              Text('设备可用：${_byteLabel(usage.freeBytes)}'),
            ],
            SizedBox(height: appStyle.spaceMd),
            const Text('诊断信息仅包含状态计数、存储指标、模型版本和错误码；不包含会议标题、转录、音频或本地路径。'),
            SizedBox(height: appStyle.spaceMd),
            FButton(
              key: const ValueKey('export-diagnostics'),
              onPress: viewModel.isBusy
                  ? null
                  : () => unawaited(viewModel.exportDiagnostics()),
              child: const Text('查看并分享诊断信息'),
            ),
            if (viewModel.message case final message?) ...[
              SizedBox(height: appStyle.spaceMd),
              FAlert(title: Text(message)),
            ],
          ],
        ),
      ),
    );
  }
}

String _byteLabel(int bytes) {
  const mib = 1024 * 1024;
  const gib = 1024 * mib;
  if (bytes >= gib) {
    return '${(bytes / gib).toStringAsFixed(2)} GiB';
  }
  return '${(bytes / mib).toStringAsFixed(1)} MiB';
}

final class _ModelSettingsCard extends StatelessWidget {
  const _ModelSettingsCard({
    required this.option,
    required this.selected,
    required this.busy,
    required this.onSelect,
    this.onDownload,
    this.onCancel,
    this.onRetry,
    this.onDelete,
  });

  final AsrModelOption option;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final advanced = option.descriptor.tier == AsrModelTier.advanced;
    final action = advanced ? _action() : null;
    return FCard(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FRadio(
                    key: ValueKey('default-${option.descriptor.modelId}'),
                    value: selected,
                    enabled: option.isInstalled && !busy,
                    onChange: (_) => onSelect(),
                    label: Text(option.descriptor.displayName),
                    description: Text(option.positioningLabel),
                  ),
                ),
                SizedBox(width: appStyle.spaceSm),
                FBadge(
                  variant:
                      option.status == AsrModelUiStatus.failed ||
                          option.status == AsrModelUiStatus.insufficientStorage
                      ? FBadgeVariant.destructive
                      : FBadgeVariant.secondary,
                  child: Text(option.statusLabel),
                ),
              ],
            ),
            if (option.resourceLabel case final resource?) ...[
              SizedBox(height: appStyle.spaceSm),
              Text(
                resource,
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: appStyle.spaceMd),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _action() => switch (option.status) {
    AsrModelUiStatus.notInstalled =>
      onDownload == null
          ? null
          : FButton(
              onPress: busy ? null : onDownload,
              child: const Text('下载高级模型'),
            ),
    AsrModelUiStatus.downloading =>
      onCancel == null
          ? null
          : FButton(onPress: onCancel, child: const Text('取消下载')),
    AsrModelUiStatus.paused ||
    AsrModelUiStatus.failed ||
    AsrModelUiStatus.insufficientStorage =>
      onRetry == null
          ? null
          : FButton(onPress: busy ? null : onRetry, child: const Text('重试下载')),
    AsrModelUiStatus.updateAvailable =>
      onRetry == null
          ? null
          : FButton(
              onPress: busy ? null : onRetry,
              child: const Text('更新高级模型'),
            ),
    AsrModelUiStatus.installed =>
      onDelete == null
          ? null
          : FButton(
              onPress: busy ? null : onDelete,
              child: const Text('删除高级模型'),
            ),
    AsrModelUiStatus.checking ||
    AsrModelUiStatus.verifying ||
    AsrModelUiStatus.deleting => null,
  };
}
