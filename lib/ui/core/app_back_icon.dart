import 'package:material_ui/material_ui.dart';

/// 使用 Flutter 的平台自适应返回图形：
/// Android 显示带箭杆返回箭头，iOS 显示系统习惯的返回尖括号。
final class AppBackIcon extends StatelessWidget {
  const AppBackIcon({required this.semanticsLabel, super.key});

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final icon = switch (Theme.of(context).platform) {
      TargetPlatform.iOS => Icons.arrow_back_ios_new,
      _ => Icons.arrow_back,
    };
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ExcludeSemantics(child: Icon(icon)),
    );
  }
}
