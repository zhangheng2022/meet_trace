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
  group('GitHub Actions 结构守卫', () {
    test('仓库只保留六个职责明确的工作流', () async {
      final names = await Directory('.github/workflows')
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.yml'))
          .map((entry) => entry.uri.pathSegments.last)
          .toList();

      expect(names.toSet(), <String>{
        '_flutter-core.yml',
        'alpha-release-reconcile.yml',
        'alpha-release.yml',
        'codeql.yml',
        'firebase-test-lab.yml',
        'quality.yml',
      });
    });

    test('所有第三方 Action 固定完整提交 SHA', () async {
      final files = await Directory('.github/workflows')
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.yml'))
          .cast<File>()
          .toList();
      final source = (await Future.wait(
        files.map((file) => file.readAsString()),
      )).join('\n');

      for (final match in RegExp(r'uses:\s+([^\s]+)').allMatches(source)) {
        final reference = match.group(1)!;
        if (reference.startsWith('./')) {
          continue;
        }
        expect(
          reference,
          matches(RegExp(r'^[^@]+@[0-9a-f]{40}$')),
          reason: 'Action 未固定完整 SHA：$reference',
        );
      }
    });

    test('只有 Alpha Release 是人工发布入口', () async {
      final release = await _workflow('alpha-release.yml');
      final reconciler = await _workflow('alpha-release-reconcile.yml');

      expect(release, contains('name: Alpha Release'));
      expect(release, contains('  workflow_dispatch:'));
      expect(release, contains('release_id:'));
      expect(reconciler, isNot(contains('  workflow_dispatch:')));
      expect(reconciler, contains('types: [alpha-release-reconcile]'));
      expect(reconciler, contains('cron: "*/15 * * * *"'));
    });

    test('常规 CI 将 Actions Lint 纳入稳定 CI Gate', () async {
      final workflow = await _workflow('quality.yml');
      final lint = _job(workflow, 'actions-lint', 'classify');
      final gate = _job(workflow, 'ci-gate');

      expect(lint, contains('name: Actions Lint'));
      expect(lint, contains('actionlint/cmd/actionlint@v1.7.12'));
      expect(lint, contains('actionlint -config-file .github/actionlint.yaml'));
      expect(gate, contains('if: always()'));
      expect(gate, contains('actions-lint'));
      expect(gate, contains('ACTIONS_LINT_RESULT'));
      expect(gate, contains(r'[[ "$ACTIONS_LINT_RESULT" == "success" ]]'));
      expect(workflow, isNot(contains('paths-ignore:')));
    });
  });

  group('Alpha 候选守卫', () {
    test('三平台候选共享 SHA、构建号和质量核心', () async {
      final workflow = await _workflow('alpha-release.yml');
      final quality = _job(workflow, 'quality', 'android');
      final android = _job(workflow, 'android', 'android_distribution');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'queue_reconciliation');

      expect(quality, contains('uses: ./.github/workflows/_flutter-core.yml'));
      expect(workflow, contains('build_number:'));
      expect(android, contains('--split-per-abi'));
      expect(android, contains('--target-platform android-arm64'));
      expect(android, contains('androidBaseBuildNumber'));
      expect(android, contains('versionCode'));
      expect(ios, contains('IOS_BUILD_NUMBER'));
      expect(windows, contains('RELEASE_BUILD_NUMBER'));
      for (final job in <String>[android, ios, windows]) {
        expect(job, contains('MEETTRACE_APP_UPDATE_ENABLED=true'));
        expect(job, contains(r'${{ needs.prepare.outputs.candidate_sha }}'));
      }
    });

    test('Android 签名候选只执行一次 Firebase ARM 原包验证', () async {
      final workflow = await _workflow('alpha-release.yml');
      final validation = _job(workflow, 'android_distribution', 'ios');

      expect(validation, contains('Validate signed Android candidate once'));
      expect(validation, contains('MediumPhone.arm'));
      expect(validation, contains('--type robo'));
      expect(validation, contains('--no-resign'));
      expect(validation, contains('androidCandidateDistribution'));
      expect(validation, contains('artifactSha256'));
      expect(
        RegExp(r'gcloud firebase test android run').allMatches(workflow).length,
        1,
      );
    });

    test('GitHub Release 不包含 IPA 或 MSIX', () async {
      final workflow = await _workflow('alpha-release.yml');
      final android = _job(workflow, 'android', 'android_distribution');
      final ios = _job(workflow, 'ios', 'windows');
      final windows = _job(workflow, 'windows', 'queue_reconciliation');
      final publish = _job(workflow, 'publish');

      expect(android, contains('gh release upload'));
      expect(android, contains('candidate-manifest.json'));
      expect(ios, isNot(contains('gh release upload')));
      expect(windows, isNot(contains('gh release upload')));
      expect(publish, contains('endswith(".ipa")'));
      expect(publish, contains('endswith(".msix")'));
      expect(workflow, isNot(contains('--clobber')));
    });
  });

  group('发布协调器守卫', () {
    test('协调器直接执行 Windows Flight 与 production 生命周期', () async {
      final workflow = await _workflow('alpha-release-reconcile.yml');
      final flightScript = await File(
        'tool/release/submit_microsoft_store_flight.ps1',
      ).readAsString();
      final submission = _job(
        workflow,
        'microsoft_store_flight',
        'microsoft_store_status',
      );
      final flight = _job(
        workflow,
        'windows_flight_validation',
        'windows_production_validation',
      );

      expect(submission, contains('Submit or recover Microsoft Store'));
      expect(
        submission,
        contains('tool/release/submit_microsoft_store_flight.ps1'),
      );
      expect(submission, contains('windows-flight-request.json'));
      expect(workflow, isNot(contains('  windows_flight:')));
      expect(
        workflow,
        contains('sort_by(.created_at, .id) | last | .id // empty'),
      );
      expect(flightScript, contains("'pendingcommit', 'commitfailed'"));
      expect(flightScript, contains('Test-RecoverableCandidate'));
      expect(flightScript, contains('Invoke-RestMethod -Method Delete'));
      expect(flightScript, contains('belongs to a different candidate'));
      final production = _job(
        workflow,
        'windows_production_validation',
        'report_blocked',
      );

      for (final entry in <MapEntry<String, String>>[
        MapEntry('flight', flight),
        MapEntry('production', production),
      ]) {
        expect(
          entry.value,
          contains('runs-on: [self-hosted, Windows, X64, meettrace-store]'),
        );
        expect(entry.value, contains('environment: windows-store-validation'));
        expect(entry.value, contains('MEETTRACE_DEDICATED_STORE_VALIDATION'));
        expect(entry.value, contains('validate_store_distribution.ps1'));
        expect(entry.value, contains("stage = '${entry.key}'"));
        expect(entry.value, contains('windowsStoreDistribution'));
        expect(entry.value, contains("windowsStoreLifecycle = 'passed'"));
        expect(entry.value, contains('event_type=alpha-release-reconcile'));
      }
      expect(workflow, isNot(contains('candidate-distribution-validation')));
      expect(
        workflow,
        isNot(contains('Dispatch dedicated candidate validation')),
      );
    });

    test('协调门禁绑定单次 Android 与两次独立 Windows 验证', () async {
      final workflow = await _workflow('alpha-release-reconcile.yml');
      final status = _job(workflow, 'validation_status', 'submit_production');
      final finalize = _job(workflow, 'finalize');

      expect(status, contains('androidCandidateDistribution'));
      expect(status, contains('windowsStoreDistribution'));
      expect(status, contains('android_ready'));
      expect(status, contains(r'windows-$stage.json'));
      expect(
        status,
        contains(r'meettrace-reconcile-windows-$stage-$RELEASE_ID'),
      );
      expect(finalize, contains('schemaVersion: 2'));
      expect(finalize, contains('validations: {android:'));
      expect(finalize, contains('windowsFlight:'));
      expect(finalize, contains('windowsProduction:'));
      expect(finalize, contains('gh workflow run alpha-release.yml'));
    });

    test('候选发现只接受带 Firebase ARM 回执的新发布运行', () async {
      final workflow = await _workflow('alpha-release-reconcile.yml');
      final resolve = _job(workflow, 'resolve', 'testflight_status');
      final validation = _job(
        workflow,
        'validation_status',
        'submit_production',
      );

      expect(
        resolve,
        contains('Validate signed Android candidate once on Firebase ARM64'),
      );
      expect(
        validation,
        contains(r'android_name="meettrace-android-distribution-$RELEASE_ID"'),
      );
      expect(
        validation,
        contains('.validation == "androidCandidateDistribution"'),
      );
      expect(validation, contains(r'.artifactSha256 == $digest'));
    });

    test('候选发现失败也会维护 release-blocked Issue', () async {
      final workflow = await _workflow('alpha-release-reconcile.yml');
      final resolve = _job(workflow, 'resolve', 'testflight_status');
      final report = _job(workflow, 'report_blocked', 'finalize');

      expect(resolve, contains(r'echo "release_id=$release_id"'));
      expect(
        resolve.indexOf(r'echo "release_id=$release_id"'),
        lessThan(resolve.indexOf(r'release_json="$(jq')),
      );
      expect(report, contains("needs.resolve.result == 'failure'"));
      expect(report, contains("needs.resolve.result != 'success'"));
      expect(report, contains('validation_status'));
      expect(report, contains("needs.validation_status.result != 'success'"));
      expect(report, contains('release_key=reconciler-discovery'));
      expect(report, contains('Candidate resolution: %s'));
      final finalize = _job(workflow, 'finalize');
      expect(finalize, contains('[release-blocked] reconciler-discovery'));
    });

    test('公开后重新下载 Android APK，成功后才更新指针', () async {
      final workflow = await _workflow('alpha-release.yml');
      final publish = _job(workflow, 'publish');
      final releaseIndex = publish.indexOf(
        'Publish verified draft or update public link',
      );
      final publicCheckIndex = publish.indexOf(
        'Re-download and verify public Android APK',
      );
      final pointerIndex = publish.indexOf(
        'Atomically publish signed automatic-update pointer',
      );

      expect(releaseIndex, greaterThanOrEqualTo(0));
      expect(publicCheckIndex, greaterThan(releaseIndex));
      expect(pointerIndex, greaterThan(publicCheckIndex));
      expect(publish, contains('gh release download'));
      expect(publish, contains(r'[[ "$actual_sha" == "$expected_sha" ]]'));
    });

    test('拒审或未知状态失败关闭且正常路径无人工审批', () async {
      final workflow = await _workflow('alpha-release-reconcile.yml');
      final bootstrap = await File(
        'tool/release/bootstrap_release_automation.ps1',
      ).readAsString();

      expect(workflow, contains('release-blocked'));
      expect(workflow, contains('cron: "*/15 * * * *"'));
      expect(workflow, contains('--packageRolloutPercentage 100'));
      expect(workflow, isNot(contains('manualEnvironmentApproval')));
      expect(bootstrap, contains('wait_timer'));
      expect(bootstrap, contains('reviewers'));
    });
  });
}
