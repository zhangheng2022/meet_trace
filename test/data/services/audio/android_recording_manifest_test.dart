import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 声明 microphone 前台服务且不包含自建原生桥接', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'),
    );
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(
      manifest,
      contains('com.pravera.flutter_foreground_task.service.ForegroundService'),
    );
    expect(manifest, contains('android:foregroundServiceType="microphone"'));
    expect(manifest, isNot(contains('MainActivity.kt')));
    expect(manifest, isNot(contains('System.loadLibrary')));
  });
}
