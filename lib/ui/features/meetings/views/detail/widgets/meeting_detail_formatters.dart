import '../../../../../core/app_value_formatters.dart';

String meetingTimestampLabel(int milliseconds) =>
    formatClockDuration(Duration(milliseconds: milliseconds));

String meetingDurationLabel(int milliseconds) =>
    formatClockDuration(Duration(milliseconds: milliseconds));
