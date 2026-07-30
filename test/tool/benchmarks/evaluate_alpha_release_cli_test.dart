import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/evaluate_alpha_release.dart';

void main() {
  test('发布评估 CLI 支持命名参数和兼容位置参数', () {
    final named = parseEvaluateAlphaReleaseArguments([
      '--input',
      'input.json',
      '--output',
      'output.json',
    ]);
    final positional = parseEvaluateAlphaReleaseArguments([
      'input.json',
      'output.json',
    ]);

    expect(named?.input, 'input.json');
    expect(named?.output, 'output.json');
    expect(positional?.input, 'input.json');
    expect(positional?.output, 'output.json');
    expect(parseEvaluateAlphaReleaseArguments(const []), isNull);
    expect(parseEvaluateAlphaReleaseArguments(const ['--input']), isNull);
  });
}
