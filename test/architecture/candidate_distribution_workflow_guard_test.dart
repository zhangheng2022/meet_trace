import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('候选分发验证允许来源工作流提交晚于不可变候选', () async {
    final workflow = await File(
      '.github/workflows/candidate-distribution-validation.yml',
    ).readAsString();

    expect(workflow, contains('.headBranch == "master"'));
    expect(
      workflow,
      contains(
        r'git merge-base --is-ancestor "$CANDIDATE_SHA" "$source_head_sha"',
      ),
    );
    expect(workflow, isNot(contains(r'.headSha == $sha')));
  });
}
