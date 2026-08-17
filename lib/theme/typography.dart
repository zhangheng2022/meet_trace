part of 'theme.dart';

const _appFontFallback = <String>[
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI',
  'Noto Sans SC',
  'PingFang SC',
  'Roboto',
];

/// 事实账本字阶：系统字体、两档主要字重和稳定的数字排版。
FTypography _typography({required FColors colors, required bool touch}) =>
    FTypography(
      display: _display(colors: colors, touch: touch),
      body: _body(colors: colors, touch: touch),
    );

FTypeface _display({
  required FColors colors,
  required bool touch,
  String fontFamily = FTypeface.defaultFontFamily,
  List<String>? fontFamilyFallback,
}) {
  final fallback = fontFamilyFallback ?? _appFontFallback;
  final scale = touch ? 1.0 : 0.92;
  TextStyle style(
    double size,
    double height, {
    FontWeight weight = FontWeight.w600,
    double? letterSpacing,
  }) => TextStyle(
    color: colors.foreground,
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: size * scale,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    leadingDistribution: TextLeadingDistribution.even,
  );

  return FTypeface(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    xs3: style(10, 1.2, weight: FontWeight.w500),
    xs2: style(12, 1.25, weight: FontWeight.w500),
    xs: style(13, 1.35, weight: FontWeight.w500, letterSpacing: 0.1),
    sm: style(16, 1.35),
    md: style(18, 1.35, letterSpacing: -0.1),
    lg: style(20, 1.25, letterSpacing: -0.2),
    xl: style(22, 1.2, letterSpacing: -0.3),
    xl2: style(32, 1.1, letterSpacing: -0.8),
    xl3: style(40, 1, weight: FontWeight.w400, letterSpacing: -1.2),
    xl4: style(56, 1, weight: FontWeight.w400, letterSpacing: -1.8),
    xl5: style(64, 1, weight: FontWeight.w400, letterSpacing: -2),
    xl6: style(72, 1, weight: FontWeight.w400, letterSpacing: -2.2),
    xl7: style(80, 1, weight: FontWeight.w400, letterSpacing: -2.4),
    xl8: style(88, 1, weight: FontWeight.w400, letterSpacing: -2.6),
  );
}

FTypeface _body({
  required FColors colors,
  required bool touch,
  String fontFamily = FTypeface.defaultFontFamily,
  List<String>? fontFamilyFallback,
}) {
  final fallback = fontFamilyFallback ?? _appFontFallback;
  final scale = touch ? 1.0 : 0.92;
  TextStyle style(
    double size,
    double height, {
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
  }) => TextStyle(
    color: colors.foreground,
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    fontSize: size * scale,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    leadingDistribution: TextLeadingDistribution.even,
  );

  return FTypeface(
    fontFamily: fontFamily,
    fontFamilyFallback: fallback,
    xs3: style(10, 1.2, weight: FontWeight.w500),
    xs2: style(12, 1.3, weight: FontWeight.w500),
    xs: style(13, 1.35, weight: FontWeight.w500, letterSpacing: 0.1),
    sm: style(15, 1.5),
    md: style(16, 1.55),
    lg: style(18, 1.5),
    xl: style(20, 1.45, weight: FontWeight.w600),
    xl2: style(24, 1.35, weight: FontWeight.w600),
    xl3: style(32, 1.2, weight: FontWeight.w600, letterSpacing: -0.6),
    xl4: style(48, 1, letterSpacing: -1.5),
    xl5: style(56, 1, letterSpacing: -1.8),
    xl6: style(64, 1, letterSpacing: -2),
    xl7: style(72, 1, letterSpacing: -2.2),
    xl8: style(80, 1, letterSpacing: -2.4),
  );
}
