import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String> _workflow(String name) =>
    File('.github/workflows/$name').readAsString();

String _job(String workflow, String job, [String? nextJob]) {
  final start = workflow.indexOf('\n  $job:');
  final end = nextJob == null
      ? workflow.length
      : workflow.indexOf('\n  $nextJob:', start + 1);
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return workflow.substring(start, end);
}

void main() {
  group('GitHub Alpha 发布守卫', () {
    test('工作流使用当前稳定的官方 Action 主版本', () async {
      final workflowFiles = await Directory('.github/workflows')
          .list()
          .where(
            (entry) =>
                entry is File &&
                (entry.path.endsWith('.yml') || entry.path.endsWith('.yaml')),
          )
          .cast<File>()
          .toList();
      final workflows = (await Future.wait(
        workflowFiles.map((file) => file.readAsString()),
      )).join('\n');

      expect(
        RegExp(
          r'actions/checkout@[^\s]+',
        ).allMatches(workflows).map((match) => match.group(0)).toSet(),
        {'actions/checkout@v7'},
      );
      expect(
        RegExp(
          r'actions/setup-java@[^\s]+',
        ).allMatches(workflows).map((match) => match.group(0)).toSet(),
        {'actions/setup-java@v5'},
      );
    });

    test('所有 Flutter 工作流固定到已验证的工具链版本', () async {
      final workflowFiles = await Directory('.github/workflows')
          .list()
          .where(
            (entry) =>
                entry is File &&
                (entry.path.endsWith('.yml') || entry.path.endsWith('.yaml')),
          )
          .cast<File>()
          .toList();
      final workflows = (await Future.wait(
        workflowFiles.map((file) => file.readAsString()),
      )).join('\n');

      final flutterSetupCount = RegExp(
        r'uses: subosito/flutter-action@[^\s]+',
      ).allMatches(workflows).length;
      final pinnedVersionCount = RegExp(
        r'flutter-version: "3\.44\.9"',
      ).allMatches(workflows).length;

      expect(flutterSetupCount, greaterThan(0));
      expect(pinnedVersionCount, flutterSetupCount);
      expect(workflows, isNot(contains('channel: stable')));
    });

    test('正式发布只保留一个 YML 和一个手动入口', () async {
      final workflow = await _workflow('alpha-release.yml');
      final obsoleteWorkflows = [
        'android-alpha.yml',
        'ios-testflight.yml',
        'finalize-release.yml',
      ];

      for (final name in obsoleteWorkflows) {
        expect(await File('.github/workflows/$name').exists(), isFalse);
      }
      expect(workflow, contains('name: Alpha Release'));
      expect(workflow, contains('workflow_dispatch:'));
      expect(workflow, contains('\n  android:'));
      expect(workflow, contains('\n  ios:'));
      expect(workflow, contains('\n  publish:'));
      expect(workflow, isNot(contains('uses: ./.github/workflows/')));

      final dispatchInputs = workflow.substring(
        workflow.indexOf('  workflow_dispatch:'),
        workflow.indexOf('\npermissions:'),
      );
      expect(
        RegExp(r'required: true').allMatches(dispatchInputs),
        hasLength(1),
      );
      expect(workflow, isNot(contains('expected_sha:')));
      expect(workflow, isNot(contains('gate_input_path:')));
    });

    test('产品质量记录不再作为自动发布门禁', () async {
      final workflow = await _workflow('alpha-release.yml');

      expect(workflow, isNot(contains('alpha_release_input.json')));
      expect(workflow, isNot(contains('evaluate_alpha_release.dart')));
      expect(workflow, isNot(contains('gateDecision')));
      expect(workflow, isNot(contains('release-gate-report')));
    });

    test('Android 与 iOS 共享连续递增的发布构建号', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');
      final ios = _job(workflow, 'ios', 'publish');

      expect(
        workflow,
        contains(
          r'build_number: ${{ steps.build_number.outputs.build_number }}',
        ),
      );
      expect(workflow, contains('Allocate shared release build number'));
      expect(workflow, contains('gh api --paginate'));
      expect(workflow, contains('max_build_number + 1'));
      expect(workflow, contains('Reusing build number'));
      expect(
        RegExp(
          r'RELEASE_BUILD_NUMBER: \$\{\{ needs\.prepare\.outputs\.build_number \}\}',
        ).allMatches(workflow),
        hasLength(2),
      );
      expect(android, contains(r'ANDROID_BUILD_NUMBER=$RELEASE_BUILD_NUMBER'));
      expect(ios, contains(r'IOS_BUILD_NUMBER=$RELEASE_BUILD_NUMBER'));
      expect(workflow, contains('Android and iOS build numbers differ'));
      expect(
        workflow,
        contains('Existing Android and iOS build numbers differ'),
      );
      expect(workflow, isNot(contains('GITHUB_RUN_NUMBER * 100')));
    });

    test('Android job 仅构建 arm64 Draft 且支持恢复重试', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');

      expect(android, contains('environment: android-alpha'));
      expect(android, contains('--target-platform android-arm64'));
      expect(android, contains('--split-per-abi'));
      expect(
        android,
        contains('build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'),
      );
      expect(android, contains(r'meettrace-${RELEASE_ID}-android-arm64.apk'));
      expect(android, contains(r'git tag -a "$RELEASE_ID"'));
      expect(android, contains(r'.isDraft <<<"$release_json")" == true'));
      expect(android, contains('--draft --prerelease'));
      expect(android, contains('--clobber'));
      expect(android, contains('ANDROID_SIGNING_CERT_SHA256'));
      expect(android, contains(r'^.*certificate SHA-256 digest:'));
      expect(android, isNot(contains(r'^Signer #1 certificate SHA-256')));
      expect(android, contains('uses: actions/attest@v4'));
      expect(android, contains('"job": "android"'));
      expect(android, contains(r'if ($abis.Count -ne 1'));
      expect(android, isNot(contains('build/app/outputs/flutter-apk/*.apk')));
    });

    test('iOS job 只上传 TestFlight 且不向 GitHub 暴露 IPA', () async {
      final workflow = await _workflow('alpha-release.yml');
      final ios = _job(workflow, 'ios', 'publish');

      expect(ios, contains('environment: testflight'));
      expect(ios, contains('contents: read'));
      expect(ios, contains('uses: actions/attest@v4'));
      expect(ios, contains('run: fastlane ios upload_testflight'));
      expect(ios, contains('"job": "ios"'));
      expect(ios, isNot(contains('gh release upload')));
      expect(ios, isNot(contains('build/ios/testflight/*.ipa')));
    });

    test('publish job 是唯一公开批准且支持不重建地后补链接', () async {
      final workflow = await _workflow('alpha-release.yml');
      final publish = _job(workflow, 'publish');

      expect(publish, contains('environment: github-release'));
      expect(publish, contains("needs.prepare.outputs.mode == 'candidate'"));
      expect(publish, contains("needs.prepare.outputs.mode == 'metadata'"));
      expect(publish, contains('android-candidate-manifest.json'));
      expect(publish, contains('ios-candidate-manifest.json'));
      expect(publish, contains('https://testflight\\.apple\\.com/join/'));
      expect(publish, contains('iOS TestFlight 外部测试链接：待提供'));
      expect(publish, contains('Staged Android APK digest changed'));
      expect(publish, contains('Existing public Android APK changed'));
      expect(publish, contains('endswith(".ipa")'));
      expect(publish, contains('--draft=false --prerelease'));
      expect(publish, isNot(contains('gh release create')));
      expect(publish, isNot(contains('git tag -a')));
      expect(
        publish.indexOf('Staged Android APK digest changed'),
        lessThan(publish.indexOf('--draft=false --prerelease')),
      );
    });

    test('原质量记录工具继续保留为非阻断记录', () async {
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
      expect(
        await File('tool/benchmarks/evaluate_alpha_release.dart').exists(),
        isTrue,
      );
    });
  });
}
