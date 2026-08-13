import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

/// 使用应用主题令牌的可编辑文本框。
///
/// Forui 0.25.0 的 `FTextField` 会用 `MergeSemantics` 包裹 Material
/// `TextField`。Flutter 3.47 在动态插入该节点时可能触发 semantics 树断言
///（duobaseio/forui#808），因此在上游修复前集中使用这个 Material 能力缺口。
final class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final borderRadius = BorderRadius.circular(appStyle.cardRadius);
    final enabledBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: theme.colors.border,
        width: appStyle.dividerWidth,
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: theme.colors.foreground,
        style: theme.typography.body.md,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
          hintStyle: theme.typography.body.md.copyWith(
            color: theme.colors.mutedForeground,
          ),
          filled: true,
          fillColor: theme.colors.card,
          contentPadding: EdgeInsets.symmetric(
            horizontal: appStyle.spaceMd,
            vertical: appStyle.spaceSm,
          ),
          enabledBorder: enabledBorder,
          focusedBorder: enabledBorder.copyWith(
            borderSide: BorderSide(
              color: theme.colors.app.focusRing,
              width: appStyle.strongBorderWidth,
            ),
          ),
        ),
      ),
    );
  }
}
