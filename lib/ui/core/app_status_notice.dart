// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
// Hallmark · component: status-notice · genre: modern-minimal · theme: Cobalt
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
    final visual = _visual(theme);
    final baseStyle = theme.alertStyles.primary;

    return FAlert(
      liveRegion: liveRegion,
      icon: Icon(visual.icon),
      title: Text(title),
      subtitle: message == null ? null : Text(message!),
      style: baseStyle.copyWith(
        iconStyle: IconThemeDataDelta.delta(color: visual.color),
      ),
    );
  }

  _AppStatusVisual _visual(FThemeData theme) => switch (tone) {
    AppStatusTone.info => _AppStatusVisual(
      color: theme.colors.primary,
      icon: FLucideIcons.info,
    ),
    AppStatusTone.recording => _AppStatusVisual(
      color: theme.colors.app.recording,
      icon: FLucideIcons.radio,
    ),
    AppStatusTone.warning => _AppStatusVisual(
      color: theme.colors.app.warning,
      icon: FLucideIcons.triangleAlert,
    ),
    AppStatusTone.error => _AppStatusVisual(
      color: theme.colors.error,
      icon: FLucideIcons.circleAlert,
    ),
    AppStatusTone.success => _AppStatusVisual(
      color: theme.colors.app.success,
      icon: FLucideIcons.circleCheck,
    ),
  };
}

final class _AppStatusVisual {
  const _AppStatusVisual({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
