import 'dart:io';

import '../../../domain/use_cases/lock_recording_input.dart';

enum RecordingInputRecoveryPlatform { android, ios, windows }

PlanRecordingInputRecoveryUseCase? createRecordingInputRecoveryPlanner({
  RecordingInputRecoveryPlatform? platform,
}) {
  final resolved = platform ?? _currentPlatform();
  return switch (resolved) {
    RecordingInputRecoveryPlatform.windows =>
      const PlanRecordingInputRecoveryUseCase(),
    RecordingInputRecoveryPlatform.android ||
    RecordingInputRecoveryPlatform.ios => null,
  };
}

RecordingInputRecoveryPlatform _currentPlatform() {
  if (Platform.isWindows) {
    return RecordingInputRecoveryPlatform.windows;
  }
  if (Platform.isAndroid) {
    return RecordingInputRecoveryPlatform.android;
  }
  if (Platform.isIOS) {
    return RecordingInputRecoveryPlatform.ios;
  }
  throw UnsupportedError('当前平台不支持录音输入恢复');
}
