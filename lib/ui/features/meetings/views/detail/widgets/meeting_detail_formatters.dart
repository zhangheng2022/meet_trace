String meetingTimestampLabel(int milliseconds) =>
    _timeLabel(Duration(milliseconds: milliseconds));

String meetingDurationLabel(int milliseconds) =>
    _timeLabel(Duration(milliseconds: milliseconds));

String _timeLabel(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
