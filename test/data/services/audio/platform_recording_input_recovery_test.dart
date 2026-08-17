import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/platform_recording_input_recovery.dart';

void main() {
  test('只有 Windows 启用一次系统默认输入回退', () {
    expect(
      createRecordingInputRecoveryPlanner(
        platform: RecordingInputRecoveryPlatform.windows,
      ),
      isNotNull,
    );
    expect(
      createRecordingInputRecoveryPlanner(
        platform: RecordingInputRecoveryPlatform.android,
      ),
      isNull,
    );
    expect(
      createRecordingInputRecoveryPlanner(
        platform: RecordingInputRecoveryPlatform.ios,
      ),
      isNull,
    );
  });
}
