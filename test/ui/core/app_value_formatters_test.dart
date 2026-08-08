import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/ui/core/app_value_formatters.dart';

void main() {
  test('按 B、KiB、MiB 格式化存储空间', () {
    expect(formatStorageBytes(512), '512 B');
    expect(formatStorageBytes(1536), '1.5 KiB');
    expect(formatStorageBytes(1572864), '1.5 MiB');
  });
}
