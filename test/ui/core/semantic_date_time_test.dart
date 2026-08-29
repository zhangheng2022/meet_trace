import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meettrace/l10n/l10n.dart';
import 'package:meettrace/ui/core/semantic_date_time.dart';

void main() {
  setUpAll(initializeDateFormatting);

  test('中英文日期覆盖相对、本周、同年和跨年分支', () {
    final reference = DateTime(2026, 8, 12, 9);
    final chinese = lookupAppLocalizations(const Locale('zh'));
    final english = lookupAppLocalizations(const Locale('en'));

    expect(
      semanticCompactDateLabel(reference, reference: reference, l10n: chinese),
      '今天',
    );
    expect(
      semanticCompactDateLabel(
        DateTime(2026, 8, 11),
        reference: reference,
        l10n: english,
      ),
      'Yesterday',
    );
    expect(
      semanticCompactDateLabel(
        DateTime(2026, 8, 13),
        reference: reference,
        l10n: chinese,
      ),
      '明天',
    );
    expect(
      semanticCompactDateLabel(
        DateTime(2026, 8, 10),
        reference: reference,
        l10n: english,
      ),
      'Mon',
    );
    expect(
      semanticCompactDateLabel(
        DateTime(2026, 7, 10),
        reference: reference,
        l10n: chinese,
      ),
      '7月10日',
    );
    expect(
      semanticCompactDateLabel(
        DateTime(2025, 12, 31),
        reference: reference,
        l10n: english,
      ),
      '12/31/2025',
    );
  });

  test('完整语义日期时间遵循当前语言', () {
    final reference = DateTime(2026, 8, 12, 9);
    final english = lookupAppLocalizations(const Locale('en'));

    expect(
      semanticDateTimeLabel(
        DateTime(2026, 8, 12, 14, 30),
        reference: reference,
        l10n: english,
      ),
      allOf(contains('Today'), contains('2:30')),
    );
    expect(
      semanticDateTimeLabel(
        DateTime(2025, 8, 10, 14, 30),
        reference: reference,
        l10n: english,
      ),
      contains('August 10, 2025'),
    );
    expect(clockTimeLabel(DateTime(2026, 8, 12, 4, 5)), '04:05');
  });
}
