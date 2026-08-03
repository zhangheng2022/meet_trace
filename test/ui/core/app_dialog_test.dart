import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/core/app_dialog.dart';

void main() {
  testWidgets('确认对话框统一返回取消与确认结果', (tester) async {
    bool? result;
    await tester.pumpWidget(
      Application(
        home: Builder(
          builder: (context) => FButton(
            onPress: () async {
              result = await showAppConfirmDialog(
                context: context,
                semanticsLabel: '删除确认',
                title: '永久删除？',
                message: '此操作无法撤销。',
                cancelLabel: '取消',
                confirmLabel: '永久删除',
                destructive: true,
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('此操作无法撤销。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('提示对话框使用统一单操作布局', (tester) async {
    await tester.pumpWidget(
      Application(
        home: Builder(
          builder: (context) => FButton(
            onPress: () => showAppAlertDialog(
              context: context,
              semanticsLabel: '启动失败',
              title: '无法开始会议',
              message: '请检查录音权限。',
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('无法开始会议'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('无法开始会议'), findsNothing);
  });
}
