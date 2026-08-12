import 'package:meettrace/keys.dart';
// 模块直接调用 Patrol API；显式导入便于 API 归属和后续升级检查。
// ignore: unused_import
import 'package:patrol/patrol.dart';

import 'module.dart';

final class Meetings extends Module {
  const Meetings(super.$);

  Future<void> endAndSaveMeeting() async {
    await $(keys.meetings.recordingEndReady).tap();
    await $(keys.meetings.recordingEndConfirm).tap();
  }

  Future<void> dismissRecordingConditions() async {
    await $.platform.android.pressBack();
  }

  Future<void> expectDetailVisible() async {
    await $(keys.meetings.detailTitle).waitUntilVisible();
  }

  Future<void> expectDetailAudioDurationAtLeast(Duration minimum) async {
    final durationLabel = (await $(
      keys.meetings.detailAudioDuration,
    ).waitUntilVisible()).text!;
    final duration = _parseClockDuration(durationLabel.split(' · ')[1]);
    if (duration < minimum) {
      throw StateError('事实音频时长不足 ${minimum.inSeconds} 秒：$durationLabel');
    }
  }

  Future<void> expectRecordingDurationAdvancedBy({
    required Duration before,
    required Duration minimum,
  }) async {
    Duration current = Duration.zero;
    for (var attempt = 0; attempt < 20; attempt++) {
      current = await recordingDuration();
      if (current - before >= minimum) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError(
      '后台期间事实音频仅增长 '
      '${(current - before).inMilliseconds}ms，预期至少 '
      '${minimum.inMilliseconds}ms',
    );
  }

  Future<void> expectHomeVisible() async {
    await $(keys.meetings.listBrandMark).waitUntilVisible();
  }

  Future<void> expectMicrophonePermissionGranted(bool expected) async {
    final label = (await $(
      keys.meetings.recordingConditionMicrophoneStatus,
    ).waitUntilVisible()).text;
    final expectedLabel = expected ? '已授权' : '待授权';
    if (label != expectedLabel) {
      throw StateError('麦克风权限状态为 $label，预期为 $expectedLabel');
    }
  }

  Future<void> openRecordingConditions() async {
    await $(keys.meetings.listRecordingConditions).tap();
  }

  Future<bool> isMicrophonePermissionGranted() async {
    final label = (await $(
      keys.meetings.recordingConditionMicrophoneStatus,
    ).waitUntilVisible()).text;
    return label == '已授权';
  }

  Future<void> pauseRecording() async {
    await $(keys.meetings.recordingPauseReady).tap();
  }

  Future<void> requestMicrophonePermission() async {
    await $(keys.meetings.recordingConditionsAction).tap();
  }

  Future<Duration> recordingDuration() async {
    final durationLabel = (await $(
      keys.meetings.recordingElapsedDuration,
    ).waitUntilVisible()).text!;
    return _parseClockDuration(durationLabel);
  }

  Future<void> resumeRecording() async {
    await $(keys.meetings.recordingResumeReady).tap();
  }

  Future<void> startMeeting() async {
    await $(keys.meetings.listStartMeeting).tap();
  }

  Duration _parseClockDuration(String label) {
    final parts = label.split(':');
    return Duration(
      seconds: parts.fold<int>(
        0,
        (total, part) => total * 60 + int.parse(part),
      ),
    );
  }
}
