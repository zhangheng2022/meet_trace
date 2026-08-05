// THESIS: 设置页是一张本地运行账本，让用户确认新会议默认值、离线资源和本机数据状态。
// OWN-WORLD: 连续分区、细规则线、对齐数值与按状态提升的维护操作，不使用卡片仪表盘。
// STORY: 先确认新会议使用什么，再核对资源是否可用，最后查看存储、隐私与诊断入口。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/asr_model.dart';
import '../../../../theme/theme.dart';
import '../../../core/asr_model_option.dart';
import '../../../core/app_back_icon.dart';
import '../../../core/app_dialog.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_responsive.dart';
import '../view_models/data_controls_view_model.dart';
import '../view_models/model_settings_view_model.dart';

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
        childPad: false,
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
    final appStyle = context.theme.style.app;
    final descriptor = viewModel.registry.requireById(viewModel.defaultModelId);
    final option = viewModel.options.isEmpty ? null : viewModel.options.first;
    final modelLedger = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.errorMessage case final message?) ...[
          FAlert(
            variant: FAlertVariant.destructive,
            title: const Text('模型设置未完成'),
            subtitle: Text(message),
          ),
          SizedBox(height: appStyle.spaceLg),
        ],
        _MeetingDefaultsSection(
          descriptor: descriptor,
          loading: viewModel.isLoading,
        ),
        SizedBox(height: appStyle.spaceXl),
        _OfflineResourcesSection(
          option: option,
          loading: viewModel.isLoading,
          busy: viewModel.isBusy,
          onRepair: viewModel.actions.repair == null
              ? null
              : () => unawaited(viewModel.repairModel()),
          onPause: viewModel.actions.pause == null
              ? null
              : viewModel.pauseRepair,
        ),
      ],
    );
    final dataControls = widget.dataControls;
    return SingleChildScrollView(
      child: AppPageBody(
        width: AppPageWidth.wide,
        child: AppResponsiveBuilder(
          builder: (context, sizeClass, constraints) {
            if (dataControls == null) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: appStyle.readingContentMaxWidth,
                  ),
                  child: modelLedger,
                ),
              );
            }
            final dataLedger = ListenableBuilder(
              listenable: dataControls,
              builder: (context, _) => _DataLedger(viewModel: dataControls),
            );
            if (sizeClass != AppWindowSizeClass.expanded) {
              return Column(
                key: const ValueKey('settings-single-column'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  modelLedger,
                  SizedBox(height: appStyle.spaceXl),
                  dataLedger,
                ],
              );
            }
            return Row(
              key: const ValueKey('settings-two-column'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: modelLedger),
                SizedBox(width: appStyle.spaceXl),
                Expanded(child: dataLedger),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _MeetingDefaultsSection extends StatelessWidget {
  const _MeetingDefaultsSection({
    required this.descriptor,
    required this.loading,
  });

  final AsrModelDescriptor descriptor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      key: const ValueKey('meeting-defaults-section'),
      title: '会议默认',
      child: _SettingsValueRow(
        key: const ValueKey('default-transcription-model'),
        label: '新会议转录模型',
        value: loading ? '正在读取' : descriptor.displayName,
        description: '只影响后续新会议；录音开始后模型锁定，不会自动切换。',
      ),
    );
  }
}

final class _OfflineResourcesSection extends StatelessWidget {
  const _OfflineResourcesSection({
    required this.option,
    required this.loading,
    required this.busy,
    required this.onRepair,
    required this.onPause,
  });

  final AsrModelOption? option;
  final bool loading;
  final bool busy;
  final VoidCallback? onRepair;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return _SettingsSection(
      key: const ValueKey('offline-resources-section'),
      title: '离线转录资源',
      topRule: true,
      child: option == null
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: appStyle.spaceSm),
              child: loading
                  ? const FProgress(semanticsLabel: '正在读取离线转录资源')
                  : const Text('没有可用的离线转录资源。'),
            )
          : _ModelResourceLedger(
              option: option!,
              busy: busy,
              onRepair: onRepair,
              onPause: onPause,
            ),
    );
  }
}

final class _ModelResourceLedger extends StatelessWidget {
  const _ModelResourceLedger({
    required this.option,
    required this.busy,
    required this.onRepair,
    required this.onPause,
  });

  final AsrModelOption option;
  final bool busy;
  final VoidCallback? onRepair;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final descriptor = option.descriptor;
    final action = _prominentAction();
    final processing = switch (option.status) {
      AsrModelUiStatus.checking ||
      AsrModelUiStatus.verifying ||
      AsrModelUiStatus.deleting => true,
      _ => false,
    };
    return Column(
      key: const ValueKey('model-resource-ledger'),
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
                    descriptor.displayName,
                    style: theme.typography.display.md,
                  ),
                  SizedBox(height: appStyle.spaceXs),
                  Text(
                    '${_languageLabel(descriptor.supportedLanguages)} · '
                    '${_decimalMegabytes(descriptor.requiredBytes)}',
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
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
            if (option.status == AsrModelUiStatus.installed &&
                onRepair != null) ...[
              SizedBox(width: appStyle.spaceXs),
              _ModelMaintenanceMenu(busy: busy, onRepair: onRepair!),
            ],
          ],
        ),
        SizedBox(height: appStyle.spaceSm),
        Text(
          '版本 ${descriptor.version} · 自动识别语言'
          '${descriptor.useInverseTextNormalization ? ' · ITN 已开启' : ''}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        if (processing || action != null) ...[
          SizedBox(height: appStyle.spaceMd),
          if (processing)
            FProgress(semanticsLabel: '${option.statusLabel}离线转录资源')
          else
            Align(alignment: Alignment.centerLeft, child: action!),
        ],
      ],
    );
  }

  Widget? _prominentAction() => switch (option.status) {
    AsrModelUiStatus.notInstalled =>
      onRepair == null
          ? null
          : FButton(
              key: const ValueKey('repair-model-resource'),
              onPress: busy ? null : onRepair,
              child: const Text('下载并修复'),
            ),
    AsrModelUiStatus.downloading =>
      onPause == null
          ? null
          : FButton(
              key: const ValueKey('pause-model-download'),
              variant: FButtonVariant.outline,
              onPress: onPause,
              child: const Text('暂停下载'),
            ),
    AsrModelUiStatus.paused ||
    AsrModelUiStatus.failed ||
    AsrModelUiStatus.insufficientStorage =>
      onRepair == null
          ? null
          : FButton(
              key: const ValueKey('repair-model-resource'),
              onPress: busy ? null : onRepair,
              child: const Text('继续或重试'),
            ),
    AsrModelUiStatus.updateAvailable =>
      onRepair == null
          ? null
          : FButton(
              key: const ValueKey('repair-model-resource'),
              onPress: busy ? null : onRepair,
              child: const Text('校验并更新'),
            ),
    AsrModelUiStatus.installed ||
    AsrModelUiStatus.checking ||
    AsrModelUiStatus.verifying ||
    AsrModelUiStatus.deleting => null,
  };
}

final class _ModelMaintenanceMenu extends StatelessWidget {
  const _ModelMaintenanceMenu({required this.busy, required this.onRepair});

  final bool busy;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    return FPopoverMenu.tiles(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      semanticsLabel: '模型维护操作',
      menuBuilder: (context, controller, _) => [
        FTileGroup(
          children: [
            FTile(
              key: const ValueKey('verify-and-repair-model'),
              prefix: const Icon(FLucideIcons.refreshCcw),
              title: const Text('校验并修复'),
              subtitle: const Text('核对本地文件完整性，必要时重新下载'),
              onPress: () async {
                await controller.hide();
                onRepair();
              },
            ),
          ],
        ),
      ],
      builder: (context, controller, child) => FButton(
        key: const ValueKey('model-maintenance-menu'),
        variant: FButtonVariant.ghost,
        mainAxisSize: MainAxisSize.min,
        prefix: const Icon(FLucideIcons.ellipsis),
        onPress: busy ? null : () => unawaited(controller.toggle()),
        child: const Text('维护'),
      ),
    );
  }
}

final class _DataLedger extends StatelessWidget {
  const _DataLedger({required this.viewModel});

  final DataControlsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoragePrivacySection(viewModel: viewModel),
        SizedBox(height: appStyle.spaceXl),
        _DiagnosticsSection(viewModel: viewModel),
      ],
    );
  }
}

final class _StoragePrivacySection extends StatelessWidget {
  const _StoragePrivacySection({required this.viewModel});

  final DataControlsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final usage = viewModel.usage;
    return _SettingsSection(
      key: const ValueKey('storage-privacy-section'),
      title: '存储与隐私',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: appStyle.spaceSm),
              child: const FProgress(semanticsLabel: '正在读取本地存储用量'),
            )
          else if (usage == null) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: const Text('存储用量读取失败'),
              subtitle: const Text('本地数据没有被修改，可以重新读取。'),
            ),
            SizedBox(height: appStyle.spaceMd),
            FButton(
              key: const ValueKey('retry-storage-usage'),
              variant: FButtonVariant.outline,
              onPress: () => unawaited(viewModel.load()),
              child: const Text('重新读取'),
            ),
          ] else ...[
            _StorageMetricRow(
              key: const ValueKey('storage-total'),
              label: '应用总计',
              value: _byteLabel(usage.totalBytes),
              emphasis: true,
            ),
            _StorageMetricRow(
              label: '会议数据',
              value: _byteLabel(usage.meetingBytes),
            ),
            _StorageMetricRow(
              label: '模型数据',
              value: _byteLabel(usage.modelBytes),
            ),
            _StorageMetricRow(
              label: '数据库',
              value: _byteLabel(usage.databaseBytes),
            ),
            _StorageMetricRow(
              label: '设备可用',
              value: _byteLabel(usage.freeBytes),
            ),
          ],
          SizedBox(height: appStyle.spaceMd),
          Text(
            '会议录音、最终转录与运行资源只保存在本机；卸载应用可能永久删除这些数据。',
            style: context.theme.typography.body.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

final class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({required this.viewModel});

  final DataControlsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final message = viewModel.usage == null ? null : viewModel.message;
    return _SettingsSection(
      key: const ValueKey('diagnostics-section'),
      title: '诊断',
      topRule: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FTileGroup(
            children: [
              FTile(
                key: const ValueKey('export-diagnostics'),
                prefix: const Icon(FLucideIcons.fileJson2),
                title: const Text('查看并分享诊断信息'),
                subtitle: const Text('仅含状态、用量、模型版本和错误码'),
                suffix: const Icon(FLucideIcons.chevronRight),
                enabled: !viewModel.isBusy,
                onPress: () => unawaited(_confirmExport(context)),
              ),
            ],
          ),
          if (message != null) ...[
            SizedBox(height: appStyle.spaceMd),
            FAlert(
              variant: message.contains('失败')
                  ? FAlertVariant.destructive
                  : FAlertVariant.primary,
              title: Text(message),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmExport(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: '确认分享诊断信息',
      title: '分享诊断信息？',
      message: '诊断信息不包含会议标题、最终转录、事实音频或本地路径。',
      cancelLabel: '取消',
      confirmLabel: '查看并分享',
      confirmKey: const ValueKey('confirm-export-diagnostics'),
    );
    if (confirmed == true && context.mounted) {
      await viewModel.exportDiagnostics();
    }
  }
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.topRule = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool topRule;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: topRule
            ? Border(top: BorderSide(color: theme.colors.border))
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topRule ? appStyle.spaceLg : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.typography.display.md),
            SizedBox(height: appStyle.spaceMd),
            child,
          ],
        ),
      ),
    );
  }
}

final class _SettingsValueRow extends StatelessWidget {
  const _SettingsValueRow({
    required this.label,
    required this.value,
    required this.description,
    super.key,
  });

  final String label;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final labels = largeText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.typography.body.md),
              SizedBox(height: appStyle.spaceXs),
              Text(value, style: theme.typography.body.md),
            ],
          )
        : Row(
            children: [
              Expanded(child: Text(label, style: theme.typography.body.md)),
              SizedBox(width: appStyle.spaceMd),
              Text(value, style: theme.typography.body.md),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labels,
        SizedBox(height: appStyle.spaceSm),
        Text(
          description,
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

final class _StorageMetricRow extends StatelessWidget {
  const _StorageMetricRow({
    required this.label,
    required this.value,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final style = theme.typography.body.sm.copyWith(
      fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: appStyle.spaceXs),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: style),
                SizedBox(height: appStyle.space2Xs),
                Text(value, style: style),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(label, style: style)),
                SizedBox(width: appStyle.spaceMd),
                Text(value, style: style),
              ],
            ),
    );
  }
}

String _languageLabel(List<String> languages) {
  const labels = {'zh': '中', 'yue': '粤', 'en': '英', 'ja': '日', 'ko': '韩'};
  return '${languages.map((language) => labels[language] ?? language).join('、')}语';
}

String _decimalMegabytes(int bytes) =>
    '${(bytes / 1000 / 1000).toStringAsFixed(1)} MB';

String _byteLabel(int bytes) {
  const mib = 1024 * 1024;
  const gib = 1024 * mib;
  if (bytes >= gib) {
    return '${(bytes / gib).toStringAsFixed(2)} GiB';
  }
  return '${(bytes / mib).toStringAsFixed(1)} MiB';
}
