import 'package:flutter/services.dart';

const _transparentSystemBar = Color(0x00000000);

/// 让系统状态栏成为应用表面的延伸，同时保留可读的系统图标。
SystemUiOverlayStyle appSystemUiOverlayStyle(Brightness backgroundBrightness) {
  final base = backgroundBrightness == Brightness.light
      ? SystemUiOverlayStyle.dark
      : SystemUiOverlayStyle.light;

  return base.copyWith(
    statusBarColor: _transparentSystemBar,
    systemStatusBarContrastEnforced: false,
  );
}

/// 启用 Android 推荐的 edge-to-edge 窗口布局。
Future<void> enableAppEdgeToEdge() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
