import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 与 iOS 生产标识统一为 com.meettrace.app', () async {
    final gradle = await File('android/app/build.gradle.kts').readAsString();
    final activity = File(
      'android/app/src/main/kotlin/com/meettrace/app/MainActivity.kt',
    );
    final xcodeProject = await File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsString();

    expect(gradle, contains('namespace = "com.meettrace.app"'));
    expect(gradle, contains('applicationId = "com.meettrace.app"'));
    expect(await activity.exists(), true);
    expect(
      await activity.readAsString(),
      contains('package com.meettrace.app'),
    );
    expect(
      await File(
        'android/app/src/main/kotlin/com/example/meettrace/MainActivity.kt',
      ).exists(),
      false,
    );
    expect(
      RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = com\.meettrace\.app;')
          .allMatches(xcodeProject),
      hasLength(3),
    );
    expect(
      RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = com\.meettrace\.app\.RunnerTests;')
          .allMatches(xcodeProject),
      hasLength(3),
    );

    final nativeConfiguration = [
      gradle,
      await activity.readAsString(),
      xcodeProject,
    ].join('\n');
    expect(nativeConfiguration, isNot(contains('com.example.meettrace')));
  });

  test('Android Release 只接受显式注入的正式签名配置', () async {
    final gradle = await File('android/app/build.gradle.kts').readAsString();

    expect(
      gradle,
      contains('environmentVariable("MEETTRACE_ANDROID_KEYSTORE_PATH")'),
    );
    expect(gradle, contains('create("release")'));
    expect(gradle, contains('signingConfigs.findByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });
}
