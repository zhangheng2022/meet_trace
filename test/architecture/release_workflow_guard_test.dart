import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String> _workflow(String name) =>
    File('.github/workflows/$name').readAsString();

void main() {
  group('GitHub Alpha 发布守卫', () {
    test('仅 Alpha Release 暴露手动入口且只要求 release ID', () async {
      final orchestrator = await _workflow('alpha-release.yml');
      final internalWorkflows = await Future.wait([
        _workflow('android-alpha.yml'),
        _workflow('ios-testflight.yml'),
        _workflow('finalize-release.yml'),
      ]);

      expect(orchestrator, contains('name: Alpha Release'));
      expect(orchestrator, contains('workflow_dispatch:'));
      expect(orchestrator, contains('release_id:'));
      expect(orchestrator, contains('release_notes:'));
      expect(orchestrator, contains('ios_testflight_external_url:'));
      final dispatchInputs = orchestrator.substring(
        orchestrator.indexOf('  workflow_dispatch:'),
        orchestrator.indexOf('\npermissions:'),
      );
      expect(RegExp(r'required: true').allMatches(dispatchInputs), hasLength(1));
      expect(orchestrator, isNot(contains('expected_sha:')));
      expect(orchestrator, isNot(contains('gate_input_path:')));
      expect(orchestrator, contains('name: Automatic technical checks'));
      expect(
        orchestrator,
        contains('uses: ./.github/workflows/android-alpha.yml'),
      );
      expect(
        orchestrator,
        contains('uses: ./.github/workflows/ios-testflight.yml'),
      );
      expect(
        orchestrator,
        contains('uses: ./.github/workflows/finalize-release.yml'),
      );

      for (final workflow in internalWorkflows) {
        expect(workflow, contains('workflow_call:'));
        expect(workflow, isNot(contains('workflow_dispatch:')));
      }
    });

    test('产品质量记录不再作为自动发布门禁', () async {
      final workflows = await Future.wait([
        _workflow('alpha-release.yml'),
        _workflow('android-alpha.yml'),
        _workflow('ios-testflight.yml'),
        _workflow('finalize-release.yml'),
      ]);

      for (final workflow in workflows) {
        expect(workflow, isNot(contains('alpha_release_input.json')));
        expect(workflow, isNot(contains('evaluate_alpha_release.dart')));
        expect(workflow, isNot(contains('gateDecision')));
        expect(workflow, isNot(contains('release-gate-report')));
      }
    });

    test('Android Draft 可恢复重试但公开后不可覆盖', () async {
      final workflow = await _workflow('android-alpha.yml');

      expect(workflow, contains('environment: android-alpha'));
      expect(workflow, contains('--target-platform android-arm64'));
      expect(workflow, contains(r'meettrace-${RELEASE_ID}-android-arm64.apk'));
      expect(workflow, contains(r'git tag -a "$RELEASE_ID"'));
      expect(workflow, contains(r'.isDraft <<<"$release_json")" == true'));
      expect(workflow, contains('--draft --prerelease'));
      expect(workflow, contains('--clobber'));
      expect(workflow, contains('ANDROID_SIGNING_CERT_SHA256'));
      expect(workflow, contains('uses: actions/attest@v4'));
      expect(workflow, contains(r'if ($abis.Count -ne 1'));
      expect(workflow, isNot(contains('build/app/outputs/flutter-apk/*.apk')));
    });

    test('iOS 只上传 TestFlight 且不向 GitHub 暴露签名 IPA', () async {
      final workflow = await _workflow('ios-testflight.yml');

      expect(workflow, contains('environment: testflight'));
      expect(workflow, contains('contents: read'));
      expect(workflow, contains('uses: actions/attest@v4'));
      expect(workflow, contains('run: fastlane ios upload_testflight'));
      expect(workflow, contains(r'ref: ${{ inputs.candidate_sha }}'));
      expect(workflow, isNot(contains('gh release upload')));
      expect(workflow, isNot(contains('build/ios/testflight/*.ipa')));
    });

    test('最终发布只有一次批准并支持不重建地后补链接', () async {
      final orchestrator = await _workflow('alpha-release.yml');
      final workflow = await _workflow('finalize-release.yml');

      expect(orchestrator, contains("mode == 'metadata'"));
      expect(workflow, contains('environment: github-release'));
      expect(workflow, contains("if: inputs.mode == 'candidate'"));
      expect(workflow, contains("if: inputs.mode == 'metadata'"));
      expect(workflow, contains('android-candidate-manifest.json'));
      expect(workflow, contains('ios-candidate-manifest.json'));
      expect(workflow, contains('https://testflight\\.apple\\.com/join/'));
      expect(workflow, contains('iOS TestFlight 外部测试链接：待提供'));
      expect(workflow, contains('Staged Android APK digest changed'));
      expect(workflow, contains('Existing public Android APK changed'));
      expect(workflow, contains('endswith(".ipa")'));
      expect(workflow, contains('unexpected APK name'));
      expect(workflow, contains('--draft=false --prerelease'));
      expect(workflow, isNot(contains('gh release create')));
      expect(workflow, isNot(contains('git tag -a')));
      expect(
        workflow.indexOf('Staged Android APK digest changed'),
        lessThan(workflow.indexOf('--draft=false --prerelease')),
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
