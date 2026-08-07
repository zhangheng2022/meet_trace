import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('启动源图在不同平台画布上保持同一光学尺寸', () async {
    final expectations = <String, _ExpectedMetrics>{
      'assets/branding/splash/meettrace-splash.png': const _ExpectedMetrics(
        canvasWidth: 384,
        canvasHeight: 384,
        visibleWidth: 352,
        visibleHeight: 292,
      ),
      'assets/branding/splash/meettrace-splash-dark.png':
          const _ExpectedMetrics(
            canvasWidth: 384,
            canvasHeight: 384,
            visibleWidth: 352,
            visibleHeight: 292,
          ),
      'assets/branding/splash/meettrace-splash-android12.png':
          const _ExpectedMetrics(
            canvasWidth: 1152,
            canvasHeight: 1152,
            visibleWidth: 352,
            visibleHeight: 292,
          ),
      'assets/branding/splash/meettrace-splash-android12-dark.png':
          const _ExpectedMetrics(
            canvasWidth: 1152,
            canvasHeight: 1152,
            visibleWidth: 352,
            visibleHeight: 292,
          ),
    };

    final metricsByPath = <String, _PngMetrics>{};
    for (final entry in expectations.entries) {
      final metrics = await _readPngMetrics(entry.key);
      metricsByPath[entry.key] = metrics;
      expect(metrics.canvasWidth, entry.value.canvasWidth, reason: entry.key);
      expect(metrics.canvasHeight, entry.value.canvasHeight, reason: entry.key);
      expect(metrics.visibleWidth, entry.value.visibleWidth, reason: entry.key);
      expect(
        metrics.visibleHeight,
        entry.value.visibleHeight,
        reason: entry.key,
      );
      expect(metrics.horizontalCenterOffset.abs(), lessThanOrEqualTo(0.5));
      expect(metrics.verticalCenterOffset.abs(), lessThanOrEqualTo(1));
    }
    _expectMatchingAlphaWithinRounding(
      metricsByPath,
      'assets/branding/splash/meettrace-splash.png',
      'assets/branding/splash/meettrace-splash-dark.png',
    );
    _expectMatchingAlphaWithinRounding(
      metricsByPath,
      'assets/branding/splash/meettrace-splash-android12.png',
      'assets/branding/splash/meettrace-splash-android12-dark.png',
    );
  });

  test('Android 与 iOS 生成资源保持 88dp/pt 启动标志', () async {
    final expectations = <String, _ExpectedMetrics>{
      'android/app/src/main/res/drawable-mdpi/splash.png':
          const _ExpectedMetrics(
            canvasWidth: 96,
            canvasHeight: 96,
            visibleWidth: 88,
            visibleHeight: 74,
          ),
      'android/app/src/main/res/drawable-night-mdpi/splash.png':
          const _ExpectedMetrics(
            canvasWidth: 96,
            canvasHeight: 96,
            visibleWidth: 88,
            visibleHeight: 74,
          ),
      'android/app/src/main/res/drawable-mdpi/android12splash.png':
          const _ExpectedMetrics(
            canvasWidth: 288,
            canvasHeight: 288,
            visibleWidth: 88,
            visibleHeight: 74,
          ),
      'android/app/src/main/res/drawable-night-mdpi/android12splash.png':
          const _ExpectedMetrics(
            canvasWidth: 288,
            canvasHeight: 288,
            visibleWidth: 88,
            visibleHeight: 74,
          ),
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png':
          const _ExpectedMetrics(
            canvasWidth: 96,
            canvasHeight: 96,
            visibleWidth: 88,
            visibleHeight: 74,
          ),
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImageDark.png':
          const _ExpectedMetrics(
            canvasWidth: 96,
            canvasHeight: 96,
            visibleWidth: 88,
            visibleHeight: 74,
          ),
    };

    final metricsByPath = <String, _PngMetrics>{};
    for (final entry in expectations.entries) {
      final metrics = await _readPngMetrics(entry.key);
      metricsByPath[entry.key] = metrics;
      expect(metrics.canvasWidth, entry.value.canvasWidth, reason: entry.key);
      expect(metrics.canvasHeight, entry.value.canvasHeight, reason: entry.key);
      expect(metrics.visibleWidth, entry.value.visibleWidth, reason: entry.key);
      expect(
        metrics.visibleHeight,
        entry.value.visibleHeight,
        reason: entry.key,
      );
    }
    _expectMatchingAlphaWithinRounding(
      metricsByPath,
      'android/app/src/main/res/drawable-mdpi/splash.png',
      'android/app/src/main/res/drawable-night-mdpi/splash.png',
    );
    _expectMatchingAlphaWithinRounding(
      metricsByPath,
      'android/app/src/main/res/drawable-mdpi/android12splash.png',
      'android/app/src/main/res/drawable-night-mdpi/android12splash.png',
    );
    _expectMatchingAlphaWithinRounding(
      metricsByPath,
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImageDark.png',
    );
  });
}

void _expectMatchingAlphaWithinRounding(
  Map<String, _PngMetrics> metricsByPath,
  String lightPath,
  String darkPath,
) {
  final lightAlpha = metricsByPath[lightPath]!.alphaChannel;
  final darkAlpha = metricsByPath[darkPath]!.alphaChannel;
  expect(lightAlpha.length, darkAlpha.length, reason: '$lightPath 与 $darkPath');
  var maxDelta = 0;
  for (var index = 0; index < lightAlpha.length; index++) {
    final delta = (lightAlpha[index] - darkAlpha[index]).abs();
    if (delta > maxDelta) maxDelta = delta;
  }
  expect(
    maxDelta,
    lessThanOrEqualTo(1),
    reason: '$lightPath 与 $darkPath 的 Alpha 轮廓只能存在 1/255 的舍入差',
  );
}

Future<_PngMetrics> _readPngMetrics(String relativePath) async {
  final bytes = await File(relativePath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw StateError('无法读取 PNG 像素：$relativePath');
    }
    final pixels = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    var minX = image.width;
    var minY = image.height;
    var maxX = -1;
    var maxY = -1;
    final alphaChannel = Uint8List(image.width * image.height);
    for (var alphaIndex = 3; alphaIndex < pixels.length; alphaIndex += 4) {
      final alpha = pixels[alphaIndex];
      alphaChannel[alphaIndex ~/ 4] = alpha;
      if (alpha == 0) {
        continue;
      }
      final pixelIndex = alphaIndex ~/ 4;
      final x = pixelIndex % image.width;
      final y = pixelIndex ~/ image.width;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (maxX < 0 || maxY < 0) {
      throw StateError('PNG 没有可见像素：$relativePath');
    }
    return _PngMetrics(
      canvasWidth: image.width,
      canvasHeight: image.height,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      alphaChannel: alphaChannel,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

final class _ExpectedMetrics {
  const _ExpectedMetrics({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.visibleWidth,
    required this.visibleHeight,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int visibleWidth;
  final int visibleHeight;
}

final class _PngMetrics {
  const _PngMetrics({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.alphaChannel,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final Uint8List alphaChannel;

  int get visibleWidth => maxX - minX + 1;
  int get visibleHeight => maxY - minY + 1;
  double get horizontalCenterOffset =>
      ((minX + maxX) / 2) - ((canvasWidth - 1) / 2);
  double get verticalCenterOffset =>
      ((minY + maxY) / 2) - ((canvasHeight - 1) / 2);
}
