// THESIS: 设置页是一张本地运行账本，让用户确认新会议默认值、离线资源和本机数据状态。
// OWN-WORLD: 连续分区、细规则线、对齐数值与按状态提升的维护操作，不使用卡片仪表盘。
// STORY: 先确认新会议使用什么，再核对资源是否可用，最后查看存储、隐私与诊断入口。
// FIRST VIEWPORT: 宽屏维持设置双栏，录音输入位于左栏会议默认与离线资源之间；紧凑宽度自然下排。
// FORM: 继承既有 Quiet Evidence Ledger 的窄范围扩展，不启动新的视觉世界或概念选型。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/app_theme.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/recording_input.dart';
import '../../../../theme/theme.dart';
import '../../../core/asr_model_option.dart';
import '../../../core/app_back_icon.dart';
import '../../../core/app_dialog.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_responsive.dart';
import '../view_models/data_controls_view_model.dart';
import '../view_models/model_settings_view_model.dart';
import '../view_models/theme_settings_view_model.dart';

final class ModelSettingsView extends StatefulWidget {
  const ModelSettingsView({
    required this.viewModel,
    this.dataControls,
    this.themeSettings,
    this.onBack,
    super.key,
  });

  final ModelSettingsViewModel viewModel;
  final DataControlsViewModel? dataControls;
  final ThemeSettingsViewModel? themeSettings;
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
        if (widget.themeSettings case final themeSettings?) ...[
          ListenableBuilder(
            listenable: themeSettings,
            builder: (context, _) =>
                _AppearanceSection(viewModel: themeSettings),
          ),
          SizedBox(height: appStyle.spaceXl),
        ],
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
          topRule: widget.themeSettings != null,
        ),
        if (viewModel.supportsRecordingInputSelection) ...[
          SizedBox(height: appStyle.spaceXl),
          _RecordingInputSection(viewModel: viewModel),
        ],
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

final class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.viewModel});

  final ThemeSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return _SettingsSection(
      key: const ValueKey('appearance-section'),
      title: '外观',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.errorMessage case final message?) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: const Text('主题设置未保存'),
              subtitle: Text(message),
            ),
            SizedBox(height: appStyle.spaceMd),
          ],
          FTileGroup(
            semanticsLabel: '外观主题',
            children: [
              for (final mode in AppThemeMode.values)
                _PreferenceTile(
                  key: ValueKey('theme-mode-${mode.name}'),
                  label: switch (mode) {
                    AppThemeMode.system => '跟随系统',
                    AppThemeMode.light => '浅色',
                    AppThemeMode.dark => '深色',
                  },
                  detail: switch (mode) {
                    AppThemeMode.system => '自动匹配设备外观',
                    AppThemeMode.light => '始终使用浅色外观',
                    AppThemeMode.dark => '始终使用深色外观',
                  },
                  icon: switch (mode) {
                    AppThemeMode.system => FLucideIcons.monitor,
                    AppThemeMode.light => FLucideIcons.sun,
                    AppThemeMode.dark => FLucideIcons.moon,
                  },
                  selected: viewModel.selectedMode == mode,
                  enabled: !viewModel.isBusy,
                  onPress: () => unawaited(viewModel.select(mode)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _MeetingDefaultsSection extends StatelessWidget {
  const _MeetingDefaultsSection({
    required this.descriptor,
    required this.loading,
    this.topRule = false,
  });

  final AsrModelDescriptor descriptor;
  final bool loading;
  final bool topRule;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      key: const ValueKey('meeting-defaults-section'),
      title: '会议默认',
      topRule: topRule,
      child: _SettingsValueRow(
        key: const ValueKey('default-transcription-model'),
        label: '新会议转录模型',
        value: loading ? '正在读取' : descriptor.displayName,
        description: '只影响后续新会议；录音开始后模型锁定，不会自动切换。',
      ),
    );
  }
}

final class _RecordingInputSection extends StatelessWidget {
  const _RecordingInputSection({required this.viewModel});

  final ModelSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    final preference = viewModel.recordingInputPreference;
    final missingSelectedDevice =
        preference != null && !viewModel.selectedRecordingInputAvailable;
    final devices = viewModel.recordingInputOptions;
    return _SettingsSection(
      key: const ValueKey('recording-input-section'),
      title: '录音输入',
      topRule: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '新会议开始时锁定这里的选择；会议中设备断开时仅回退一次系统默认麦克风。',
            style: context.theme.typography.body.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          SizedBox(height: appStyle.spaceMd),
          if (viewModel.recordingInputErrorMessage case final message?) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: const Text('麦克风设置未完成'),
              subtitle: Text(message),
            ),
            SizedBox(height: appStyle.spaceMd),
          ],
          if (preference == null) ...[
            if (viewModel.recordingInputsLoading)
              const FProgress(semanticsLabel: '正在读取 Windows 麦克风列表'),
          ] else ...[
            FTileGroup(
              semanticsLabel: 'Windows 录音输入设备',
              children: [
                _PreferenceTile(
                  key: const ValueKey('recording-input-system-default'),
                  label: '系统默认麦克风',
                  detail: '由 Windows 在每场会议开始时解析',
                  selected: preference.usesSystemDefault,
                  enabled:
                      !viewModel.recordingInputBusy &&
                      !viewModel.recordingInputsLoading,
                  onPress: () => unawaited(
                    viewModel.selectRecordingInput(
                      const RecordingInputPreference.systemDefault(),
                    ),
                  ),
                  icon: FLucideIcons.mic,
                ),
                if (missingSelectedDevice)
                  _PreferenceTile(
                    key: const ValueKey('recording-input-unavailable'),
                    label: preference.lastKnownLabel!,
                    detail: '当前不可用，请连接设备或选择其他麦克风',
                    selected: true,
                    enabled: false,
                    onPress: null,
                    icon: FLucideIcons.mic,
                  ),
                for (final device in devices)
                  _PreferenceTile(
                    key: ValueKey('recording-input-${device.id}'),
                    label: device.label,
                    detail: 'Windows 输入设备',
                    selected: preference.deviceId == device.id,
                    enabled:
                        !viewModel.recordingInputBusy &&
                        !viewModel.recordingInputsLoading,
                    onPress: () => unawaited(
                      viewModel.selectRecordingInput(
                        RecordingInputPreference.device(
                          deviceId: device.id,
                          lastKnownLabel: device.label,
                        ),
                      ),
                    ),
                    icon: FLucideIcons.mic,
                  ),
              ],
            ),
            if (devices.isEmpty) ...[
              SizedBox(height: appStyle.spaceSm),
              Text(
                '未发现其他麦克风，仍可使用系统默认麦克风。',
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
            if (viewModel.recordingInputsLoading) ...[
              SizedBox(height: appStyle.spaceSm),
              const FProgress(semanticsLabel: '正在重新扫描 Windows 麦克风列表'),
            ],
          ],
          if (viewModel.recordingInputStatusMessage case final status?) ...[
            SizedBox(height: appStyle.spaceSm),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ),
          ],
          SizedBox(height: appStyle.spaceSm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FButton(
              key: const ValueKey('refresh-recording-inputs'),
              variant: FButtonVariant.ghost,
              onPress:
                  viewModel.recordingInputsLoading ||
                      viewModel.recordingInputBusy
                  ? null
                  : () => unawaited(viewModel.refreshRecordingInputs()),
              prefix: const Icon(FLucideIcons.refreshCcw),
              child: const Text('重新扫描麦克风'),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PreferenceTile extends StatelessWidget with FTileMixin {
  const _PreferenceTile({
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onPress,
    super.key,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: FTile(
        selected: selected,
        semanticsLabel: '$label，$detail',
        prefix: Icon(icon),
        title: Text(label),
        subtitle: Text(detail),
        suffix: selected
            ? const ExcludeSemantics(child: Icon(FLucideIcons.check))
            : null,
        enabled: enabled,
        onPress: onPress,
      ),
    ),
  );
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
        _ModelResourceHeader(option: option),
        SizedBox(height: appStyle.spaceXs),
        Text(
          '${_languageLabel(descriptor.supportedLanguages)} · '
          '${_decimalMegabytes(descriptor.requiredBytes)}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        SizedBox(height: appStyle.spaceSm),
        Text(
          '版本 ${descriptor.version} · 自动识别语言'
          '${descriptor.useInverseTextNormalization ? ' · ITN 已开启' : ''}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        if (option.status == AsrModelUiStatus.installed &&
            onRepair != null) ...[
          SizedBox(height: appStyle.spaceMd),
          _ModelMaintenanceMenu(busy: busy, onRepair: onRepair!),
        ],
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

final class _ModelResourceHeader extends StatelessWidget {
  const _ModelResourceHeader({required this.option});

  final AsrModelOption option;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final name = Text(
      option.descriptor.displayName,
      key: const ValueKey('model-resource-name'),
      style: theme.typography.display.md,
    );
    final status = _ModelResourceStatus(option: option);
    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          name,
          SizedBox(height: appStyle.spaceXs),
          status,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: name),
        SizedBox(width: appStyle.spaceSm),
        status,
      ],
    );
  }
}

final class _ModelResourceStatus extends StatelessWidget {
  const _ModelResourceStatus({required this.option});

  final AsrModelOption option;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final failed =
        option.status == AsrModelUiStatus.failed ||
        option.status == AsrModelUiStatus.insufficientStorage;
    final color = failed
        ? theme.colors.foreground
        : theme.colors.mutedForeground;
    return Semantics(
      key: const ValueKey('model-resource-status'),
      container: true,
      label: '${option.statusLabel}，离线转录资源状态',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusIcon(option.status),
              size: theme.typography.body.sm.fontSize,
              color: color,
            ),
            SizedBox(width: theme.style.app.space2Xs),
            Text(
              option.statusLabel,
              style: theme.typography.body.sm.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _statusIcon(AsrModelUiStatus status) => switch (status) {
  AsrModelUiStatus.installed => FLucideIcons.circleCheck,
  AsrModelUiStatus.notInstalled => FLucideIcons.packageOpen,
  AsrModelUiStatus.downloading => FLucideIcons.download,
  AsrModelUiStatus.paused => FLucideIcons.circlePause,
  AsrModelUiStatus.updateAvailable => FLucideIcons.circleArrowUp,
  AsrModelUiStatus.failed ||
  AsrModelUiStatus.insufficientStorage => FLucideIcons.triangleAlert,
  AsrModelUiStatus.checking ||
  AsrModelUiStatus.verifying ||
  AsrModelUiStatus.deleting => FLucideIcons.loaderCircle,
};

final class _ModelMaintenanceMenu extends StatelessWidget {
  const _ModelMaintenanceMenu({required this.busy, required this.onRepair});

  final bool busy;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: appStyle.spaceXs),
        child: FPopoverMenu.tiles(
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
          builder: (context, controller, child) => FButton.raw(
            key: const ValueKey('model-maintenance-menu'),
            variant: FButtonVariant.ghost,
            size: FButtonSizeVariant.lg,
            semanticsLabel: '维护离线转录资源',
            onPress: busy ? null : () => unawaited(controller.toggle()),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: appStyle.minimumTouchTarget,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: appStyle.spaceSm),
                child: Row(
                  children: [
                    const Icon(FLucideIcons.refreshCcw),
                    SizedBox(width: appStyle.spaceSm),
                    const Expanded(child: Text('维护资源')),
                    SizedBox(width: appStyle.spaceSm),
                    const Icon(FLucideIcons.chevronRight),
                  ],
                ),
              ),
            ),
          ),
        ),
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
