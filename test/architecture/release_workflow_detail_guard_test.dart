import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String> _workflow(String name) async => (await File(
  '.github/workflows/$name',
).readAsString()).replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _job(String workflow, String job, [String? nextJob]) {
  final start = workflow.indexOf('\n  $job:');
  final end = nextJob == null
      ? workflow.length
      : workflow.indexOf('\n  $nextJob:', start + 1);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing job $job');
  expect(end, greaterThan(start), reason: 'invalid boundary for job $job');
  return workflow.substring(start, end);
}

void main() {
  group('发布工具链与常规 CI 细节守卫', () {
    test('所有 Flutter 工作流使用统一锁定版本', () async {
      final files = await Directory('.github/workflows')
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.yml'))
          .cast<File>()
          .toList();
      final workflows = (await Future.wait(
        files.map((file) => file.readAsString()),
      )).join('\n');
      const flutterAction =
          'uses: axi92/flutter-action@'
          '36d2c2625bac6ea011cd7808d2a01bd8a7e5c766';
      final setupCount = flutterAction.allMatches(workflows).length;
      final versionFileCount = RegExp(r'flutter-version-file: "\.fvmrc"')
          .allMatches(workflows)
          .length;
      final fvm = jsonDecode(await File('.fvmrc').readAsString()) as Map;

      expect(setupCount, greaterThan(0));
      expect(versionFileCount, setupCount);
      expect(workflows, isNot(contains('subosito/flutter-action@')));
      expect(fvm['flutter'], '3.47.1');
      expect(workflows, isNot(contains('channel: stable')));
      expect(workflows, isNot(contains('runs-on: ubuntu-latest')));
      expect(workflows, isNot(contains('runs-on: macos-latest')));
    });

    test('CI 保留 iOS 无签名审计与不可分发 Windows 探针', () async {
      final workflow = await _workflow('quality.yml');
      final ios = _job(workflow, 'ios-unsigned', 'windows-msix-probe');
      final windows = _job(workflow, 'windows-msix-probe', 'ci-gate');

      expect(ios, contains('Build Release app without code signing'));
      expect(ios, contains('tool/benchmarks/inspect_ios_app.sh'));
      expect(ios, isNot(contains('Build Debug app without code signing')));
      expect(ios, isNot(contains('actions/upload-artifact')));
      expect(ios, isNot(contains('build/ios/unsigned/*.ipa')));
      expect(windows, contains('runs-on: windows-2025'));
      expect(windows, contains('flutter build windows --release'));
      expect(windows, contains("-Publisher 'CN=MeetTrace Development'"));
      expect(windows, contains('-DevelopmentProbe'));
      expect(windows, contains('Remove non-distributable MSIX probe'));
      expect(windows, isNot(contains('build/windows/msix/*.msix')));
      expect(workflow, contains('actions-lint'));
      expect(workflow, contains('tool/ci/classify_changes.py'));
      expect(workflow, isNot(contains('\n    paths-ignore:')));
    });

    test('CodeQL 继续保留既定分析边界', () async {
      final codeql = await _workflow('codeql.yml');
      final config = await File('.github/codeql/codeql-config.yml')
          .readAsString();

      expect(
        codeql,
        contains('config-file: ./.github/codeql/codeql-config.yml'),
      );
      expect(codeql, contains('fail-fast: false'));
      expect(codeql, contains('- ruby'));
      expect(codeql, contains('name: CodeQL Gate'));
      expect(codeql, contains('needs: analyze'));
      expect(config, contains('- ".agents/**"'));
      expect(config, contains('- ".claude/**"'));
    });
  });

  group('Alpha 三平台候选细节守卫', () {
    test('共享构建号连续递增并映射到三平台真实版本', () async {
      final workflow = await _workflow('alpha-release.yml');
      final prepare = _job(workflow, 'prepare', 'quality');
      final android = _job(workflow, 'android', 'android_distribution');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'queue_reconciliation');

      expect(workflow, contains('build_number=2001'));
      expect(workflow, contains('max_build_number + 1'));
      expect(workflow, contains('Reusing build number'));
      expect(prepare, contains('contents: write'));
      expect(android, contains(r'ANDROID_BUILD_NUMBER=$RELEASE_BUILD_NUMBER'));
      expect(
        android,
        contains(
          r'ANDROID_PACKAGE_BUILD_NUMBER=$((RELEASE_BUILD_NUMBER - 2000))',
        ),
      );
      expect(
        android,
        contains('version_code != android_base_build_number + 2000'),
      );
      expect(ios, contains(r'IOS_BUILD_NUMBER=$RELEASE_BUILD_NUMBER'));
      expect(
        windows,
        contains(r'MEETTRACE_MSIX_VERSION=1.0.$($env:RELEASE_BUILD_NUMBER).0'),
      );
      expect(
        workflow,
        contains('Android, iOS, and Windows build numbers differ'),
      );
    });

    test('Android 候选固定 arm64、签名、Draft 与不可覆盖语义', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'android_distribution');

      expect(android, contains('environment: android-alpha'));
      expect(android, contains('--target-platform android-arm64'));
      expect(android, contains('--split-per-abi'));
      expect(android, contains('app-arm64-v8a-release.apk'));
      expect(android, contains(r'git tag -a "$RELEASE_ID"'));
      expect(android, contains('--draft --prerelease'));
      expect(android, contains('Reusing immutable staged Android candidate'));
      expect(android, contains('Refusing to overwrite assets'));
      expect(android, contains('ANDROID_SIGNING_CERT_SHA256'));
      expect(android, contains('actions/attest@'));
      expect(android, isNot(contains('--clobber')));
      expect(android, isNot(contains('build/app/outputs/flutter-apk/*.apk')));
    });

    test('iOS 仅上传 TestFlight 并支持复用不可变候选', () async {
      final workflow = await _workflow('alpha-release.yml');
      final ios = _job(workflow, 'ios', 'windows');
      final fastfile = await File('fastlane/Fastfile').readAsString();

      expect(ios, contains('environment: testflight'));
      expect(ios, contains('bundle exec fastlane ios upload_testflight'));
      expect(
        ios,
        contains(r'TESTFLIGHT_CHANGELOG: ${{ inputs.release_notes }}'),
      );
      expect(
        ios,
        contains(r'if [[ -z "${TESTFLIGHT_CHANGELOG//[[:space:]]/}" ]]'),
      );
      expect(
        ios,
        contains(r'export TESTFLIGHT_CHANGELOG="MeetTrace $RELEASE_ID"'),
      );
      expect(ios, contains('Reuse immutable uploaded TestFlight candidate'));
      expect(ios, contains(r'meettrace-ios-testflight-$source_run_id-'));
      expect(ios, contains("if: steps.staged.outputs.reuse != 'true'"));
      expect(ios, contains("if: steps.staged.outputs.reuse == 'true'"));
      expect(ios, isNot(contains('gh release upload')));
      expect(ios, isNot(contains('build/ios/testflight/*.ipa')));
      expect(fastfile, contains('ENV.fetch("TESTFLIGHT_CHANGELOG", "").strip'));
      expect(
        fastfile,
        contains(
          'changelog = "MeetTrace #{ENV.fetch("RELEASE_ID")}" '
          'if changelog.empty?',
        ),
      );
      expect(fastfile, contains('options[:changelog] = changelog'));
      expect(
        fastfile,
        isNot(
          contains('options[:changelog] = changelog unless changelog.empty?'),
        ),
      );
    });

    test('Windows 固定 Store 身份且 MSIX 只进入不可变 Artifact', () async {
      final workflow = await _workflow('alpha-release.yml');
      final windows = _job(workflow, 'windows', 'queue_reconciliation');

      expect(windows, contains('runs-on: windows-2025'));
      expect(windows, contains('environment: windows-alpha'));
      expect(windows, contains('Reuse immutable Microsoft Store candidate'));
      expect(windows, contains('Immutable Microsoft Store MSIX bytes changed'));
      expect(windows, contains('Build Windows x64 Store Release'));
      expect(windows, contains('-MicrosoftStore'));
      expect(windows, contains('zhangheng2026.MeetTrace'));
      expect(windows, contains('CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B'));
      expect(windows, contains('meettrace-windows-store-'));
      expect(windows, contains('build/windows/msix/*.msix'));
      expect(windows, isNot(contains('gh release upload')));
      expect(windows, isNot(contains('New-SelfSignedCertificate')));
    });

    test('Android 与 iOS 符号上传绑定 Environment Secret 和 release dist', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'android_distribution');
      final ios = _job(workflow, 'ios', 'windows');

      for (final job in <String>[android, ios]) {
        expect(job, contains(r'${{ secrets.SENTRY_AUTH_TOKEN }}'));
        expect(job, contains('dart run sentry_dart_plugin'));
        expect(job, contains(r'--sentry-define="release=$SENTRY_RELEASE"'));
        expect(job, contains(r'--sentry-define="dist=$SENTRY_DIST"'));
        expect(job, contains('failed after 3 attempts'));
      }
      expect(
        await _workflow('quality.yml'),
        isNot(contains('SENTRY_AUTH_TOKEN')),
      );
    });
  });

  group('最终公开与恢复细节守卫', () {
    test('完整门禁、公开 APK 复核和签名指针严格有序', () async {
      final workflow = await _workflow('alpha-release.yml');
      final publish = _job(workflow, 'publish');
      final gate = publish.indexOf('verify_release_orchestration_gate.dart');
      final pointerPreparation = publish.indexOf(
        'Prepare signed automatic-update pointer',
      );
      final releasePublication = publish.indexOf('--draft=false --prerelease');
      final publicApk = publish.indexOf(
        'Re-download and verify public Android APK',
      );
      final pointerPublication = publish.indexOf(
        'Atomically publish signed automatic-update pointer',
      );

      expect(gate, greaterThanOrEqualTo(0));
      expect(gate, lessThan(pointerPreparation));
      expect(pointerPreparation, lessThan(releasePublication));
      expect(releasePublication, lessThan(publicApk));
      expect(publicApk, lessThan(pointerPublication));
      expect(publish, contains('--android-artifact-sha256'));
      expect(publish, contains('endswith(".ipa")'));
      expect(publish, contains('endswith(".msix")'));
      expect(publish, isNot(contains('gh release create')));
      expect(publish, isNot(contains('gh release upload')));
    });

    test('Release 只保留 APK 和单一候选清单', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'android_distribution');
      final publish = _job(workflow, 'publish');
      final uploadStart = android.indexOf('          gh release upload');
      final uploadEnd = android.indexOf(
        r'            --repo "$GITHUB_REPOSITORY"',
        uploadStart,
      );
      expect(uploadStart, greaterThanOrEqualTo(0));
      expect(uploadEnd, greaterThan(uploadStart));
      final upload = android.substring(uploadStart, uploadEnd);

      expect(upload, contains(r'"$APK_PATH"'));
      expect(upload, contains('build/android/alpha/candidate-manifest.json'));
      expect(upload, isNot(contains('apksigner.txt')));
      expect(android, contains('apksigner.txt'));
      expect(publish, contains('Remove redundant Release evidence assets'));
    });

    test('协调器恢复只复用已验证候选而不重建', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'android_distribution');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'queue_reconciliation');
      final publish = _job(workflow, 'publish');

      expect(workflow, contains('resume_run_id:'));
      expect(workflow, contains('mode=resume'));
      for (final job in <String>[android, ios, windows]) {
        expect(job, contains("if: needs.prepare.outputs.mode == 'candidate'"));
      }
      expect(
        publish,
        contains('Download candidate evidence from the verified run'),
      );
      expect(publish, contains('.workflowName == "Alpha Release"'));
      expect(
        publish,
        contains('iOS candidate does not belong to the verified source run'),
      );
      expect(
        publish,
        contains(
          'Windows candidate does not belong to the verified source run',
        ),
      );
    });

    test('旧候选恢复使用已审查发布工具且候选事实保持不可变', () async {
      final workflow = await _workflow('alpha-release.yml');
      final publish = _job(workflow, 'publish');

      expect(publish, contains('Checkout reviewed release implementation'));
      expect(publish, contains(r'ref: ${{ github.workflow_sha }}'));
      expect(publish, contains(r'WORKFLOW_SHA: ${{ github.workflow_sha }}'));
      expect(publish, contains(r'git show "$CANDIDATE_SHA:pubspec.yaml"'));
      expect(
        publish,
        contains(
          r'$CANDIDATE_SHA:lib/data/services/storage/local_data_generation_gate.dart',
        ),
      );
      expect(publish, isNot(contains('Checkout immutable candidate')));
    });
  });
}
