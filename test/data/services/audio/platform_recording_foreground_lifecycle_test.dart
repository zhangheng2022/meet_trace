import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/flutter_foreground_recording_lifecycle.dart';
import 'package:meettrace/data/services/audio/platform_recording_foreground_lifecycle.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';

void main() {
  test('Android 使用麦克风前台服务生命周期', () {
    final lifecycle = createRecordingForegroundLifecycle(
      platform: RecordingPlatform.android,
    );

    expect(lifecycle, isA<FlutterForegroundRecordingLifecycle>());
  });

  test('iOS 由音频后台模式承载，不启动 Android 前台服务', () {
    final lifecycle = createRecordingForegroundLifecycle(
      platform: RecordingPlatform.ios,
    );

    expect(lifecycle, isA<NoopRecordingForegroundLifecycle>());
  });

  test('Windows 开发预览不启动 Android 前台服务', () {
    final lifecycle = createRecordingForegroundLifecycle(
      platform: RecordingPlatform.windows,
    );

    expect(lifecycle, isA<NoopRecordingForegroundLifecycle>());
  });
}
