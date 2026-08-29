import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../core/app_value_formatters.dart';

IconData meetingStatusIcon(MeetingState state) => switch (state) {
  MeetingState.created => FLucideIcons.circleDashed,
  MeetingState.recording => FLucideIcons.square,
  MeetingState.processing => FLucideIcons.audioLines,
  MeetingState.completed => FLucideIcons.circleCheck,
  MeetingState.failed => FLucideIcons.circleAlert,
};

String meetingStatusLabel(AppLocalizations l10n, MeetingState state) =>
    switch (state) {
      MeetingState.created => l10n.meetingStatusPreparing,
      MeetingState.recording => l10n.meetingStatusRecording,
      MeetingState.processing => l10n.meetingStatusProcessing,
      MeetingState.completed => l10n.meetingStatusCompleted,
      MeetingState.failed => l10n.meetingStatusFailed,
    };

String meetingLedgerStatus(AppLocalizations l10n, Meeting meeting) =>
    switch (meeting.status) {
      MeetingState.created => l10n.meetingStatusPreparing,
      MeetingState.recording => l10n.meetingStatusRecording,
      MeetingState.processing => l10n.meetingStatusGeneratingFinal,
      MeetingState.completed => l10n.meetingStatusCompleted,
      MeetingState.failed when meeting.audioPath?.isNotEmpty == true =>
        l10n.meetingStatusProcessingFailed,
      MeetingState.failed => l10n.meetingStatusFailedAudioHint,
    };

String meetingDurationLabel(Duration value) =>
    formatClockDuration(value, alwaysShowHours: true);
