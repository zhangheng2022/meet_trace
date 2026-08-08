String formatStorageBytes(int bytes) {
  const kib = 1024;
  const mib = kib * 1024;
  if (bytes >= mib) {
    return '${(bytes / mib).toStringAsFixed(1)} MiB';
  }
  if (bytes >= kib) {
    return '${(bytes / kib).toStringAsFixed(1)} KiB';
  }
  return '$bytes B';
}

String formatClockDuration(Duration duration, {bool alwaysShowHours = false}) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (alwaysShowHours) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
