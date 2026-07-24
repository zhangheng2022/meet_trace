import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:meetily_ai/app/application.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/ui/features/meetings/views/locked_recording_model_view.dart';

void main() {
  testWidgets('录音态只显示锁定模型且没有切换入口', (tester) async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;

    await tester.pumpWidget(
      Application(
        home: FScaffold(
          child: LockedRecordingModelView(
            descriptor: descriptor,
            modelVersion: descriptor.version,
          ),
        ),
      ),
    );

    expect(find.text('本场转录模型'), findsOneWidget);
    expect(find.text(descriptor.displayName), findsOneWidget);
    expect(find.text('已锁定'), findsOneWidget);
    expect(find.textContaining('切换'), findsNothing);
    expect(find.byType(FRadio), findsNothing);
  });
}
