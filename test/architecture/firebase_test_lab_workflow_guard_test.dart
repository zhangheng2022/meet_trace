import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase Test Lab 工作流仅允许从 master 手动运行', () {
    final workflow = File('.github/workflows/firebase-test-lab.yml')
        .readAsStringSync();

    final triggerBlock = workflow.substring(
      workflow.indexOf('on:'),
      workflow.indexOf('permissions:'),
    );

    expect(triggerBlock, contains('workflow_dispatch:'));
    expect(triggerBlock, isNot(contains('push:')));
    expect(triggerBlock, isNot(contains('pull_request:')));
    expect(workflow, contains(r'[[ "$GITHUB_REF" != "refs/heads/master" ]]'));
  });

  test('Firebase Test Lab 工作流使用 OIDC 和完整 Patrol 测试矩阵', () {
    final workflow = File('.github/workflows/firebase-test-lab.yml')
        .readAsStringSync();

    expect(workflow, contains('id-token: write'));
    expect(workflow, contains('FIREBASE_PROJECT_ID: meet-trace'));
    expect(
      workflow,
      contains(
        'google-github-actions/auth@'
        '7c6bc770dae815cd3e89ee6cdf493a5fab2cc093 # v3',
      ),
    );
    expect(
      workflow,
      contains(
        'google-github-actions/setup-gcloud@'
        'aa5489c8933f4cc7a4f7d45035b3b1440c9c10db # v3',
      ),
    );
    expect(workflow, contains('install_components: alpha'));
    expect(workflow, contains(r'vars.GCP_WORKLOAD_IDENTITY_PROVIDER'));
    expect(workflow, contains(r'vars.GCP_SERVICE_ACCOUNT'));
    expect(workflow, isNot(contains('credentials_json')));
    const patrolTargets = <String>[
      'patrol_test/harness_smoke_test.dart',
      'patrol_test/meeting_list_smoke_test.dart',
      'patrol_test/microphone_permission_recovery_test.dart',
      'patrol_test/meeting_golden_path_test.dart',
      'patrol_test/recording_continuity_test.dart',
    ];
    for (final target in patrolTargets) {
      expect(workflow, contains('target: $target'));
    }
    expect(
      RegExp(
        r'^\s+target: patrol_test/.+_test\.dart$',
        multiLine: true,
      ).allMatches(workflow),
      hasLength(patrolTargets.length),
    );
    expect(workflow, contains('fail-fast: false'));
    expect(workflow, contains('max-parallel: 2'));
    expect(workflow, contains('android_version: ["35", "36"]'));
    expect(
      workflow,
      contains(r'ANDROID_VERSION: ${{ matrix.android_version }}'),
    );
    expect(workflow, contains(r'PATROL_NAME: ${{ matrix.patrol.name }}'));
    expect(workflow, contains(r'PATROL_TARGET: ${{ matrix.patrol.target }}'));
    expect(workflow, contains(r'patrol build android \'));
    expect(workflow, contains(r'--target "$PATROL_TARGET" \'));
    expect(workflow, contains(r'gcloud alpha firebase test android run \'));
    expect(workflow, contains(r'--grant-permissions=none \'));
    expect(
      workflow,
      contains(
        r'matrixLabel=meettrace-api${ANDROID_VERSION}-${PATROL_NAME}-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}',
      ),
    );
    expect(
      workflow,
      contains(
        r'name: firebase-test-lab-api-${{ matrix.android_version }}-${{ matrix.patrol.name }}-${{ github.run_id }}-${{ github.run_attempt }}',
      ),
    );
    expect(workflow, contains('default: MediumPhone.arm'));
    expect(workflow, contains('--timeout 45m'));
    expect(workflow, isNot(contains('--use-orchestrator')));
    expect(workflow, contains('name: Collect Firebase raw results'));
    expect(workflow, contains(r'gcloud storage rsync --recursive \'));
    expect(workflow, contains('build/firebase-test-lab/raw-results/'));
  });
}
