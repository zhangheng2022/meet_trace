import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase Test Lab 工作流仅允许从 master 手动运行', () {
    final workflow = File(
      '.github/workflows/firebase-test-lab.yml',
    ).readAsStringSync();

    final triggerBlock = workflow.substring(
      workflow.indexOf('on:'),
      workflow.indexOf('permissions:'),
    );

    expect(triggerBlock, contains('workflow_dispatch:'));
    expect(triggerBlock, isNot(contains('push:')));
    expect(triggerBlock, isNot(contains('pull_request:')));
    expect(workflow, contains(r'[[ "$GITHUB_REF" != "refs/heads/master" ]]'));
  });

  test('Firebase Test Lab 工作流使用 OIDC 和专用 Patrol 测试目标', () {
    final workflow = File(
      '.github/workflows/firebase-test-lab.yml',
    ).readAsStringSync();

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
    expect(workflow, contains(r'vars.GCP_WORKLOAD_IDENTITY_PROVIDER'));
    expect(workflow, contains(r'vars.GCP_SERVICE_ACCOUNT'));
    expect(workflow, isNot(contains('credentials_json')));
    expect(
      workflow,
      contains('--target patrol_test/recording_continuity_test.dart'),
    );
    expect(workflow, contains('default: MediumPhone.arm'));
    expect(workflow, contains('--timeout 45m'));
    expect(workflow, isNot(contains('--use-orchestrator')));
  });
}
