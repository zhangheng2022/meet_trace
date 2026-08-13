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
    test('工作流使用不可变的 Action 完整提交 SHA', () async {
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
        RegExp(r'actions/checkout@[^\s]+')
            .allMatches(workflows)
            .map((match) => match.group(0))
            .toSet(),
        {
          'actions/checkout@'
              '3d3c42e5aac5ba805825da76410c181273ba90b1',
        },
      );
      expect(
        RegExp(r'actions/setup-java@[^\s]+')
            .allMatches(workflows)
            .map((match) => match.group(0))
            .toSet(),
        {
          'actions/setup-java@'
              'b6effb05e454b25005698d916606bdc6ffcbf961',
        },
      );
      expect(
        RegExp(r'uses:\s+[^@\s]+@([^\s]+)')
            .allMatches(workflows)
            .every(
              (match) => RegExp(r'^[0-9a-f]{40}$').hasMatch(match.group(1)!),
            ),
        isTrue,
      );
      expect(workflows, isNot(contains('runs-on: ubuntu-latest')));
      expect(workflows, isNot(contains('runs-on: macos-latest')));
      expect(workflows, contains('runs-on: ubuntu-24.04'));
      expect(workflows, contains('runs-on: macos-26'));
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

      final flutterSetupCount = RegExp(r'uses: subosito/flutter-action@[^\s]+')
          .allMatches(workflows)
          .length;
      final versionFileCount = RegExp(r'flutter-version-file: "\.fvmrc"')
          .allMatches(workflows)
          .length;
      final fvmConfig = jsonDecode(
        await File('.fvmrc').readAsString(),
      ) as Map<String, Object?>;

      expect(flutterSetupCount, greaterThan(0));
      expect(versionFileCount, flutterSetupCount);
      expect(fvmConfig['flutter'], '3.47.0');
      expect(workflows, isNot(contains('flutter-version:')));
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
      expect(workflow, contains('uses: ./.github/workflows/_flutter-core.yml'));
      final reusableQuality = await _workflow('_flutter-core.yml');
      expect(reusableQuality, contains('workflow_call:'));
      expect(reusableQuality, isNot(contains('workflow_dispatch:')));

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
      expect(
        android,
        contains(
          'uses: actions/attest@'
          '1e69f48acb82d1966a394da916b4c1698aa569d6',
        ),
      );
      expect(android, contains('"job": "android"'));
      expect(android, contains(r'if ($abis.Count -ne 1'));
      expect(android, isNot(contains('build/app/outputs/flutter-apk/*.apk')));
    });

    test('iOS job 只上传 TestFlight 且不向 GitHub 暴露 IPA', () async {
      final workflow = await _workflow('alpha-release.yml');
      final ios = _job(workflow, 'ios', 'publish');

      expect(ios, contains('environment: testflight'));
      expect(ios, contains('contents: read'));
      expect(
        ios,
        contains(
          'uses: actions/attest@'
          '1e69f48acb82d1966a394da916b4c1698aa569d6',
        ),
      );
      expect(
        ios,
        contains(
          'uses: ruby/setup-ruby@'
          '95ef2b042f9d7a56d8268cba8559e2842e2ad01b',
        ),
      );
      expect(ios, contains('run: bundle exec fastlane ios upload_testflight'));
      expect(await File('Gemfile').readAsString(), contains('2.238.0'));
      expect(
        await File('Gemfile.lock').readAsString(),
        contains('fastlane (2.238.0)'),
      );
      expect(ios, contains('"job": "ios"'));
      expect(ios, isNot(contains('gh release upload')));
      expect(ios, isNot(contains('build/ios/testflight/*.ipa')));
    });

    test('iOS 无签名检查只保留审计证据且不打包 IPA', () async {
      final workflow = await _workflow('quality.yml');
      final ios = _job(workflow, 'ios-unsigned', 'ci-gate');

      expect(ios, contains('Build Release app without code signing'));
      expect(ios, contains('Write unsigned app bundle metadata'));
      expect(ios, contains('unsigned-app-bundle'));
      expect(ios, isNot(contains('Package unsigned IPA')));
      expect(ios, isNot(contains('Payload/Runner.app')));
      expect(ios, isNot(contains('build/ios/unsigned/*.ipa')));
      expect(ios, isNot(contains('build/ios/unsigned/*.sha256')));
      expect(ios, isNot(contains('\n      - name: Analyze')));
      expect(ios, isNot(contains('\n      - name: Test')));
    });

    test('常规 CI 使用稳定 Gate 并按变更路径选择平台', () async {
      final workflow = await _workflow('quality.yml');
      final reusable = await _workflow('_flutter-core.yml');
      final classifier = await File('tool/ci/classify_changes.py')
          .readAsString();

      expect(workflow, contains('\n  classify:'));
      expect(workflow, contains('tool/ci/classify_changes.py'));
      expect(workflow, contains('\n  flutter-quality:'));
      expect(workflow, contains('\n  ios-unsigned:'));
      expect(workflow, contains('\n  ci-gate:'));
      expect(workflow, contains('name: CI Gate'));
      expect(workflow, contains('if: always()'));
      expect(
        workflow,
        contains('needs: [classify, flutter-quality, ios-unsigned]'),
      );
      expect(workflow, contains('uses: ./.github/workflows/_flutter-core.yml'));
      expect(workflow, isNot(contains('\n    paths:')));
      expect(workflow, isNot(contains('\n    paths-ignore:')));

      expect(reusable, contains('workflow_call:'));
      expect(reusable, contains('flutter pub get --enforce-lockfile'));
      expect(reusable, contains('dart format --output=none'));
      expect(reusable, contains('run: flutter analyze'));
      expect(reusable, contains('run: flutter test'));
      expect(reusable, contains('if: inputs.build_android'));

      expect(
        classifier,
        contains('cannot silently bypass platform validation'),
      );
      expect(classifier, contains('return {key: True for key in result}'));
    });

    test('正式双平台构建使用 Environment Secret 上传 Sentry 符号', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');
      final ios = _job(workflow, 'ios', 'publish');

      for (final job in [android, ios]) {
        expect(job, contains('SENTRY_AUTH_TOKEN:'));
        expect(job, contains(r'${{ secrets.SENTRY_AUTH_TOKEN }}'));
        expect(job, contains('dart run sentry_dart_plugin'));
        expect(job, contains(r'--sentry-define="release=$SENTRY_RELEASE"'));
        expect(job, contains(r'--sentry-define="dist=$SENTRY_DIST"'));
        expect(job, contains('SENTRY_RELEASE='));
        expect(job, contains('SENTRY_DIST='));
        expect(job, contains('failed after 3 attempts'));
      }

      final nonReleaseWorkflows = [
        await _workflow('quality.yml'),
        await _workflow('firebase-test-lab.yml'),
      ].join('\n');
      expect(nonReleaseWorkflows, isNot(contains('SENTRY_AUTH_TOKEN')));
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
      final decoded = jsonDecode(
        await File('docs/quality/alpha_release_input.json').readAsString(),
      ) as Map<String, Object?>;
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
