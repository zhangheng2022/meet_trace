import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/theme/theme.dart';

void main() {
  test('浅色和深色主题提供完整语义颜色', () {
    final light = lightTheme.colors;
    final dark = darkTheme.colors;

    expect(light.background.toARGB32(), 0xFFF7F7F5);
    expect(light.foreground.toARGB32(), 0xFF111111);
    expect(light.primary.toARGB32(), 0xFF111111);
    expect(light.app.recording.toARGB32(), 0xFF111111);
    expect(light.app.warning.toARGB32(), 0xFF3F3F3C);
    expect(light.app.success.toARGB32(), 0xFF111111);
    expect(light.app.focusRing.toARGB32(), 0xFF111111);
    expect(light.app.borderStrong.toARGB32(), 0xFF8B8B85);

    expect(dark.background.toARGB32(), 0xFF0D0D0D);
    expect(dark.foreground.toARGB32(), 0xFFF4F4F1);
    expect(dark.primary.toARGB32(), 0xFFF4F4F1);
    expect(dark.app.recording.toARGB32(), 0xFFF4F4F1);
    expect(dark.app.warning.toARGB32(), 0xFFB7B7B0);
    expect(dark.app.success.toARGB32(), 0xFFF4F4F1);
    expect(dark.app.focusRing.toARGB32(), 0xFFF4F4F1);
    expect(dark.app.borderStrong.toARGB32(), 0xFF777772);
  });

  test('AppStyle 固定 4pt 间距、触控尺寸和响应式断点', () {
    const style = AppStyle();

    expect(
      [
        style.space2Xs,
        style.spaceXs,
        style.spaceSm,
        style.spaceMd,
        style.spaceLg,
        style.spaceXl,
        style.space2Xl,
      ],
      [4, 8, 12, 16, 24, 32, 48],
    );
    expect(style.minimumTouchTarget, 48);
    expect(style.controlHeight, 48);
    expect(style.mediumLayoutMinWidth, 600);
    expect(style.wideLayoutMinWidth, 840);
    expect(style.ultraWideLayoutMinWidth, 1024);
    expect(style.readingContentMaxWidth, 760);
    expect(style.wideContentMaxWidth, 1280);
    expect(style.ledgerTimeColumnWidth, 64);
    expect(style.factRailWidth, 280);
    expect(style.statusRailWidth, 3);
    expect(style.dividerWidth, 1);
    expect(style.strongBorderWidth, 2);
  });

  test('主题正文和语义色对比度达到设计门槛', () {
    final light = lightTheme.colors;
    final dark = darkTheme.colors;

    expect(
      _contrast(light.foreground, light.background),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(light.mutedForeground, light.background),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(light.primaryForeground, light.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(light.app.recordingForeground, light.app.recording),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(light.app.warningForeground, light.app.warning),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(light.app.successForeground, light.app.success),
      greaterThanOrEqualTo(4.5),
    );

    expect(
      _contrast(dark.foreground, dark.background),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(dark.mutedForeground, dark.background),
      greaterThanOrEqualTo(7),
    );
    expect(
      _contrast(dark.primaryForeground, dark.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(dark.app.recordingForeground, dark.app.recording),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(dark.app.warningForeground, dark.app.warning),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(dark.app.successForeground, dark.app.success),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
