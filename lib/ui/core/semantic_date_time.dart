import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';

/// 为时间账本提供紧凑、可扫描的日期标签。
///
/// 今天和临近日期优先使用相对语义；较早日期保留足够的日历信息，同时控制
/// 在账本时间列内的长度。
String semanticCompactDateLabel(
  DateTime value, {
  required DateTime reference,
  required AppLocalizations l10n,
}) {
  final localValue = value.toLocal();
  final localReference = reference.toLocal();
  final date = _dateOnly(localValue);
  final today = _dateOnly(localReference);
  final difference = date.difference(today).inDays;

  if (difference == 0) {
    return l10n.today;
  }
  if (difference == -1) {
    return l10n.yesterday;
  }
  if (difference == 1) {
    return l10n.tomorrow;
  }

  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  if (!date.isBefore(weekStart) && date.isBefore(today)) {
    return DateFormat.E(l10n.localeName).format(date);
  }
  if (date.year == today.year) {
    return DateFormat.MMMd(l10n.localeName).format(date);
  }

  return DateFormat.yMd(l10n.localeName).format(date);
}

/// 用于详情预览的完整语义日期时间。
String semanticDateTimeLabel(
  DateTime value, {
  required DateTime reference,
  required AppLocalizations l10n,
}) {
  final localValue = value.toLocal();
  final localReference = reference.toLocal();
  final compact = semanticCompactDateLabel(
    localValue,
    reference: localReference,
    l10n: l10n,
  );
  final date = _dateOnly(localValue);
  final today = _dateOnly(localReference);
  final difference = date.difference(today).inDays;
  final isRelative =
      difference == 0 ||
      difference == -1 ||
      difference == 1 ||
      (!date.isBefore(today.subtract(Duration(days: today.weekday - 1))) &&
          date.isBefore(today));
  final dateLabel = isRelative
      ? compact
      : DateFormat.yMMMMd(l10n.localeName).format(date);
  return '$dateLabel ${clockTimeLabel(localValue, locale: l10n.localeName)}';
}

String clockTimeLabel(DateTime value, {String? locale}) {
  final localValue = value.toLocal();
  if (locale != null) {
    return DateFormat.jm(locale).format(localValue);
  }
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(localValue.hour)}:${two(localValue.minute)}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
