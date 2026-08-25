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
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return workflow.substring(start, end);
}

String _step(String job, String step, String nextStep) {
  final start = job.indexOf('\n      - name: $step');
  final end = job.indexOf('\n      - name: $nextStep', start + 1);
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return job.substring(start, end);
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
      final storeRecovery = await _workflow(
        'microsoft-store-flight-recovery.yml',
      );
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
      expect(workflow, contains('\n  windows:'));
      expect(workflow, contains('\n  publish:'));
      expect(workflow, contains('uses: ./.github/workflows/_flutter-core.yml'));
      final reusableQuality = await _workflow('_flutter-core.yml');
      expect(reusableQuality, contains('workflow_call:'));
      expect(reusableQuality, isNot(contains('workflow_dispatch:')));
      expect(storeRecovery, isNot(contains('workflow_dispatch:')));
      expect(
        storeRecovery,
        contains('types: [microsoft-store-flight-recovery]'),
      );

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

    test('Android、iOS 与 Windows 共享连续递增的发布构建号', () async {
      final workflow = await _workflow('alpha-release.yml');
      final prepare = _job(workflow, 'prepare', 'quality');
      final android = _job(workflow, 'android', 'ios');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'windows_flight');

      expect(
        workflow,
        contains(
          r'build_number: ${{ steps.build_number.outputs.build_number }}',
        ),
      );
      expect(workflow, contains('Allocate shared release build number'));
      expect(workflow, contains('build_number=2001'));
      expect(workflow, contains('gh api --paginate'));
      expect(workflow, contains('max_build_number + 1'));
      expect(workflow, contains('Reusing build number'));
      expect(prepare, contains('contents: write'));
      expect(prepare, contains('Draft Releases hold reserved build numbers'));
      expect(
        RegExp(
          r'RELEASE_BUILD_NUMBER: \$\{\{ needs\.prepare\.outputs\.build_number \}\}',
        ).allMatches(workflow),
        hasLength(3),
      );
      expect(android, contains(r'ANDROID_BUILD_NUMBER=$RELEASE_BUILD_NUMBER'));
      expect(
        android,
        contains(
          r'ANDROID_PACKAGE_BUILD_NUMBER=$((RELEASE_BUILD_NUMBER - 2000))',
        ),
      );
      expect(
        android,
        contains(r'--build-number="$ANDROID_PACKAGE_BUILD_NUMBER"'),
      );
      expect(
        android,
        contains(
          r'--dart-define="MEETTRACE_BUILD_NUMBER=$ANDROID_BUILD_NUMBER"',
        ),
      );
      expect(ios, contains(r'IOS_BUILD_NUMBER=$RELEASE_BUILD_NUMBER'));
      expect(
        windows,
        contains(
          r'RELEASE_BUILD_NUMBER: ${{ needs.prepare.outputs.build_number }}',
        ),
      );
      expect(
        workflow,
        contains('Android, iOS, and Windows build numbers differ'),
      );
      expect(
        workflow,
        contains('version_code != int(os.environ["ANDROID_BUILD_NUMBER"])'),
      );
      expect(workflow, isNot(contains('GITHUB_RUN_NUMBER * 100')));
    });

    test('Android job 仅构建 arm64 Draft 且支持恢复重试', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');

      expect(android, contains('environment: android-alpha'));
      expect(android, contains('--target-platform android-arm64'));
      expect(android, contains('--split-per-abi'));
      expect(android, contains('"androidBaseBuildNumber"'));
      expect(android, contains('"versionCode"'));
      expect(
        android,
        contains('version_code != android_base_build_number + 2000'),
      );
      expect(
        android,
        contains('build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'),
      );
      expect(android, contains(r'meettrace-${RELEASE_ID}-android-arm64.apk'));
      expect(android, contains(r'git tag -a "$RELEASE_ID"'));
      expect(android, contains(r'.isDraft <<<"$release_json")" == true'));
      expect(android, contains('--draft --prerelease'));
      expect(android, contains('id: staged'));
      expect(android, contains('Reusing immutable staged Android candidate'));
      expect(android, contains(r'.artifact.sha256'));
      expect(android, contains('Existing draft candidate is incomplete'));
      expect(android, contains('Refusing to overwrite assets'));
      expect(android, isNot(contains('--clobber')));
      const freshCandidateSteps = [
        'Set up Java 17',
        'Set up Flutter 3.47.0',
        'Resolve locked dependencies',
        'Decode Android signing keystore',
        'Build signed Android Release APK',
        'Upload Android debug symbols to Sentry',
        'Inspect APK contents',
        'Verify APK signature and certificate',
        'Write Android candidate manifest',
        'Generate APK provenance attestation',
        "Stage APK in this repository's draft release",
      ];
      for (final step in freshCandidateSteps) {
        expect(
          android,
          contains(
            '      - name: $step\n'
            "        if: steps.staged.outputs.reuse != 'true'",
          ),
        );
      }
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
      final ios = _job(workflow, 'ios', 'windows');

      expect(ios, contains('environment: testflight'));
      expect(ios, contains('actions: read'));
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
      expect(ios, contains('bundle exec ruby -rxcodeproj'));
      expect(ios, contains('run: bundle exec fastlane ios upload_testflight'));
      final gemfile = await File('Gemfile').readAsString();
      expect(gemfile, contains('gem "fastlane", "2.238.0"'));
      expect(gemfile, contains('gem "xcodeproj", "1.28.1"'));
      expect(
        await File('Gemfile.lock').readAsString(),
        contains('fastlane (2.238.0)'),
      );
      expect(
        await File('Gemfile.lock').readAsString(),
        contains('xcodeproj (= 1.28.1)'),
      );
      expect(ios, contains('"job": "ios"'));
      expect(ios, isNot(contains('gh release upload')));
      expect(ios, isNot(contains('build/ios/testflight/*.ipa')));
    });

    test('iOS 恢复执行复用不可变 TestFlight 候选且不重复上传', () async {
      final workflow = await _workflow('alpha-release.yml');
      final ios = _job(workflow, 'ios', 'windows');

      expect(ios, contains('Reuse immutable uploaded TestFlight candidate'));
      expect(ios, contains('--limit 100'));
      expect(ios, contains(r'--arg candidate_sha "$CANDIDATE_SHA"'));
      expect(ios, contains(r'.commitSha == $candidate_sha'));
      expect(ios, contains(r'meettrace-ios-testflight-$source_run_id-'));
      expect(ios, contains(r'test("^[0-9a-f]{64}$")'));
      expect(ios, contains(r'.runId = $run_id'));
      expect(ios, contains(r'sourceArtifactId: $source_artifact_id'));
      expect(ios, contains("if: steps.staged.outputs.reuse != 'true'"));
      expect(
        ios,
        contains(
          "- name: Upload IPA to TestFlight\n"
          "        if: steps.staged.outputs.reuse != 'true'",
        ),
      );
      expect(ios, contains("if: steps.staged.outputs.reuse == 'true'"));
      expect(ios, contains('retention-days: 30'));
    });

    test('Windows 正式候选只进入 Microsoft Store Artifact', () async {
      final workflow = await _workflow('alpha-release.yml');
      final windows = _job(workflow, 'windows', 'windows_flight');

      expect(windows, contains('runs-on: windows-2025'));
      expect(windows, contains('environment: windows-alpha'));
      expect(windows, contains('actions: read'));
      expect(windows, contains('Reuse immutable Microsoft Store candidate'));
      expect(windows, contains('--workflow alpha-release.yml'));
      expect(windows, contains('Sort-Object -Property createdAt'));
      expect(windows, contains('PREFERRED_STORE_SOURCE_RUN_ID'));
      expect(windows, contains('Sort-Object -Property id'));
      expect(windows, contains('Immutable Microsoft Store MSIX bytes changed'));
      expect(windows, contains(r'sourceRunId = [long]$sourceRunId'));
      expect(windows, contains("if: steps.staged.outputs.reuse != 'true'"));
      expect(windows, contains('Build Windows x64 Store Release'));
      expect(windows, contains('-MicrosoftStore'));
      expect(
        windows,
        contains(r'MEETTRACE_MSIX_VERSION=1.0.$($env:RELEASE_BUILD_NUMBER).0'),
      );
      expect(
        windows,
        contains('Windows Store package build number exceeds 65535'),
      );
      expect(windows, contains('zhangheng2026.MeetTrace'));
      expect(windows, contains('CN=E5BC0A60-65F7-46C4-9A30-653FFCF9619B'));
      expect(
        windows,
        contains(r'publisherDisplayName = $identity.publisherDisplayName'),
      );
      expect(windows, contains(r'storeId = $identity.storeId'));
      expect(windows, contains(r'storeUrl = $identity.storeUrl'));
      expect(windows, contains('meettrace-windows-store-'));
      expect(windows, contains('build/windows/msix/*.msix'));
      expect(windows, contains('retention-days: 90'));
      expect(windows, isNot(contains('if: always()')));
      expect(windows, isNot(contains('gh release upload')));
      expect(windows, isNot(contains('New-SelfSignedCertificate')));
      expect(windows, isNot(contains('signtool sign')));
    });

    test('iOS 无签名检查只保留审计证据且不打包 IPA', () async {
      final workflow = await _workflow('quality.yml');
      final ios = _job(workflow, 'ios-unsigned', 'windows-msix-probe');

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
      expect(
        workflow,
        contains('.github/workflows/quality.yml|tool/ci/classify_changes.py'),
      );
      expect(workflow, contains('echo "\$TARGET=true"'));
      expect(workflow, contains('\n  flutter-quality:'));
      expect(workflow, contains('\n  ios-unsigned:'));
      expect(workflow, contains('\n  windows-msix-probe:'));
      expect(workflow, contains('\n  ci-gate:'));
      expect(workflow, contains('name: CI Gate'));
      expect(workflow, contains('if: always()'));
      expect(
        workflow,
        contains(
          'needs: [classify, flutter-quality, ios-unsigned, '
          'windows-msix-probe]',
        ),
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

    test('Windows CI 仅保留不可分发的 MSIX 探针证据', () async {
      final workflow = await _workflow('quality.yml');
      final windows = _job(workflow, 'windows-msix-probe', 'ci-gate');

      expect(windows, contains('runs-on: windows-2025'));
      expect(windows, contains('Set up Java 17 for JNI headers'));
      expect(windows, contains('Windows SDK KitsRoot10 is missing'));
      expect(windows, contains('flutter build windows --release'));
      expect(windows, contains('--dart-define=SENTRY_ENABLED=false'));
      expect(windows, contains("-Publisher 'CN=MeetTrace Development'"));
      expect(windows, contains('-DevelopmentProbe'));
      expect(windows, contains('tool/benchmarks/inspect_msix.ps1'));
      expect(windows, contains('Remove non-distributable MSIX probe'));
      expect(windows, contains('build/windows/msix/*.json'));
      expect(windows, contains('build/windows/msix/*.txt'));
      expect(windows, isNot(contains('build/windows/msix/*.msix')));
      expect(windows, isNot(contains('gh release upload')));
      expect(windows, isNot(contains('New-SelfSignedCertificate')));
      expect(windows, contains(r'\s*(?:#.*)?$'));
    });

    test('Codacy 仅跳过无法解析 Flutter package graph 的测试代码', () async {
      final configuration = await File('.codacy.yml').readAsString();

      expect(configuration, startsWith('---'));
      expect(configuration, contains('- ".agents/**"'));
      expect(configuration, contains('- ".claude/**"'));
      expect(configuration, contains('dartanalyzer:'));
      expect(configuration, contains('- "test/**"'));
      expect(configuration, isNot(contains('lib/**')));
      expect(configuration, isNot(contains('tool/**')));
      expect(configuration, isNot(contains('languages:')));
    });

    test('CodeQL 使用高级配置并排除代理技能目录', () async {
      final workflow = await _workflow('codeql.yml');
      final configuration = await File('.github/codeql/codeql-config.yml')
          .readAsString();

      expect(workflow, contains('name: CodeQL'));
      expect(
        workflow,
        contains('config-file: ./.github/codeql/codeql-config.yml'),
      );
      expect(workflow, contains('github/codeql-action/init@'));
      expect(workflow, contains('github/codeql-action/analyze@'));
      expect(workflow, contains('fail-fast: false'));
      expect(workflow, contains('- actions'));
      expect(workflow, contains('- c-cpp'));
      expect(workflow, contains('- python'));
      expect(configuration, contains('paths-ignore:'));
      expect(configuration, contains('- ".agents/**"'));
      expect(configuration, contains('- ".claude/**"'));
    });

    test('Android 与 iOS 正式构建使用 Environment Secret 上传 Sentry 符号', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');
      final ios = _job(workflow, 'ios', 'windows');

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

    test('publish job 只接受协调器门禁并自动公开原 Draft', () async {
      final workflow = await _workflow('alpha-release.yml');
      final publish = _job(workflow, 'publish');

      expect(publish, contains('environment: github-release'));
      expect(publish, contains("needs.prepare.outputs.mode == 'resume'"));
      expect(publish, contains("needs.prepare.outputs.mode == 'metadata'"));
      expect(
        publish,
        contains('Download and verify automatic publication gate'),
      );
      expect(
        publish,
        contains(
          'dart run tool/release/verify_release_orchestration_gate.dart',
        ),
      );
      expect(publish, contains(r'meettrace-release-gate-$RELEASE_ID'));
      expect(publish, contains('Alpha Release Reconciler'));
      expect(publish, contains('android-candidate-manifest.json'));
      expect(publish, contains('ios-candidate-manifest.json'));
      expect(publish, contains('windows-candidate-manifest.json'));
      expect(publish, contains('meettrace-windows-store-'));
      expect(publish, contains('9PHHSJMWK06G'));
      expect(publish, contains('Windows candidate Store identity changed'));
      expect(
        publish,
        contains('Windows Store package version mapping changed'),
      );
      expect(publish, contains('https://testflight\\.apple\\.com/join/'));
      expect(
        publish,
        contains(r'TESTFLIGHT_URL: ${{ vars.TESTFLIGHT_PUBLIC_LINK }}'),
      );
      expect(publish, contains('Staged Android APK digest changed'));
      expect(publish, contains('Existing public Android APK changed'));
      expect(publish, contains('endswith(".ipa")'));
      expect(publish, contains('endswith(".msix")'));
      expect(publish, contains('--draft=false --prerelease'));
      expect(publish, isNot(contains('gh release create')));
      expect(publish, isNot(contains('gh release upload')));
      expect(publish, isNot(contains('--clobber')));
      expect(publish, isNot(contains('git tag -a')));
      expect(
        publish.indexOf('Staged Android APK digest changed'),
        lessThan(publish.indexOf('--draft=false --prerelease')),
      );
    });

    test('商店审核与发布由无人工审批的协调器幂等推进', () async {
      final workflow = await _workflow('alpha-release.yml');
      final reconciler = await _workflow('alpha-release-reconcile.yml');
      final candidateValidation = await _workflow(
        'candidate-distribution-validation.yml',
      );
      final windowsFlight = _job(
        workflow,
        'windows_flight',
        'queue_reconciliation',
      );
      final publish = _job(workflow, 'publish');
      final storeStatus = _job(
        reconciler,
        'microsoft_store_status',
        'validation_status',
      );
      final submitProduction = _job(
        reconciler,
        'submit_production',
        'dispatch_flight_validation',
      );

      expect(workflow, isNot(contains('store_verification_mode:')));
      expect(workflow, contains('orchestration_run_id:'));
      expect(windowsFlight, contains('environment: microsoft-store'));
      expect(windowsFlight, contains('runs-on: windows-2025'));
      expect(
        windowsFlight,
        contains(r'actions/runs/$($env:GITHUB_RUN_ID)/artifacts?per_page=100'),
      );
      expect(windowsFlight, contains(r'[regex]::Escape($env:GITHUB_RUN_ID)'));
      expect(windowsFlight, contains('Sort-Object -Property id -Descending'));
      expect(
        windowsFlight,
        isNot(
          contains(
            r'"meettrace-windows-store-$($env:GITHUB_RUN_ID)-$($env:GITHUB_RUN_ATTEMPT)"',
          ),
        ),
      );
      expect(windowsFlight, contains(r'--inputDirectory $inputDirectory'));
      expect(windowsFlight, isNot(contains('--inputFile')));
      expect(windowsFlight, contains('--uploadTimeout 900'));
      expect(windowsFlight, isNot(contains('--verbose')));
      expect(windowsFlight, contains('PARTNER_CENTER_FLIGHT_SUBMISSION_ID'));
      expect(windowsFlight, contains(r'/submissions/$SubmissionId/status'));
      expect(windowsFlight, contains("'commitstarted'"));
      expect(windowsFlight, contains("'certification'"));
      expect(windowsFlight, contains("'publishing'"));
      expect(
        windowsFlight,
        contains('Reusing the tracked immutable Package Flight submission'),
      );
      expect(
        windowsFlight,
        contains('Tracked Package Flight submission requires recovery'),
      );
      expect(windowsFlight, isNot(contains('gh variable set')));
      expect(windowsFlight, contains('IsNullOrWhiteSpace'));
      expect(windowsFlight, contains('pendingFlightSubmission.id'));
      expect(
        windowsFlight,
        contains('Pending Package Flight submission requires recovery'),
      );
      expect(
        windowsFlight,
        contains(r'--flightId $env:PARTNER_CENTER_FLIGHT_ID'),
      );
      final reconfigureIndex = windowsFlight.indexOf('msstore reconfigure `');
      final settingsIndex = windowsFlight.indexOf(
        'msstore settings --enableTelemetry',
      );
      expect(reconfigureIndex, greaterThanOrEqualTo(0));
      expect(settingsIndex, greaterThan(reconfigureIndex));
      expect(
        windowsFlight,
        contains(r'MicrosoftStoreCli:user=$($env:PARTNER_CENTER_CLIENT_ID)'),
      );
      expect(windowsFlight, contains('EntryPoint = "CredDeleteW"'));
      expect(windowsFlight, isNot(contains('libsecret-1-0')));
      expect(windowsFlight, isNot(contains('msstore reconfigure --reset')));
      expect(
        windowsFlight,
        contains(
          'microsoft/microsoft-store-apppublisher@'
          'cc9910a8d59f2eb55cbb83df0a3800cf3b5300e0',
        ),
      );
      expect(windowsFlight, contains('version: v0.4.1'));
      final storeRecovery = await _workflow(
        'microsoft-store-flight-recovery.yml',
      );
      expect(storeRecovery, contains('environment: microsoft-store'));
      expect(storeRecovery, contains('actions: write'));
      expect(storeRecovery, contains("workflowName -cne 'Alpha Release'"));
      expect(storeRecovery, contains("headBranch -cne 'master'"));
      expect(storeRecovery, contains("conclusion -cne 'failure'"));
      expect(storeRecovery, contains(r'[regex]::Escape($env:SOURCE_RUN_ID)'));
      expect(storeRecovery, contains(r'--inputDirectory $inputDirectory'));
      expect(storeRecovery, isNot(contains('--inputFile')));
      expect(storeRecovery, contains('--uploadTimeout 900'));
      expect(storeRecovery, isNot(contains('--verbose')));
      expect(storeRecovery, contains("@('pendingcommit', 'commitfailed')"));
      expect(storeRecovery, contains("'InvalidParameterValue'"));
      expect(storeRecovery, contains(r'[regex]::Escape($packageVersion)'));
      expect(storeRecovery, contains(r"$submissionStatus -eq 'published'"));
      expect(storeRecovery, contains(r'$matchingCandidateNames.Count -ne 1'));
      expect(storeRecovery, contains("'commitstarted'"));
      expect(storeRecovery, contains("'certification'"));
      expect(
        storeRecovery,
        contains('does not match the immutable recovery candidate'),
      );
      final recoveryDeleteIndex = storeRecovery.indexOf(
        r'-Uri "$baseUri/submissions/$deletableSubmissionId"',
      );
      expect(storeRecovery, contains('Sort-Object -Property id |'));
      final recoveryPublishIndex = storeRecovery.indexOf(
        r'msstore publish $env:GITHUB_WORKSPACE `',
      );
      expect(recoveryDeleteIndex, greaterThanOrEqualTo(0));
      expect(recoveryPublishIndex, greaterThan(recoveryDeleteIndex));
      expect(
        storeRecovery,
        contains(
          'The tracked immutable Package Flight submission cannot be deleted',
        ),
      );
      expect(
        storeRecovery,
        contains(
          'The failed Package Flight draft belongs to a different candidate',
        ),
      );
      expect(
        storeRecovery,
        contains('A stale CLI response can describe the original Publishing'),
      );
      expect(
        storeRecovery,
        contains('Recovered Package Flight could not be bound'),
      );
      expect(
        windowsFlight,
        isNot(contains('msstore flights submission delete')),
      );
      expect(
        storeRecovery,
        contains('Resume Alpha Release on current master workflow'),
      );
      expect(storeRecovery, contains('gh workflow run alpha-release.yml `'));
      expect(storeRecovery, contains('--ref master `'));
      expect(storeRecovery, contains(r'-f "release_id=$($env:RELEASE_ID)"'));
      expect(storeRecovery, isNot(contains('/rerun')));
      for (final secret in <String>[
        'PARTNER_CENTER_TENANT_ID',
        'PARTNER_CENTER_SELLER_ID',
        'PARTNER_CENTER_CLIENT_ID',
        'PARTNER_CENTER_CLIENT_SECRET',
      ]) {
        expect(
          windowsFlight,
          contains(
            r'${{ secrets.'
            '$secret'
            ' }}',
          ),
        );
      }
      for (final secret in <String>[
        'PARTNER_CENTER_TENANT_ID',
        'PARTNER_CENTER_SELLER_ID',
        'PARTNER_CENTER_CLIENT_ID',
        'PARTNER_CENTER_CLIENT_SECRET',
      ]) {
        expect(publish, isNot(contains(secret)));
      }
      expect(
        publish,
        contains(
          r'PARTNER_CENTER_FLIGHT_ID: ${{ vars.PARTNER_CENTER_FLIGHT_ID }}',
        ),
      );
      expect(publish, isNot(contains('msstore submission get')));
      expect(publish, contains('windows-store-production-receipt.json'));
      expect(reconciler, contains('cron: "*/15 * * * *"'));
      expect(reconciler, contains('types: [alpha-release-reconcile]'));
      expect(reconciler, contains('app_store_connect_status.rb'));
      expect(reconciler, contains('verify_testflight_submission.dart'));
      expect(reconciler, contains('submission-request.json'));
      expect(reconciler, contains('windows_flight_submission_id'));
      expect(storeStatus, contains('runs-on: windows-2025'));
      expect(storeStatus, contains('version: v0.4.1'));
      expect(storeStatus, contains('PARTNER_CENTER_FLIGHT_SUBMISSION_ID'));
      expect(storeStatus, contains(r'-Uri "$submissionUri/status"'));
      expect(storeStatus, contains('ApplicationPackages = @('));
      expect(storeStatus, contains("Architecture = 'x64'"));
      expect(storeStatus, isNot(contains('msstore flights submission get `')));
      expect(storeStatus, contains('9PHHSJMWK06G'));
      expect(storeStatus, contains('Write-Output -NoEnumerate'));
      expect(reconciler, contains('msstore submission get 9PHHSJMWK06G'));
      expect(submitProduction, contains('runs-on: windows-2025'));
      expect(submitProduction, contains('version: v0.4.1'));
      expect(submitProduction, contains(r'--inputDirectory $inputDirectory'));
      expect(submitProduction, isNot(contains('--inputFile')));
      expect(submitProduction, contains('--packageRolloutPercentage 100'));
      expect(submitProduction, contains('--uploadTimeout 900'));
      expect(submitProduction, isNot(contains('--verbose')));
      for (final job in [windowsFlight, storeStatus, submitProduction]) {
        final configure = job.indexOf('msstore reconfigure `');
        final settings = job.indexOf('msstore settings --enableTelemetry');
        expect(configure, greaterThanOrEqualTo(0));
        expect(settings, greaterThan(configure));
        expect(job, contains('EntryPoint = "CredDeleteW"'));
        expect(
          job,
          contains(r'MicrosoftStoreCli:user=$($env:PARTNER_CENTER_CLIENT_ID)'),
        );
        expect(job, isNot(contains('msstore reconfigure --reset')));
      }
      expect(reconciler, contains('release-blocked'));
      expect(reconciler, contains('meettrace-release-gate-'));
      expect(reconciler, contains('gh workflow run alpha-release.yml'));
      expect(reconciler, isNot(contains('manualEnvironmentApproval')));
      expect(
        candidateValidation,
        contains('types: [candidate-distribution-validation]'),
      );
      expect(candidateValidation, contains('--no-resign'));
      expect(
        candidateValidation,
        contains('runs-on: [self-hosted, Windows, X64, meettrace-store]'),
      );

      final gateVerification = publish.indexOf(
        'Download and verify automatic publication gate',
      );
      final pointerPreparation = publish.indexOf(
        'Prepare signed automatic-update pointer',
      );
      final releasePublication = publish.indexOf(
        'Publish verified draft or update public link',
      );
      final pointerPublication = publish.indexOf(
        'Atomically publish signed automatic-update pointer',
      );
      expect(gateVerification, greaterThanOrEqualTo(0));
      expect(gateVerification, lessThan(pointerPreparation));
      expect(pointerPreparation, lessThan(releasePublication));
      expect(releasePublication, lessThan(pointerPublication));
    });

    test('三平台正式包启用签名自动更新且指针只在公开后原子写入', () async {
      final workflow = await _workflow('alpha-release.yml');
      final runtimeConfiguration = await File(
        'lib/data/services/updates/app_update_configuration.dart',
      ).readAsString();
      final android = _job(workflow, 'android', 'ios');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'windows_flight');
      final publish = _job(workflow, 'publish');

      for (final job in <String>[android, ios, windows]) {
        expect(job, contains('MEETTRACE_APP_UPDATE_ENABLED=true'));
        expect(job, contains('MEETTRACE_VERSION_NAME='));
        expect(job, contains('MEETTRACE_BUILD_NUMBER='));
      }
      expect(runtimeConfiguration, contains("'MEETTRACE_APP_UPDATE_ENABLED'"));
      expect(runtimeConfiguration, contains('defaultValue: false'));
      expect(
        runtimeConfiguration,
        isNot(contains('defaultValue: kReleaseMode')),
      );
      expect(workflow, contains('withdraw_update:'));
      expect(workflow, contains('repair_update_pointer:'));
      expect(
        workflow,
        contains('Withdrawal and pointer repair are mutually exclusive'),
      );
      expect(android, contains('"packageIdentity": "com.meettrace.app"'));
      expect(android, contains('"signingIdentitySha256": signing_identity'));
      expect(
        publish,
        contains(
          r'APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64: ${{ secrets.APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64 }}',
        ),
      );
      expect(
        publish,
        contains(
          'dart run tool/release/create_signed_app_update_manifest.dart',
        ),
      );
      expect(publish, contains('refs/heads/updates/alpha'));
      expect(publish, contains('UPDATE_POINTER_PREVIOUS_SHA'));
      expect(publish, contains(r'sha: $sha'));
      expect(publish, contains('cmp build/finalize/update/alpha.json'));
      expect(
        publish.indexOf('--draft=false --prerelease'),
        lessThan(
          publish.indexOf('Atomically publish signed automatic-update pointer'),
        ),
      );
      expect(
        publish.indexOf('Prepare signed automatic-update pointer'),
        lessThan(publish.indexOf('--draft=false --prerelease')),
      );
      expect(
        publish,
        isNot(contains('APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64=')),
      );
    });

    test('Release 只保留 APK 与单一候选清单，详细证据进入 Artifact', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');
      final publish = _job(workflow, 'publish');
      final uploadStart = android.indexOf('          gh release upload');
      final uploadEnd = android.indexOf(
        r'            --repo "$GITHUB_REPOSITORY"',
        uploadStart,
      );
      expect(uploadStart, greaterThanOrEqualTo(0));
      expect(uploadEnd, greaterThan(uploadStart));
      final releaseUpload = android.substring(uploadStart, uploadEnd);

      expect(releaseUpload, contains(r'"$APK_PATH"'));
      expect(
        releaseUpload,
        contains('build/android/alpha/candidate-manifest.json'),
      );
      for (final redundantAsset in [
        'android-apk-inspection.json',
        'android-release-apk.sha256',
        'apksigner.txt',
        'signing-certificate.sha256',
      ]) {
        expect(releaseUpload, isNot(contains(redundantAsset)));
        expect(android, contains(redundantAsset));
        expect(publish, contains(redundantAsset));
      }
      expect(android, contains('build/android/alpha/*.json'));
      expect(android, contains('build/android/alpha/*.sha256'));
      expect(android, contains('build/android/alpha/*.txt'));
      expect(publish, contains('Remove redundant Release evidence assets'));
    });

    test('失败发布可复用已成功的三平台候选且不重复构建或上传', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'ios');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'windows_flight');
      final publish = _job(workflow, 'publish');

      expect(workflow, contains('resume_run_id:'));
      expect(workflow, contains('mode=resume'));
      expect(
        android,
        contains("if: needs.prepare.outputs.mode == 'candidate'"),
      );
      expect(ios, contains("if: needs.prepare.outputs.mode == 'candidate'"));
      expect(
        windows,
        contains("if: needs.prepare.outputs.mode == 'candidate'"),
      );
      expect(
        publish,
        contains('Download candidate evidence from the verified run'),
      );
      expect(publish, contains(r'gh run view "$source_run_id"'));
      expect(publish, contains('.workflowName == "Alpha Release"'));
      expect(
        publish,
        contains(
          'Source run did not complete all three release candidates successfully',
        ),
      );
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

    test('公开分发验证只接受默认分支调度事件和不可变生产合同', () async {
      final workflow = await _workflow('platform-distribution-validation.yml');
      final resolve = _job(workflow, 'resolve', 'android_public_install');
      final runVerification = _step(
        resolve,
        'Verify source, publish run, and Android signing lineage',
        'Export validated contract',
      );

      expect(workflow, contains('name: Platform Distribution Validation'));
      expect(workflow, contains('repository_dispatch:'));
      expect(workflow, contains('types: [platform-distribution-validation]'));
      expect(workflow, isNot(contains('  workflow_dispatch:')));
      expect(workflow, contains('cancel-in-progress: false'));
      expect(resolve, contains('fetch-depth: 0'));
      expect(resolve, contains(r'[[ "$GITHUB_REF" == "refs/heads/master" ]]'));
      expect(
        resolve,
        contains('dart run tool/release/verify_public_update.dart'),
      );
      expect(resolve, contains('--windows-production-receipt'));
      expect(resolve, contains(r'--publish-run-id "$PUBLISH_RUN_ID"'));
      expect(resolve, contains('.workflowName == "Alpha Release"'));
      expect(resolve, contains('.conclusion == "success"'));
      expect(resolve, contains(r'.headSha == $sha'));
      expect(runVerification, contains(r'gh run view "$SOURCE_RUN_ID"'));
      expect(runVerification, contains(r'gh run view "$PUBLISH_RUN_ID"'));
      expect(runVerification, contains('build/distribution/publish-run.json'));
      expect(resolve, contains('sort_by(.created_at, .id)'));
      expect(resolve, contains('matching unexpired artifact was not found'));
      expect(resolve, contains(r'git cat-file -t "$RELEASE_ID"'));
      expect(resolve, contains(r'git rev-list -n 1 "$RELEASE_ID"'));
      expect(resolve, contains('Android signing lineage changed'));
      expect(resolve, contains('aapt" dump badging'));
      expect(resolve, contains('apksigner" verify --print-certs'));
      expect(runVerification, contains(r'(?:Signer #\d+|V\d+ Signer:)'));
      expect(runVerification, contains('len(signing_digests) != 1'));
      expect(
        runVerification,
        contains('android_arm64_version_code_offset = 2000'),
      );
      expect(
        runVerification,
        contains('previous.get("schemaVersion") not in (1, 2)'),
      );
      expect(
        runVerification,
        contains('Android APK marketing version differs'),
      );
      expect(
        runVerification,
        contains('Android APK version code differs from the arm64 split'),
      );
      expect(
        resolve,
        contains(
          'actions/setup-java@'
          'b6effb05e454b25005698d916606bdc6ffcbf961',
        ),
      );
      expect(resolve, contains('Artifact digest changed:'));
      expect(resolve, contains('updates/alpha'));
      expect(resolve, isNot(contains(r'${{ secrets.')));
    });

    test('Android 公开 APK 在 ARM Test Lab 原样安装启动', () async {
      final workflow = await _workflow('platform-distribution-validation.yml');
      final android = _job(
        workflow,
        'android_public_install',
        'ios_testflight_evidence',
      );

      expect(workflow, contains("|| 'MediumPhone.arm'"));
      expect(android, contains('gcloud firebase test android run'));
      expect(android, contains('--type robo'));
      expect(android, contains('--no-resign'));
      expect(android, contains('arm64-v8a'));
      expect(android, contains('.supportedAbis'));
      expect(android, contains('sha256sum --check --strict'));
      expect(android, isNot(contains('--additional-apks')));
      expect(android, isNot(contains('app-x86_64')));
    });

    test('iOS 只复核 TestFlight 提交证据且不下载或上传 IPA', () async {
      final workflow = await _workflow('platform-distribution-validation.yml');
      final ios = _job(workflow, 'ios_testflight_evidence', 'windows_store');

      expect(ios, contains(r'--name "$IOS_SOURCE_ARTIFACT_NAME"'));
      expect(
        ios,
        isNot(contains(r'meettrace-ios-testflight-${SOURCE_RUN_ID}-*')),
      );
      expect(ios, contains("-iname '*.ipa'"));
      expect(ios, contains('ipaExposed'));
      expect(ios, contains('testFlightSubmissionEvidence'));
      expect(ios, isNot(contains('fastlane ios upload_testflight')));
      expect(ios, isNot(contains('gh release upload')));
    });

    test('Windows Store 生命周期只在受保护专用自托管机执行', () async {
      final workflow = await _workflow('platform-distribution-validation.yml');
      final windows = _job(workflow, 'windows_store', 'validation_gate');
      final script = await File('tool/windows/validate_store_distribution.ps1')
          .readAsString();

      expect(
        windows,
        contains('runs-on: [self-hosted, Windows, X64, meettrace-store]'),
      );
      expect(windows, contains('environment: windows-store-validation'));
      expect(windows, contains('MEETTRACE_DEDICATED_STORE_VALIDATION: "1"'));
      expect(windows, contains("RUNNER_ENVIRONMENT -cne 'self-hosted'"));
      expect(windows, contains('validate_store_distribution.ps1'));
      expect(windows, contains(r'-Mode $env:WINDOWS_VALIDATION_MODE'));
      expect(
        windows,
        contains(r'-PreviousVersion $env:WINDOWS_PREVIOUS_VERSION'),
      );
      expect(
        windows,
        isNot(contains(r"-Mode '${{ github.event.client_payload")),
      );
      expect(windows, contains('Revalidate Windows candidate bytes'));
      expect(script, contains("ValidateSet('InstallUninstall', 'Update')"));
      expect(script, contains(r"$storeId = '9PHHSJMWK06G'"));
      expect(script, contains(r"$identityName = 'zhangheng2026.MeetTrace'"));
      expect(script, contains(r"$env:GITHUB_REF -cne 'refs/heads/master'"));
      expect(
        script,
        contains(r"$env:GITHUB_EVENT_NAME -cne 'repository_dispatch'"),
      );
      expect(script, contains('winget source list --disable-interactivity'));
      expect(script, contains(r'[int]$os.ProductType -ne 1'));
      expect(script, contains('MeetTraceWindowValidation'));
      expect(script, contains(r'ShowWindowAsync($windowHandle, 6)'));
      expect(script, contains(r'GetForegroundWindow() -eq $windowHandle'));
      expect(
        script,
        contains(
          'Second launch did not restore and foreground the existing '
          'MeetTrace window.',
        ),
      );
      expect(script, contains(r"'install', '--id', $storeId"));
      expect(script, contains(r"'upgrade', '--id', $storeId"));
      expect(script, contains('[CmdletBinding(SupportsShouldProcess)]'));
      expect(script, contains(r'$PSCmdlet.ShouldProcess('));
      expect(
        script,
        contains(
          'Store validation cannot complete without removing the '
          'current-user package.',
        ),
      );
      expect(script, contains('Remove-AppxPackage -Package'));
      expect(script, isNot(contains('Remove-AppxPackage -AllUsers')));
      expect(script, isNot(contains('Get-AppxPackage -AllUsers')));
    });

    test('纵向验证必须等待三个平台成功且没有旁路', () async {
      final workflow = await _workflow('platform-distribution-validation.yml');
      final gate = _job(workflow, 'validation_gate');

      expect(
        workflow,
        contains(
          'needs: [resolve, android_public_install, '
          'ios_testflight_evidence, windows_store]',
        ),
      );
      expect(gate, contains('Platform distribution validation passed'));
      expect(gate, isNot(contains('if: always()')));
      expect(workflow, isNot(contains('continue-on-error: true\n    name:')));
    });
  });
}
