import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../keys.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../l10n/ui_message_localizations.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_page_body.dart';
import '../../../../../core/app_responsive.dart';
import '../../../../../core/app_status_notice.dart';
import '../../../view_models/detail/meeting_detail_view_model.dart';
import '../audio/meeting_audio_actions.dart';
import '../transcript/meeting_transcript_section.dart';
import 'meeting_detail_formatters.dart';

final class MeetingResultView extends StatelessWidget {
  const MeetingResultView({
    required this.viewModel,
    required this.transcriptKey,
    required this.editingTranscript,
    required this.onEditingChanged,
    super.key,
  });

  final MeetingDetailViewModel viewModel;
  final GlobalKey<TranscriptSectionState> transcriptKey;
  final bool editingTranscript;
  final ValueChanged<bool> onEditingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final snapshot = viewModel.snapshot!;
    final workbench = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.errorMessage case final message?) ...[
          AppStatusNotice(
            tone: AppStatusTone.error,
            title: context.l10n.lastProcessingIncomplete,
            message: context.l10n.localizeUiMessage(message),
          ),
          SizedBox(height: appStyle.spaceMd),
        ],
        TranscriptSection(
          key: transcriptKey,
          snapshot: snapshot,
          viewModel: viewModel,
          editing: editingTranscript,
          onEditingChanged: onEditingChanged,
        ),
        if (viewModel.resultMessage case final message?) ...[
          SizedBox(height: appStyle.spaceLg),
          AppStatusNotice(
            tone: AppStatusTone.info,
            title: context.l10n.operationStatus,
            message: context.l10n.localizeUiMessage(message),
          ),
        ],
        SizedBox(height: appStyle.spaceXl),
        DiarizationSection(viewModel: viewModel, editing: editingTranscript),
      ],
    );
    return SingleChildScrollView(
      child: AppPageBody(
        width: AppPageWidth.wide,
        child: AppResponsiveBuilder(
          builder: (context, sizeClass, constraints) {
            if (sizeClass != AppWindowSizeClass.expanded) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: appStyle.readingContentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MeetingIdentity(viewModel: viewModel),
                    SizedBox(height: appStyle.spaceLg),
                    AudioEvidenceStrip(viewModel: viewModel),
                    SizedBox(height: appStyle.spaceXl),
                    workbench,
                  ],
                ),
              );
            }
            return Row(
              key: const ValueKey('meeting-detail-audio-workbench'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: appStyle.factRailWidth,
                  child: _MeetingFactRail(viewModel: viewModel),
                ),
                SizedBox(width: appStyle.spaceXl),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: appStyle.readingContentMaxWidth,
                    ),
                    child: workbench,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class MeetingIdentity extends StatelessWidget {
  const MeetingIdentity({required this.viewModel, super.key});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(viewModel.meeting.title, style: theme.typography.display.lg),
        SizedBox(height: appStyle.spaceSm),
        Text(
          key: keys.meetings.detailAudioDuration,
          '${_dateLabel(viewModel.meeting.createdAt)} · '
          '${meetingDurationLabel(viewModel.meeting.audioDurationMs)} · '
          '${viewModel.sourceModel.displayName}',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

final class _MeetingFactRail extends StatelessWidget {
  const _MeetingFactRail({required this.viewModel});

  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.factRecord, style: theme.typography.body.xs),
        SizedBox(height: appStyle.spaceLg),
        MeetingIdentity(viewModel: viewModel),
        SizedBox(height: appStyle.spaceLg),
        AudioEvidenceStrip(viewModel: viewModel, compact: true),
        SizedBox(height: appStyle.spaceLg),
        AppStatusNotice(
          tone: AppStatusTone.success,
          title: context.l10n.sourceAudioSaved,
          message: context.l10n.sourceAudioTimestampVerification,
        ),
      ],
    );
  }
}

final class MeetingFailureView extends StatelessWidget {
  const MeetingFailureView({
    required this.message,
    required this.viewModel,
    super.key,
  });

  final String message;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return SingleChildScrollView(
      child: AppPageBody(
        width: AppPageWidth.reading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MeetingIdentity(viewModel: viewModel),
            SizedBox(height: appStyle.spaceLg),
            AudioEvidenceStrip(viewModel: viewModel),
            SizedBox(height: appStyle.spaceXl),
            _FailureCard(message: message, viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

final class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message, required this.viewModel});

  final String message;
  final MeetingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return FAlert(
      variant: FAlertVariant.destructive,
      title: Text(context.l10n.finalTranscriptIncomplete),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.localizeUiMessage(message)),
          if (viewModel.canRetry) ...[
            SizedBox(height: appStyle.spaceMd),
            FButton(
              onPress: () => unawaited(viewModel.retry()),
              child: Text(context.l10n.retryFinalTranscript),
            ),
          ],
        ],
      ),
    );
  }
}
