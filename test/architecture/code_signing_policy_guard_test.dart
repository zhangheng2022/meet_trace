import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('仓库首页与发布说明公开 SignPath 要求的 Code signing policy', () async {
    final readme = await File('README.md').readAsString();
    final policy = await File('CODE_SIGNING_POLICY.md').readAsString();
    final workflow = await File('.github/workflows/alpha-release.yml')
        .readAsString();

    expect(readme, contains('Code signing policy'));
    expect(readme, contains('CODE_SIGNING_POLICY.md'));
    expect(workflow, contains('Code signing policy'));
    expect(
      policy,
      contains(
        'Free code signing provided by [SignPath.io]'
        '(https://about.signpath.io/), certificate by '
        '[SignPath Foundation](https://signpath.org/).',
      ),
    );
    expect(policy, contains('https://github.com/zhangheng2022'));
    expect(policy, contains('[隐私政策](PRIVACY.md)'));
    expect(policy, contains('SENTRY_ENABLED=false'));
    expect(policy, contains('不允许用自签名包、未签名包或个人 PFX 进行公开分发'));
  });

  test('隐私政策公开网络边界、Sentry 差异与数据删除方式', () async {
    final privacy = await File('PRIVACY.md').readAsString();

    expect(privacy, contains('mt.zhangheng.eu.org'));
    expect(privacy, contains('Sentry'));
    expect(privacy, contains('SignPath'));
    expect(privacy, contains('删除会议'));
    expect(privacy, contains('卸载'));
    expect(privacy, contains('不会上传事实 PCM'));
  });
}
