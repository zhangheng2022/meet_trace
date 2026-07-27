import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS 声明麦克风用途和 audio 后台模式', () async {
    final plist = await File('ios/Runner/Info.plist').readAsString();

    expect(plist, contains('<key>NSMicrophoneUsageDescription</key>'));
    expect(plist, contains('会迹需要使用麦克风持续记录会议事实音频。'));
    expect(plist, contains('<key>UIBackgroundModes</key>'));
    expect(plist, contains('<string>audio</string>'));
    expect(plist, contains('<string>会迹</string>'));
  });
}
