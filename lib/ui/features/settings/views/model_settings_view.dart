// THESIS: 设置页是一张本地运行账本，让用户确认新会议默认值、离线资源和本机数据状态。
// OWN-WORLD: 连续分区、细规则线、对齐数值与按状态提升的维护操作，不使用卡片仪表盘。
// STORY: 先确认新会议使用什么，再核对资源是否可用，最后查看存储、隐私与诊断入口。
// FIRST VIEWPORT: 宽屏维持设置双栏，录音输入位于左栏会议默认与离线资源之间；紧凑宽度自然下排。
// FORM: 继承既有 Quiet Evidence Ledger 的窄范围扩展，不启动新的视觉世界或概念选型。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/app_theme.dart';
import '../../../../domain/models/app_language.dart';
import '../../../../domain/models/asr_model.dart';
import '../../../../domain/models/recording_input.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/ui_message_localizations.dart';
import '../../../../theme/theme.dart';
import '../../../core/asr_model_option.dart';
import '../../../core/app_back_icon.dart';
import '../../../core/app_dialog.dart';
import '../../../core/app_page_body.dart';
import '../../../core/app_responsive.dart';
import '../view_models/data_controls_view_model.dart';
import '../view_models/model_settings_view_model.dart';
import '../view_models/remote_diagnostics_settings_view_model.dart';
import '../view_models/theme_settings_view_model.dart';
import '../view_models/language_settings_view_model.dart';

final class ModelSettingsView extends StatefulWidget {
  const ModelSettingsView({
    required this.viewModel,
    this.dataControls,
    this.themeSettings,
    this.languageSettings,
    this.remoteDiagnostics,
    this.onBack,
    super.key,
  });

  final ModelSettingsViewModel viewModel;
  final DataControlsViewModel? dataControls;
  final ThemeSettingsViewModel? themeSettings;
  final LanguageSettingsViewModel? languageSettings;
  final RemoteDiagnosticsSettingsViewModel? remoteDiagnostics;
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
    unawaited(widget.remoteDiagnostics?.load());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => FScaffold(
        childPad: false,
        header: widget.onBack == null
            ? FHeader(title: Text(context.l10n.settingsTitle))
            : FHeader.nested(
                title: Text(context.l10n.settingsTitle),
                prefixes: [
                  FHeaderAction(
                    icon: AppBackIcon(
                      semanticsLabel: context.l10n.backToMeetings,
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
    final l10n = context.l10n;
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
        if (widget.languageSettings case final languageSettings?) ...[
          ListenableBuilder(
            listenable: languageSettings,
            builder: (context, _) => _LanguageSection(
              viewModel: languageSettings,
              topRule: widget.themeSettings != null,
            ),
          ),
          SizedBox(height: appStyle.spaceXl),
        ],
        if (viewModel.errorMessage case final message?) ...[
          FAlert(
            variant: FAlertVariant.destructive,
            title: Text(l10n.modelSettingsIncomplete),
            subtitle: Text(l10n.localizeUiMessage(message)),
          ),
          SizedBox(height: appStyle.spaceLg),
        ],
        _MeetingDefaultsSection(
          descriptor: descriptor,
          loading: viewModel.isLoading,
          topRule:
              widget.themeSettings != null || widget.languageSettings != null,
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
            if (dataControls == null && widget.remoteDiagnostics == null) {
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
              listenable: Listenable.merge([
                ?dataControls,
                ?widget.remoteDiagnostics,
              ]),
              builder: (context, _) => _DataLedger(
                viewModel: dataControls,
                remoteDiagnostics: widget.remoteDiagnostics,
              ),
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

final class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.viewModel, required this.topRule});

  final LanguageSettingsViewModel viewModel;
  final bool topRule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    return _SettingsSection(
      key: const ValueKey('language-section'),
      title: l10n.languageSectionTitle,
      topRule: topRule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.saveFailed) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: Text(l10n.languageSaveFailedTitle),
              subtitle: Text(l10n.languageSaveFailedMessage),
            ),
            SizedBox(height: appStyle.spaceMd),
          ],
          FTileGroup(
            semanticsLabel: l10n.languageOptionsSemantics,
            children: [
              for (final mode in AppLanguageMode.values)
                _PreferenceTile(
                  key: ValueKey('language-mode-${mode.name}'),
                  label: switch (mode) {
                    AppLanguageMode.system => l10n.languageSystem,
                    AppLanguageMode.simplifiedChinese =>
                      l10n.languageSimplifiedChinese,
                    AppLanguageMode.english => l10n.languageEnglish,
                  },
                  detail: switch (mode) {
                    AppLanguageMode.system => l10n.languageSystemDescription,
                    AppLanguageMode.simplifiedChinese =>
                      l10n.languageSimplifiedChineseDescription,
                    AppLanguageMode.english => l10n.languageEnglishDescription,
                  },
                  icon: switch (mode) {
                    AppLanguageMode.system => FLucideIcons.languages,
                    AppLanguageMode.simplifiedChinese ||
                    AppLanguageMode.english => FLucideIcons.text,
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

final class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.viewModel});

  final ThemeSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    return _SettingsSection(
      key: const ValueKey('appearance-section'),
      title: l10n.appearanceSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.errorMessage case final message?) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: Text(l10n.themeSaveFailedTitle),
              subtitle: Text(l10n.localizeUiMessage(message)),
            ),
            SizedBox(height: appStyle.spaceMd),
          ],
          FTileGroup(
            semanticsLabel: l10n.themeOptionsSemantics,
            children: [
              for (final mode in AppThemeMode.values)
                _PreferenceTile(
                  key: ValueKey('theme-mode-${mode.name}'),
                  label: switch (mode) {
                    AppThemeMode.system => l10n.themeSystem,
                    AppThemeMode.light => l10n.themeLight,
                    AppThemeMode.dark => l10n.themeDark,
                  },
                  detail: switch (mode) {
                    AppThemeMode.system => l10n.themeSystemDescription,
                    AppThemeMode.light => l10n.themeLightDescription,
                    AppThemeMode.dark => l10n.themeDarkDescription,
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
    final l10n = context.l10n;
    return _SettingsSection(
      key: const ValueKey('meeting-defaults-section'),
      title: l10n.meetingDefaultsTitle,
      topRule: topRule,
      child: _SettingsValueRow(
        key: const ValueKey('default-transcription-model'),
        label: l10n.newMeetingTranscriptionModel,
        value: loading ? l10n.reading : descriptor.displayName,
        description: l10n.modelLockDescription,
      ),
    );
  }
}

final class _RecordingInputSection extends StatelessWidget {
  const _RecordingInputSection({required this.viewModel});

  final ModelSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    final preference = viewModel.recordingInputPreference;
    final missingSelectedDevice =
        preference != null && !viewModel.selectedRecordingInputAvailable;
    final devices = viewModel.recordingInputOptions;
    return _SettingsSection(
      key: const ValueKey('recording-input-section'),
      title: l10n.recordingInputTitle,
      topRule: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.recordingInputDescription,
            style: context.theme.typography.body.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          SizedBox(height: appStyle.spaceMd),
          if (viewModel.recordingInputErrorMessage case final message?) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: Text(l10n.microphoneSettingsIncomplete),
              subtitle: Text(l10n.localizeUiMessage(message)),
            ),
            SizedBox(height: appStyle.spaceMd),
          ],
          if (preference == null) ...[
            if (viewModel.recordingInputsLoading)
              FProgress(semanticsLabel: l10n.readingWindowsMicrophones),
          ] else ...[
            FTileGroup(
              semanticsLabel: l10n.windowsRecordingDevices,
              children: [
                _PreferenceTile(
                  key: const ValueKey('recording-input-system-default'),
                  label: l10n.systemDefaultMicrophone,
                  detail: l10n.systemDefaultMicrophoneDescription,
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
                    detail: l10n.microphoneUnavailable,
                    selected: true,
                    enabled: false,
                    onPress: null,
                    icon: FLucideIcons.mic,
                  ),
                for (final device in devices)
                  _PreferenceTile(
                    key: ValueKey('recording-input-${device.id}'),
                    label: device.label,
                    detail: l10n.windowsInputDevice,
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
                l10n.noOtherMicrophones,
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
            if (viewModel.recordingInputsLoading) ...[
              SizedBox(height: appStyle.spaceSm),
              FProgress(semanticsLabel: l10n.rescanningWindowsMicrophones),
            ],
          ],
          if (viewModel.recordingInputStatusMessage case final status?) ...[
            SizedBox(height: appStyle.spaceSm),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.localizeUiMessage(status),
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
              child: Text(l10n.rescanMicrophones),
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
        semanticsLabel: '$label${context.l10n.semanticListSeparator}$detail',
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
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    return _SettingsSection(
      key: const ValueKey('offline-resources-section'),
      title: l10n.offlineResourcesTitle,
      topRule: true,
      child: option == null
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: appStyle.spaceSm),
              child: loading
                  ? FProgress(semanticsLabel: l10n.readingOfflineResources)
                  : Text(l10n.noOfflineResources),
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
    final l10n = context.l10n;
    final theme = context.theme;
    final appStyle = theme.style.app;
    final descriptor = option.descriptor;
    final action = _prominentAction(context);
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
          '${_languageLabel(l10n, descriptor.supportedLanguages)} · '
          '${_decimalMegabytes(descriptor.requiredBytes)}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        SizedBox(height: appStyle.spaceSm),
        Text(
          l10n.modelVersionAutoLanguage(
            descriptor.version,
            descriptor.useInverseTextNormalization ? l10n.itnEnabledSuffix : '',
          ),
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
            FProgress(
              semanticsLabel: l10n.offlineResourceProgress(
                _statusLabel(l10n, option.status),
              ),
            )
          else
            Align(alignment: Alignment.centerLeft, child: action!),
        ],
      ],
    );
  }

  Widget? _prominentAction(BuildContext context) {
    final l10n = context.l10n;
    return switch (option.status) {
      AsrModelUiStatus.notInstalled =>
        onRepair == null
            ? null
            : FButton(
                key: const ValueKey('repair-model-resource'),
                onPress: busy ? null : onRepair,
                child: Text(l10n.downloadAndRepair),
              ),
      AsrModelUiStatus.downloading =>
        onPause == null
            ? null
            : FButton(
                key: const ValueKey('pause-model-download'),
                variant: FButtonVariant.outline,
                onPress: onPause,
                child: Text(l10n.pauseDownload),
              ),
      AsrModelUiStatus.paused ||
      AsrModelUiStatus.failed ||
      AsrModelUiStatus.insufficientStorage =>
        onRepair == null
            ? null
            : FButton(
                key: const ValueKey('repair-model-resource'),
                onPress: busy ? null : onRepair,
                child: Text(l10n.continueOrRetry),
              ),
      AsrModelUiStatus.updateAvailable =>
        onRepair == null
            ? null
            : FButton(
                key: const ValueKey('repair-model-resource'),
                onPress: busy ? null : onRepair,
                child: Text(l10n.verifyAndUpdate),
              ),
      AsrModelUiStatus.installed ||
      AsrModelUiStatus.checking ||
      AsrModelUiStatus.verifying ||
      AsrModelUiStatus.deleting => null,
    };
  }
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
    final l10n = context.l10n;
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
      label: l10n.offlineResourceStatus(_statusLabel(l10n, option.status)),
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
              _statusLabel(l10n, option.status),
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
    final l10n = context.l10n;
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
          semanticsLabel: l10n.modelMaintenanceActions,
          menuBuilder: (context, controller, _) => [
            FTileGroup(
              children: [
                FTile(
                  key: const ValueKey('verify-and-repair-model'),
                  prefix: const Icon(FLucideIcons.refreshCcw),
                  title: Text(l10n.verifyAndRepair),
                  subtitle: Text(l10n.verifyAndRepairDescription),
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
            semanticsLabel: l10n.maintainOfflineResources,
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
                    Expanded(child: Text(l10n.maintainResources)),
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
  const _DataLedger({required this.viewModel, required this.remoteDiagnostics});

  final DataControlsViewModel? viewModel;
  final RemoteDiagnosticsSettingsViewModel? remoteDiagnostics;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel case final viewModel?) ...[
          _StoragePrivacySection(viewModel: viewModel),
          SizedBox(height: appStyle.spaceXl),
        ],
        if (remoteDiagnostics case final remoteDiagnostics?) ...[
          _RemoteDiagnosticsSection(viewModel: remoteDiagnostics),
          if (viewModel != null) SizedBox(height: appStyle.spaceXl),
        ],
        if (viewModel case final viewModel?)
          _DiagnosticsSection(viewModel: viewModel),
      ],
    );
  }
}

final class _RemoteDiagnosticsSection extends StatelessWidget {
  const _RemoteDiagnosticsSection({required this.viewModel});

  final RemoteDiagnosticsSettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SettingsSection(
      key: const ValueKey('remote-diagnostics-section'),
      title: l10n.remoteDiagnosticsTitle,
      child: FSwitch(
        key: const ValueKey('remote-diagnostics-switch'),
        leadingLabel: true,
        value: viewModel.enabled,
        enabled: !viewModel.isLoading && !viewModel.isBusy,
        semanticsLabel: l10n.remoteDiagnosticsEnabled,
        label: Text(l10n.remoteDiagnosticsEnabled),
        description: Text(l10n.remoteDiagnosticsDescription),
        error: viewModel.saveFailed
            ? Text(l10n.remoteDiagnosticsSaveFailed)
            : null,
        onChange: (enabled) => unawaited(viewModel.setEnabled(enabled)),
      ),
    );
  }
}

final class _StoragePrivacySection extends StatelessWidget {
  const _StoragePrivacySection({required this.viewModel});

  final DataControlsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    final usage = viewModel.usage;
    return _SettingsSection(
      key: const ValueKey('storage-privacy-section'),
      title: l10n.storagePrivacyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (viewModel.isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: appStyle.spaceSm),
              child: FProgress(semanticsLabel: l10n.readingLocalStorage),
            )
          else if (usage == null) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              title: Text(l10n.storageReadFailed),
              subtitle: Text(l10n.storageUnchangedRetry),
            ),
            SizedBox(height: appStyle.spaceMd),
            FButton(
              key: const ValueKey('retry-storage-usage'),
              variant: FButtonVariant.outline,
              onPress: () => unawaited(viewModel.load()),
              child: Text(l10n.readAgain),
            ),
          ] else ...[
            _StorageMetricRow(
              key: const ValueKey('storage-total'),
              label: l10n.storageAppTotal,
              value: _byteLabel(usage.totalBytes),
              emphasis: true,
            ),
            _StorageMetricRow(
              label: l10n.storageMeetings,
              value: _byteLabel(usage.meetingBytes),
            ),
            _StorageMetricRow(
              label: l10n.storageModels,
              value: _byteLabel(usage.modelBytes),
            ),
            _StorageMetricRow(
              label: l10n.storageDatabase,
              value: _byteLabel(usage.databaseBytes),
            ),
            _StorageMetricRow(
              label: l10n.storageDeviceAvailable,
              value: _byteLabel(usage.freeBytes),
            ),
          ],
          SizedBox(height: appStyle.spaceMd),
          Text(
            l10n.localStoragePrivacyDescription,
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
    final l10n = context.l10n;
    final appStyle = context.theme.style.app;
    final message = viewModel.usage == null ? null : viewModel.message;
    return _SettingsSection(
      key: const ValueKey('diagnostics-section'),
      title: l10n.diagnosticsTitle,
      topRule: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FTileGroup(
            children: [
              FTile(
                key: const ValueKey('export-diagnostics'),
                prefix: const Icon(FLucideIcons.fileJson2),
                title: Text(l10n.viewShareDiagnostics),
                subtitle: Text(l10n.diagnosticsContents),
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
              title: Text(l10n.localizeUiMessage(message)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmExport(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      semanticsLabel: context.l10n.confirmShareDiagnostics,
      title: context.l10n.shareDiagnosticsQuestion,
      message: context.l10n.diagnosticsPrivacy,
      cancelLabel: context.l10n.cancel,
      confirmLabel: context.l10n.viewAndShare,
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

String _languageLabel(AppLocalizations l10n, List<String> languages) {
  final labels = {
    'zh': l10n.languageChineseShort,
    'yue': l10n.languageCantoneseShort,
    'en': l10n.languageEnglishShort,
    'ja': l10n.languageJapaneseShort,
    'ko': l10n.languageKoreanShort,
  };
  return languages
      .map((language) => labels[language] ?? language)
      .join(l10n.modelLanguageSeparator);
}

String _statusLabel(AppLocalizations l10n, AsrModelUiStatus status) =>
    switch (status) {
      AsrModelUiStatus.notInstalled => l10n.modelStatusNotDownloaded,
      AsrModelUiStatus.checking => l10n.modelStatusChecking,
      AsrModelUiStatus.downloading => l10n.modelStatusDownloading,
      AsrModelUiStatus.paused => l10n.modelStatusPaused,
      AsrModelUiStatus.verifying => l10n.modelStatusVerifying,
      AsrModelUiStatus.installed => l10n.modelStatusInstalled,
      AsrModelUiStatus.updateAvailable => l10n.modelStatusUpdateAvailable,
      AsrModelUiStatus.deleting => l10n.modelStatusDeleting,
      AsrModelUiStatus.failed => l10n.modelStatusDownloadFailed,
      AsrModelUiStatus.insufficientStorage => l10n.modelStatusInsufficientSpace,
    };

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
