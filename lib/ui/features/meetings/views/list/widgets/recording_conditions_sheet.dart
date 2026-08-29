import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../domain/models/meeting_readiness.dart';
import '../../../../../../keys.dart';
import '../../../../../../l10n/l10n.dart';
import '../../../../../../theme/theme.dart';
import '../../../../../core/app_sheet.dart';
import '../../../view_models/list/meeting_list_view_model.dart';

enum RecordingConditionsAction {
  requestMicrophonePermission,
  recheck,
  repairRuntime,
}

final class RecordingConditionsSheet extends StatelessWidget {
  const RecordingConditionsSheet({
    required this.readiness,
    required this.canRepairRuntime,
    super.key,
  });

  final MeetingReadinessViewState readiness;
  final bool canRepairRuntime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final action = _action;
    return AppSheetSurface(
      surfaceKey: const ValueKey('recording-conditions-sheet-surface'),
      title: l10n.recordingConditionsTitle,
      description: l10n.recordingConditionsDescription,
      semanticsLabel: l10n.recordingConditionsDetails,
      footer: action == null
          ? null
          : SizedBox(
              width: double.infinity,
              child: FButton(
                key: keys.meetings.recordingConditionsAction,
                size: FButtonSizeVariant.lg,
                onPress: () => Navigator.of(context).pop(action),
                child: Text(_actionLabel(l10n, action)),
              ),
            ),
      child: FTileGroup(
        semanticsLabel: l10n.recordingConditionsStatus,
        children: [
          _conditionTile(
            context: context,
            key: const ValueKey('recording-condition-microphone'),
            icon: FLucideIcons.mic,
            title: l10n.microphonePermission,
            detail: readiness.microphonePermissionGranted == true
                ? l10n.canRecordMeetingAudio
                : l10n.meetingNotCreatedBeforePermission,
            available: readiness.microphonePermissionGranted == true,
            availableLabel: l10n.authorized,
            unavailableLabel: l10n.awaitingAuthorization,
            statusKey: keys.meetings.recordingConditionMicrophoneStatus,
          ),
          _conditionTile(
            context: context,
            key: const ValueKey('recording-condition-storage'),
            icon: FLucideIcons.hardDrive,
            title: l10n.localStorage,
            detail: _storageDetail(l10n, readiness.freeBytes),
            available:
                readiness.freeBytes != null &&
                readiness.freeBytes! >= minimumRecordingFreeBytes,
            availableLabel: l10n.spaceAvailable,
            unavailableLabel: l10n.spaceInsufficient,
          ),
          _conditionTile(
            context: context,
            key: const ValueKey('recording-condition-model'),
            icon: FLucideIcons.audioLines,
            title: l10n.offlineTranscription,
            detail: l10n.modelUsedForMeeting(
              readiness.defaultModelName ?? l10n.defaultModel,
            ),
            available: readiness.defaultModelAvailable == true,
            availableLabel: l10n.available,
            unavailableLabel: l10n.needsRepair,
          ),
        ],
      ),
    );
  }

  RecordingConditionsAction? get _action => switch (readiness.status) {
    MeetingReadinessStatus.microphonePermissionRequired =>
      RecordingConditionsAction.requestMicrophonePermission,
    MeetingReadinessStatus.storageInsufficient =>
      RecordingConditionsAction.recheck,
    MeetingReadinessStatus.defaultModelUnavailable when canRepairRuntime =>
      RecordingConditionsAction.repairRuntime,
    MeetingReadinessStatus.defaultModelUnavailable =>
      RecordingConditionsAction.recheck,
    MeetingReadinessStatus.unchecked ||
    MeetingReadinessStatus.checking ||
    MeetingReadinessStatus.ready ||
    MeetingReadinessStatus.failed => null,
  };
}

FTile _conditionTile({
  required BuildContext context,
  required Key key,
  required IconData icon,
  required String title,
  required String detail,
  required bool available,
  required String availableLabel,
  required String unavailableLabel,
  Key? statusKey,
}) => FTile(
  key: key,
  prefix: Icon(icon),
  title: Text(title),
  subtitle: Text(detail),
  suffix: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        available ? FLucideIcons.circleCheck : FLucideIcons.circleAlert,
        size: 16,
      ),
      SizedBox(width: context.theme.style.app.space2Xs),
      Text(available ? availableLabel : unavailableLabel, key: statusKey),
    ],
  ),
);

String _storageDetail(AppLocalizations l10n, int? freeBytes) {
  final minimum = _readinessByteLabel(minimumRecordingFreeBytes);
  if (freeBytes == null) {
    return l10n.minimumStorageRequired(minimum);
  }
  return l10n.availableStorageMinimum(_readinessByteLabel(freeBytes), minimum);
}

String _readinessByteLabel(int bytes) {
  const gib = 1024 * 1024 * 1024;
  const mib = 1024 * 1024;
  if (bytes >= gib) {
    return '${(bytes / gib).toStringAsFixed(2)} GiB';
  }
  return '${(bytes / mib).toStringAsFixed(1)} MiB';
}

String _actionLabel(AppLocalizations l10n, RecordingConditionsAction action) =>
    switch (action) {
      RecordingConditionsAction.requestMicrophonePermission =>
        l10n.authorizeMicrophone,
      RecordingConditionsAction.recheck => l10n.recheck,
      RecordingConditionsAction.repairRuntime => l10n.repairOfflineResources,
    };
