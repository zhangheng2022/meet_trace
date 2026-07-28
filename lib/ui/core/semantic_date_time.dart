const _weekdayLabels = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 为时间账本提供紧凑、可扫描的日期标签。
///
/// 今天和临近日期优先使用相对语义；较早日期保留足够的日历信息，同时控制
/// 在账本时间列内的长度。
String semanticCompactDateLabel(DateTime value, {required DateTime reference}) {
  final localValue = value.toLocal();
  final localReference = reference.toLocal();
  final date = _dateOnly(localValue);
  final today = _dateOnly(localReference);
  final difference = date.difference(today).inDays;

  if (difference == 0) {
    return '今天';
  }
  if (difference == -1) {
    return '昨天';
  }
  if (difference == 1) {
    return '明天';
  }

  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  if (!date.isBefore(weekStart) && date.isBefore(today)) {
    return _weekdayLabels[date.weekday - 1];
  }
  if (date.year == today.year) {
    return '${date.month}月${date.day}日';
  }

  final shortYear = (date.year % 100).toString().padLeft(2, '0');
  return '$shortYear/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';
}

/// 用于详情预览的完整语义日期时间。
String semanticDateTimeLabel(DateTime value, {required DateTime reference}) {
  final localValue = value.toLocal();
  final localReference = reference.toLocal();
  final compact = semanticCompactDateLabel(
    localValue,
    reference: localReference,
  );
  final date = _dateOnly(localValue);
  final today = _dateOnly(localReference);
  final isRelative =
      compact == '今天' ||
      compact == '昨天' ||
      compact == '明天' ||
      (!date.isBefore(today.subtract(Duration(days: today.weekday - 1))) &&
          date.isBefore(today));
  final dateLabel = isRelative
      ? compact
      : '${date.year}年${date.month}月${date.day}日';
  return '$dateLabel ${clockTimeLabel(localValue)}';
}

String clockTimeLabel(DateTime value) {
  final localValue = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(localValue.hour)}:${two(localValue.minute)}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
