import 'dart:convert';
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
      expect(
        workflow,
        contains(
          'ALPHA_GATE_INPUT_PATH: docs/quality/alpha_release_input.json',
        ),
      );
      expect(workflow, contains(r'ref: ${{ inputs.release_id }}'));
      expect(workflow, contains(r'[[ "$GITHUB_REF" == "refs/heads/master" ]]'));
      expect(
        workflow.indexOf('name: Validate release identifier'),
        lessThan(workflow.indexOf('name: Checkout candidate commit')),
      );
      expect(workflow, contains(r'[[ "$tag_type" == "tag" ]]'));
      expect(workflow, contains('"commitSha": os.environ["CANDIDATE_SHA"]'));
      expect(workflow, isNot(contains('expected_sha:')));
      expect(workflow, isNot(contains('gate_input_path:')));
      expect(workflow, isNot(contains('build/ios/testflight/*.ipa')));
    });

    test('Android 仅构建 arm64 APK 并暂存到当前公开仓库 Draft Release', () async {
      final workflow = await File(
        '.github/workflows/android-alpha.yml',
      ).readAsString();

      expect(workflow, contains('environment: android-alpha'));
      expect(workflow, contains('contents: write'));
      expect(
        workflow,
        contains(
          'ALPHA_GATE_INPUT_PATH: docs/quality/alpha_release_input.json',
        ),
      );
      expect(workflow, contains(r'ref: ${{ github.sha }}'));
      expect(workflow, contains(r'[[ "$GITHUB_REF" == "refs/heads/master" ]]'));
      expect(workflow, isNot(contains('expected_sha:')));
      expect(workflow, isNot(contains('gate_input_path:')));
      expect(workflow, contains('--target-platform android-arm64'));
      expect(workflow, contains(r'meettrace-${RELEASE_ID}-android-arm64.apk'));
      expect(workflow, contains(r'[[ "$visibility" == "PUBLIC" ]]'));
      expect(workflow, contains('--draft --prerelease'));
      expect(workflow, contains(r'git tag -a "$RELEASE_ID"'));
      expect(workflow, contains(r'gh release create "$RELEASE_ID"'));
      expect(workflow, contains('--verify-tag'));
      expect(workflow, contains(r'--repo "$GITHUB_REPOSITORY"'));
      expect(workflow, contains('ANDROID_SIGNING_CERT_SHA256'));
      expect(workflow, contains('uses: actions/attest@v4'));
      expect(workflow, contains(r'if ($abis.Count -ne 1'));
      expect(workflow, isNot(contains('ANDROID_DISTRIBUTION_TOKEN')));
      expect(workflow, isNot(contains('ANDROID_DISTRIBUTION_REPOSITORY')));
      expect(workflow, isNot(contains('--clobber')));
      expect(workflow, isNot(contains('build/app/outputs/flutter-apk/*.apk')));
      expect(
        workflow.indexOf(r'git tag -a "$RELEASE_ID"'),
        lessThan(workflow.indexOf(r'gh release create "$RELEASE_ID"')),
      );
    });

    test('最终发布验证原 APK 后公开 Draft 并保留 TestFlight 外部链接', () async {
      final workflow = await File(
        '.github/workflows/finalize-release.yml',
      ).readAsString();

      expect(workflow, contains('environment: github-release'));
      expect(workflow, contains('android-candidate-manifest.json'));
      expect(workflow, contains('ios-candidate-manifest.json'));
      expect(workflow, contains('--prerelease'));
      expect(workflow, contains(r'[[ "$tag_type" == "tag" ]]'));
      expect(workflow, contains('RELEASE_IS_DRAFT'));
      expect(workflow, contains('ios_testflight_external_url:'));
      expect(workflow, contains('https://testflight\\.apple\\.com/join/'));
      expect(workflow, contains('iOS TestFlight 外部测试链接：待提供'));
      expect(workflow, contains('Android 7.0+'));
      expect(workflow, contains('安装未知应用'));
      expect(workflow, contains('无登录和云同步'));
      expect(workflow, contains('卸载应用会删除'));
      expect(workflow, contains('Alpha 升级可能清除旧数据'));
      expect(workflow, contains('约 286.3 MB'));
      expect(workflow, contains('已撤回，不建议安装'));
      expect(workflow, contains(r'gh release download "$RELEASE_ID"'));
      expect(workflow, contains('Android APK digest does not match'));
      expect(workflow, contains('Staged Android APK digest changed'));
      expect(workflow, contains('Existing public release evidence changed'));
      expect(workflow, contains(r'($sha == "" or .head_sha == $sha)'));
      expect(workflow, contains('--draft=false'));
      expect(workflow, isNot(contains('gh release create')));
      expect(workflow, isNot(contains('git tag -a')));
      expect(
        workflow.indexOf('Staged Android APK digest changed'),
        lessThan(workflow.indexOf('--draft=false')),
      );
      final assetsStart = workflow.indexOf('assets=(');
      final assetsEnd = workflow.indexOf('\n          )', assetsStart);
      final uploadedAssets = workflow.substring(assetsStart, assetsEnd);
      expect(uploadedAssets, isNot(contains('.apk')));
      expect(uploadedAssets, isNot(contains('.ipa')));
    });

    test('固定门禁输入使用 schema 4 和完整运行时下载总量', () async {
      final decoded =
          jsonDecode(
                await File(
                  'docs/quality/alpha_release_input.json',
                ).readAsString(),
              )
              as Map<String, Object?>;
      final senseVoice = decoded['senseVoice']! as Map<String, Object?>;

      expect(decoded['schemaVersion'], 4);
      expect(senseVoice['runtimeDownloadBytes'], 286314800);
      expect(decoded, contains('acceptanceEvidence'));
    });
  });
}
