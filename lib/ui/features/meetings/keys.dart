import 'package:flutter/widgets.dart';

class _MeetingsKey extends ValueKey<String> {
  const _MeetingsKey(super.value);
}

final class MeetingsKeys {
  const MeetingsKeys();

  final detailAudioDuration = const _MeetingsKey(
    'meeting-detail-audio-duration',
  );
  final detailTitle = const _MeetingsKey('meeting-detail-title');
  final listBrandMark = const _MeetingsKey('meeting-list-brand-mark');
  final listBrandTitle = const _MeetingsKey('meeting-list-brand-title');
  final listRecordingConditions = const _MeetingsKey(
    'meeting-list-recording-conditions',
  );
  final listStartMeeting = const _MeetingsKey('meeting-list-start-meeting');
  final recordingConditionsAction = const _MeetingsKey(
    'recording-conditions-action',
  );
  final recordingConditionMicrophoneStatus = const _MeetingsKey(
    'recording-condition-microphone-status',
  );
  final recordingEndButton = const _MeetingsKey('recording-end-button');
  final recordingEndConfirm = const _MeetingsKey('recording-end-confirm');
  final recordingEndReady = const _MeetingsKey('recording-end-ready');
  final recordingElapsedDuration = const _MeetingsKey(
    'recording-elapsed-duration',
  );
  final recordingPauseReady = const _MeetingsKey('recording-pause-ready');
  final recordingResumeReady = const _MeetingsKey('recording-resume-ready');
  final recordingTitle = const _MeetingsKey('recording-title');
}
