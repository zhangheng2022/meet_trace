import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHub Alpha 发布守卫', () {
    test('公开仓库的 TestFlight Artifact 不上传签名 IPA', () async {
      final workflow = await File(
        '.github/workflows/ios-testflight.yml',
      ).readAsString();

      expect(workflow, contains('environment: testflight'));
      expect(workflow, contains('uses: actions/attest@v4'));
      expect(workflow, contains('gate_input_path:'));
      expect(workflow, isNot(contains('build/ios/testflight/*.ipa')));
    });

    test('Android 签名 APK 只进入经过可见性校验的私有仓库', () async {
      final workflow = await File(
        '.github/workflows/android-alpha.yml',
      ).readAsString();

      expect(workflow, contains('environment: android-alpha'));
      expect(workflow, contains(r'[[ "$visibility" == "PRIVATE" ]]'));
      expect(workflow, contains('ANDROID_SIGNING_CERT_SHA256'));
      expect(workflow, contains('uses: actions/attest@v4'));
      expect(workflow, isNot(contains('build/app/outputs/flutter-apk/*.apk')));
    });

    test('最终发布只附带双平台清单和门禁报告', () async {
      final workflow = await File(
        '.github/workflows/finalize-release.yml',
      ).readAsString();

      expect(workflow, contains('environment: github-release'));
      expect(workflow, contains('android-candidate-manifest.json'));
      expect(workflow, contains('ios-candidate-manifest.json'));
      expect(workflow, contains('--prerelease'));
      expect(workflow, contains('TAG_ALREADY_EXISTS'));
      expect(workflow, contains('RELEASE_ALREADY_EXISTS'));
      final createStart = workflow.indexOf('gh release create');
      final createEnd = workflow.indexOf('\n\n      - name:', createStart);
      final createCommand = workflow.substring(createStart, createEnd);
      expect(createCommand, isNot(contains('.apk')));
      expect(createCommand, isNot(contains('.ipa')));
    });
  });
}
