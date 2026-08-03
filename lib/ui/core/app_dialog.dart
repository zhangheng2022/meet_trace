import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../theme/theme.dart';

Future<bool?> showAppConfirmDialog({
  required BuildContext context,
  required String semanticsLabel,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
  bool barrierDismissible = true,
  bool cancelAutofocus = false,
  bool confirmAutofocus = false,
  Key? confirmKey,
}) {
  return showFDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    useSafeArea: true,
    builder: (context, style, animation) => FDialog(
      animation: animation,
      semanticsLabel: semanticsLabel,
      builder: (context, style) => _AppDialogBody(
        title: title,
        message: message,
        titleStyle: style.titleTextStyle,
        actions: [
          FButton(
            variant: FButtonVariant.outline,
            size: FButtonSizeVariant.lg,
            autofocus: cancelAutofocus,
            onPress: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel, maxLines: 1),
          ),
          FButton(
            key: confirmKey,
            variant: destructive
                ? FButtonVariant.destructive
                : FButtonVariant.primary,
            size: FButtonSizeVariant.lg,
            autofocus: confirmAutofocus,
            onPress: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel, maxLines: 1),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAppAlertDialog({
  required BuildContext context,
  required String semanticsLabel,
  required String title,
  required String message,
  String actionLabel = '知道了',
}) {
  return showFDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (context, style, animation) => FDialog(
      animation: animation,
      semanticsLabel: semanticsLabel,
      builder: (context, style) => _AppDialogBody(
        title: title,
        message: message,
        titleStyle: style.titleTextStyle,
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

final class _AppDialogBody extends StatelessWidget {
  const _AppDialogBody({
    required this.title,
    required this.message,
    required this.titleStyle,
    required this.actions,
  });

  final String title;
  final String message;
  final TextStyle titleStyle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return Padding(
      padding: EdgeInsets.all(appStyle.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: titleStyle),
          SizedBox(height: appStyle.spaceSm),
          Text(message, style: context.theme.typography.body.md),
          SizedBox(height: appStyle.spaceLg),
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) SizedBox(height: appStyle.spaceSm),
            actions[index],
          ],
        ],
      ),
    );
  }
}
