import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/ui/features/meetings/views/recording/widgets/recording_audio_waveform.dart';

void main() {
  test('波形过渡与 100 毫秒展示节拍一致', () {
    expect(
      recordingWaveformTransitionDuration,
      const Duration(milliseconds: 100),
    );
  });

  testWidgets('真实音量样本绘制波形并提供稳定辅助语义', (tester) async {
    await tester.pumpWidget(
      const Application(
        home: RecordingAudioWaveform(
          levels: [0, 0.2, 0.8, 0.4, 1],
          state: RecordingAudioWaveformState.live,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('recording-audio-waveform')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('recording-audio-waveform')))
          .height,
      52,
    );
    expect(find.byType(CustomPaint), findsOneWidget);
    expect(find.text('麦克风输入 · 实时反馈'), findsOneWidget);
    expect(find.bySemanticsLabel('麦克风输入波形，实时反馈'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('暂停时保留波形但切换为暂停语义', (tester) async {
    await tester.pumpWidget(
      const Application(
        home: RecordingAudioWaveform(
          levels: [0.2, 0.7],
          state: RecordingAudioWaveformState.paused,
        ),
      ),
    );

    expect(find.text('麦克风输入 · 已暂停'), findsOneWidget);
    expect(find.bySemanticsLabel('麦克风输入波形，录音已暂停'), findsOneWidget);
  });

  testWidgets('新音量从当前画面连续过渡且允许中途重新定向', (tester) async {
    final levels = ValueNotifier<List<double>>(<double>[0.1, 0.3]);
    addTearDown(levels.dispose);

    await tester.pumpWidget(
      Application(
        home: ValueListenableBuilder<List<double>>(
          valueListenable: levels,
          builder: (context, value, child) => RecordingAudioWaveform(
            levels: value,
            state: RecordingAudioWaveformState.live,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    levels.value = <double>[0.1, 0.3, 0.95];
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(milliseconds: 50));
    levels.value = <double>[0.1, 0.3, 0.95, 0.2];
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('新样本在一个展示周期内完成连续过渡', (tester) async {
    final levels = ValueNotifier<List<double>>(<double>[0.1]);
    addTearDown(levels.dispose);

    await tester.pumpWidget(
      Application(
        home: ValueListenableBuilder<List<double>>(
          valueListenable: levels,
          builder: (context, value, child) => RecordingAudioWaveform(
            levels: value,
            state: RecordingAudioWaveformState.live,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    levels.value = <double>[0.1, 0.9];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 99));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减弱动态时新样本立即生效且不启动持续动画', (tester) async {
    final levels = ValueNotifier<List<double>>(<double>[0.2]);
    addTearDown(levels.dispose);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      Application(
        home: ValueListenableBuilder<List<double>>(
          valueListenable: levels,
          builder: (context, value, child) => RecordingAudioWaveform(
            levels: value,
            state: RecordingAudioWaveformState.live,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    levels.value = <double>[0.2, 0.9];
    await tester.pump();
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
