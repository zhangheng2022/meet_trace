import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/asr_model_registry.dart';
import '../../../../../../domain/models/meeting.dart';
import '../../../../../../domain/models/workflow_states.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_state_panel.dart';
import '../../../../../core/semantic_date_time.dart';
import 'meeting_list_formatters.dart';

final class MeetingPreviewPlaceholder extends StatelessWidget {
  const MeetingPreviewPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStatePanel.empty(
      icon: FLucideIcons.fileAudio,
      title: context.l10n.selectMeeting,
      message: context.l10n.selectMeetingDescription,
    );
  }
}

final class MeetingPreviewPane extends StatelessWidget {
  const MeetingPreviewPane({
    required this.meeting,
    required this.referenceTime,
    required this.onOpenMeeting,
    super.key,
  });

  final Meeting meeting;
  final DateTime referenceTime;
  final ValueChanged<Meeting>? onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final appStyle = theme.style.app;
    return ColoredBox(
      color: theme.colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(appStyle.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.display.xl,
                  ),
                  SizedBox(height: appStyle.spaceMd),
                  _MeetingPreviewStatus(meeting: meeting),
                  SizedBox(height: appStyle.spaceLg),
                  _MeetingFactRow(
                    icon: FLucideIcons.calendar,
                    label: l10n.startTime,
                    value: semanticDateTimeLabel(
                      meeting.createdAt,
                      reference: referenceTime,
                      l10n: l10n,
                    ),
                  ),
                  _MeetingFactRow(
                    icon: FLucideIcons.clock4,
                    label: l10n.recordingDuration,
                    value: meetingDurationLabel(
                      Duration(milliseconds: meeting.audioDurationMs),
                    ),
                  ),
                  _MeetingFactRow(
                    icon: FLucideIcons.fileAudio,
                    label: l10n.sourceAudio,
                    value: _audioFactLabel(l10n, meeting),
                  ),
                  _MeetingFactRow(
                    icon: FLucideIcons.settings,
                    label: l10n.meetingModel,
                    value: _modelDisplayLabel(l10n, meeting),
                  ),
                  SizedBox(height: appStyle.spaceLg),
                  Text(l10n.meetingFacts, style: theme.typography.display.lg),
                  SizedBox(height: appStyle.spaceSm),
                  Text(
                    _meetingFactDescription(l10n, meeting),
                    style: theme.typography.body.md.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                  SizedBox(height: appStyle.spaceLg),
                  _OpenMeetingRow(
                    enabled: onOpenMeeting != null,
                    onPress: onOpenMeeting == null
                        ? null
                        : () => onOpenMeeting!(meeting),
                  ),
                ],
              ),
            ),
          ),
          _PreviewBottomStatus(
            recording: meeting.status == MeetingState.recording,
          ),
        ],
      ),
    );
  }
}

final class _MeetingPreviewStatus extends StatelessWidget {
  const _MeetingPreviewStatus({required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colors.border,
          width: appStyle.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(appStyle.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceSm,
          vertical: appStyle.spaceXs,
        ),
        child: Row(
          children: [
            if (meeting.status == MeetingState.recording)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.foreground,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 8),
              )
            else
              Icon(meetingStatusIcon(meeting.status), size: 16),
            SizedBox(width: appStyle.spaceXs),
            Text(
              meetingStatusLabel(context.l10n, meeting.status),
              style: theme.typography.body.sm.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: appStyle.spaceSm),
            Container(
              width: appStyle.dividerWidth,
              height: 16,
              color: theme.colors.border,
            ),
            SizedBox(width: appStyle.spaceSm),
            Text(
              meetingDurationLabel(
                Duration(milliseconds: meeting.audioDurationMs),
              ),
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                meeting.status == MeetingState.recording
                    ? l10n.liveTranscriptReferenceOnly
                    : l10n.sourceAudioLocalFirst,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _MeetingFactRow extends StatelessWidget {
  const _MeetingFactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: appStyle.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19),
            SizedBox(width: appStyle.spaceMd),
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: theme.typography.body.sm.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: appStyle.spaceSm),
            Expanded(child: Text(value, style: theme.typography.body.sm)),
          ],
        ),
      ),
    );
  }
}

final class _OpenMeetingRow extends StatelessWidget {
  const _OpenMeetingRow({required this.enabled, required this.onPress});

  final bool enabled;
  final VoidCallback? onPress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: appStyle.spaceMd),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.openFullRecord,
                style: theme.typography.body.md.copyWith(
                  color: enabled
                      ? theme.colors.foreground
                      : theme.colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              FLucideIcons.chevronRight,
              size: 19,
              color: theme.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
    if (!enabled) {
      return content;
    }
    return FTappable(
      key: const ValueKey('open-selected-meeting'),
      semanticsLabel: context.l10n.openFullMeetingRecord,
      onPress: onPress,
      child: content,
    );
  }
}

final class _PreviewBottomStatus extends StatelessWidget {
  const _PreviewBottomStatus({required this.recording});

  final bool recording;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: appStyle.spaceLg,
            vertical: appStyle.spaceSm,
          ),
          child: Row(
            children: [
              const Icon(FLucideIcons.shieldCheck, size: 17),
              SizedBox(width: appStyle.spaceXs),
              Expanded(child: Text(context.l10n.sourceAudioLocalFirst)),
              if (recording)
                Text(
                  context.l10n.recordingContinues,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _audioFactLabel(AppLocalizations l10n, Meeting meeting) =>
    switch (meeting.status) {
      MeetingState.created => l10n.audioNotStarted,
      MeetingState.recording => l10n.audioWritingLocally,
      _ when meeting.audioPath?.isNotEmpty == true => l10n.audioSavedLocally,
      MeetingState.processing => l10n.audioSealing,
      MeetingState.completed => l10n.meetingProcessingCompleted,
      MeetingState.failed => l10n.openMeetingForSaveStatus,
    };

String _meetingFactDescription(AppLocalizations l10n, Meeting meeting) =>
    switch (meeting.status) {
      MeetingState.created => l10n.factCreatedDescription,
      MeetingState.recording => l10n.factRecordingDescription,
      MeetingState.processing => l10n.factProcessingDescription,
      MeetingState.completed when meeting.activeTranscriptSnapshotId != null =>
        l10n.factFinalReadyDescription,
      MeetingState.completed => l10n.factCompletedDescription,
      MeetingState.failed when meeting.audioPath?.isNotEmpty == true =>
        l10n.factDerivedFailedDescription,
      MeetingState.failed => l10n.factMeetingFailedDescription,
    };

String _modelDisplayLabel(AppLocalizations l10n, Meeting meeting) {
  final descriptor = AsrModelRegistry.alpha.findById(meeting.recordingModelId);
  final displayName = descriptor?.displayName ?? l10n.localModel;
  return '$displayName · ${meeting.recordingModelVersion}';
}
