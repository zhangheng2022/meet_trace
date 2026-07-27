// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
// Impeccable · component: status-rail · world: Evidence Ledger
// States: info · recording · warning · error · success · contrast: token-locked

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 应用内持续反馈的语义类型。
enum AppStatusTone { info, recording, warning, error, success }

/// 使用文字、Lucide 图标和语义色共同表达状态。
///
/// 状态不依赖颜色单独传达；[title] 应直接说明发生了什么，[message] 应在需要时
/// 补充原因和下一步。
final class AppStatusNotice extends StatelessWidget {
  const AppStatusNotice({
    required this.tone,
    required this.title,
    this.message,
    this.liveRegion = true,
    super.key,
  });

  final AppStatusTone tone;
  final String title;
  final String? message;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final visual = _visual(theme);
    final borderWidth = tone == AppStatusTone.error
        ? appStyle.strongBorderWidth
        : appStyle.dividerWidth;

    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: message == null ? title : '$title。$message',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.card,
            border: Border.all(
              color: tone == AppStatusTone.error
                  ? theme.colors.foreground
                  : theme.colors.border,
              width: borderWidth,
            ),
            borderRadius: BorderRadius.circular(appStyle.cardRadius),
          ),
          child: Padding(
            padding: EdgeInsets.all(appStyle.spaceSm),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: appStyle.statusRailWidth,
                    decoration: BoxDecoration(
                      color: visual.color,
                      borderRadius: BorderRadius.circular(
                        appStyle.statusRailWidth,
                      ),
                    ),
                  ),
                  SizedBox(width: appStyle.spaceSm),
                  Padding(
                    padding: EdgeInsets.only(top: appStyle.space2Xs),
                    child: Icon(visual.icon, color: visual.color, size: 20),
                  ),
                  SizedBox(width: appStyle.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.typography.display.sm),
                        if (message case final message?) ...[
                          SizedBox(height: appStyle.space2Xs),
                          Text(
                            message,
                            style: theme.typography.body.sm.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _AppStatusVisual _visual(FThemeData theme) => switch (tone) {
    AppStatusTone.info => _AppStatusVisual(
      color: theme.colors.mutedForeground,
      icon: FLucideIcons.info,
    ),
    AppStatusTone.recording => _AppStatusVisual(
      color: theme.colors.app.recording,
      icon: FLucideIcons.radio,
    ),
    AppStatusTone.warning => _AppStatusVisual(
      color: theme.colors.app.borderStrong,
      icon: FLucideIcons.triangleAlert,
    ),
    AppStatusTone.error => _AppStatusVisual(
      color: theme.colors.foreground,
      icon: FLucideIcons.circleAlert,
    ),
    AppStatusTone.success => _AppStatusVisual(
      color: theme.colors.foreground,
      icon: FLucideIcons.circleCheck,
    ),
  };
}

final class _AppStatusVisual {
  const _AppStatusVisual({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
