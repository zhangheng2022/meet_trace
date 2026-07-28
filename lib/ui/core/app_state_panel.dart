// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
// Impeccable · component: state-panel · world: Evidence Ledger
// States: loading · empty · error · action-enabled · action-absent

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';
import 'app_status_notice.dart';

enum _AppStatePanelKind { loading, empty, error }

/// 页面级加载、空白和错误状态。
final class AppStatePanel extends StatelessWidget {
  const AppStatePanel.loading({required String label, super.key})
    : _kind = _AppStatePanelKind.loading,
      title = label,
      message = null,
      icon = null,
      actionLabel = null,
      onAction = null;

  const AppStatePanel.empty({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert((actionLabel == null) == (onAction == null), '操作文案和回调必须同时提供。'),
       _kind = _AppStatePanelKind.empty;

  const AppStatePanel.error({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert((actionLabel == null) == (onAction == null), '操作文案和回调必须同时提供。'),
       _kind = _AppStatePanelKind.error,
       icon = null;

  final _AppStatePanelKind _kind;
  final IconData? icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;

    if (_kind == _AppStatePanelKind.loading) {
      return Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: title,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FCircularProgress(
                  key: ValueKey('app-state-loading-progress'),
                  size: FCircularProgressSizeVariant.lg,
                ),
                SizedBox(width: appStyle.spaceSm),
                Text(
                  title,
                  style: theme.typography.body.md.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_kind == _AppStatePanelKind.error) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(appStyle.spaceMd),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppStatusNotice(
                  tone: AppStatusTone.error,
                  title: title,
                  message: message,
                ),
                if (onAction != null) ...[
                  SizedBox(height: appStyle.spaceMd),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FButton(
                      onPress: onAction,
                      mainAxisSize: MainAxisSize.min,
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(appStyle.spaceMd),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: title,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.card,
                      border: Border.all(
                        color: theme.colors.border,
                        width: appStyle.dividerWidth,
                      ),
                      borderRadius: BorderRadius.circular(appStyle.panelRadius),
                    ),
                    child: SizedBox.square(
                      dimension: appStyle.emptyIconSize,
                      child: Icon(
                        icon,
                        size: theme.typography.display.lg.fontSize,
                        color: theme.colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: appStyle.spaceLg),
              Text(
                title,
                style: theme.typography.display.lg,
                textAlign: TextAlign.center,
              ),
              if (message case final message?) ...[
                SizedBox(height: appStyle.spaceSm),
                Text(
                  message,
                  style: theme.typography.body.md.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (onAction != null) ...[
                SizedBox(height: appStyle.spaceLg),
                FButton(
                  onPress: onAction,
                  mainAxisSize: MainAxisSize.min,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
