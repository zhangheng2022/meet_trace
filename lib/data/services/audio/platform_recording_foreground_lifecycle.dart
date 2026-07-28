import 'dart:io';

import 'flutter_foreground_recording_lifecycle.dart';
import 'recording_ports.dart';

enum RecordingPlatform { android, ios, windows }

RecordingForegroundLifecycle createRecordingForegroundLifecycle({
  RecordingPlatform? platform,
}) {
  final resolved = platform ?? _currentPlatform();
  return switch (resolved) {
    RecordingPlatform.android => FlutterForegroundRecordingLifecycle(),
    // iOS 的持续录音由 AVAudioSession 和 audio 后台模式承载，不启动 Android
    // foreground-task 语义。生命周期中断由 record 插件和录音协调器处理。
    RecordingPlatform.ios ||
    RecordingPlatform.windows => const NoopRecordingForegroundLifecycle(),
  };
}

RecordingPlatform _currentPlatform() {
  if (Platform.isAndroid) {
    return RecordingPlatform.android;
  }
  if (Platform.isIOS) {
    return RecordingPlatform.ios;
  }
  if (Platform.isWindows) {
    return RecordingPlatform.windows;
  }
  throw UnsupportedError('当前平台不支持会迹运行');
}
