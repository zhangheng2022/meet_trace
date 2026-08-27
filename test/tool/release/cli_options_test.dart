import 'package:flutter_test/flutter_test.dart';

import '../../../tool/release/cli_options.dart';

void main() {
  test('解析成对参数并拒绝缺值、重复和空白必填项', () {
    expect(parseCliOptions(['--input', 'receipt.json']), {
      'input': 'receipt.json',
    });
    expect(() => parseCliOptions(['--input']), throwsA(isA<FormatException>()));
    expect(
      () => parseCliOptions(['--input', '--output']),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseCliOptions(['--input', 'a', '--input', 'b']),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => requireCliOption({'input': '  '}, 'input'),
      throwsA(isA<FormatException>()),
    );
  });
}
