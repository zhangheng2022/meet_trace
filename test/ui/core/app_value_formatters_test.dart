import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/ui/core/app_value_formatters.dart';

void main() {
  test('按 B、KiB、MiB 格式化存储空间', () {
    expect(formatStorageBytes(512), '512 B');
    expect(formatStorageBytes(1536), '1.5 KiB');
    expect(formatStorageBytes(1572864), '1.5 MiB');
  });

  test('紧凑时长仅在跨小时后显示小时', () {
    expect(
      formatClockDuration(const Duration(minutes: 1, seconds: 5)),
      '01:05',
    );
    expect(
      formatClockDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '2:03:04',
    );
  });

  test('固定小时格式始终使用两位小时', () {
    expect(
      formatClockDuration(
        const Duration(minutes: 1, seconds: 5),
        alwaysShowHours: true,
      ),
      '00:01:05',
    );
    expect(
      formatClockDuration(
        const Duration(hours: 2, minutes: 3, seconds: 4),
        alwaysShowHours: true,
      ),
      '02:03:04',
    );
  });
}
