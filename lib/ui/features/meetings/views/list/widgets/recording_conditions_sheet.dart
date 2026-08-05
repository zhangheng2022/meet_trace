part of '../meeting_list_view.dart';

enum _RecordingConditionsAction {
  requestMicrophonePermission,
  recheck,
  repairRuntime,
}

final class _RecordingConditionsSheet extends StatelessWidget {
  const _RecordingConditionsSheet({
    required this.readiness,
    required this.canRepairRuntime,
  });

  final MeetingReadinessViewState readiness;
  final bool canRepairRuntime;

  @override
  Widget build(BuildContext context) {
    final action = _action;
    return AppSheetSurface(
      surfaceKey: const ValueKey('recording-conditions-sheet-surface'),
      title: '录音条件',
      description: '开始会议前会再次检查；录音和转录资源只保存在本机。',
      semanticsLabel: '录音条件详情',
      footer: action == null
          ? null
          : SizedBox(
              width: double.infinity,
              child: FButton(
                key: const ValueKey('recording-conditions-action'),
                size: FButtonSizeVariant.lg,
                onPress: () => Navigator.of(context).pop(action),
                child: Text(_actionLabel(action)),
              ),
            ),
      child: FTileGroup(
        semanticsLabel: '录音条件状态',
        children: [
          _conditionTile(
            context: context,
            key: const ValueKey('recording-condition-microphone'),
            icon: FLucideIcons.mic,
            title: '麦克风权限',
            detail: readiness.microphonePermissionGranted == true
                ? '应用可以录制会议音频'
                : '授权前不会创建会议',
            available: readiness.microphonePermissionGranted == true,
            availableLabel: '已授权',
            unavailableLabel: '待授权',
          ),
          _conditionTile(
            context: context,
            key: const ValueKey('recording-condition-storage'),
            icon: FLucideIcons.hardDrive,
            title: '本地存储',
            detail: _storageDetail(readiness.freeBytes),
            available:
                readiness.freeBytes != null &&
                readiness.freeBytes! >= minimumRecordingFreeBytes,
            availableLabel: '空间充足',
            unavailableLabel: '空间不足',
          ),
          _conditionTile(
            context: context,
            key: const ValueKey('recording-condition-model'),
            icon: FLucideIcons.audioLines,
            title: '离线转录',
            detail: '${readiness.defaultModelName ?? '默认模型'}用于会中与最终转录',
            available: readiness.defaultModelAvailable == true,
            availableLabel: '可用',
            unavailableLabel: '需修复',
          ),
        ],
      ),
    );
  }

  _RecordingConditionsAction? get _action => switch (readiness.status) {
    MeetingReadinessStatus.microphonePermissionRequired =>
      _RecordingConditionsAction.requestMicrophonePermission,
    MeetingReadinessStatus.storageInsufficient =>
      _RecordingConditionsAction.recheck,
    MeetingReadinessStatus.defaultModelUnavailable when canRepairRuntime =>
      _RecordingConditionsAction.repairRuntime,
    MeetingReadinessStatus.defaultModelUnavailable =>
      _RecordingConditionsAction.recheck,
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
      Text(available ? availableLabel : unavailableLabel),
    ],
  ),
);

String _storageDetail(int? freeBytes) {
  final minimum = _readinessByteLabel(minimumRecordingFreeBytes);
  if (freeBytes == null) {
    return '开始会议至少需要 $minimum';
  }
  return '可用 ${_readinessByteLabel(freeBytes)} · 最低要求 $minimum';
}

String _readinessByteLabel(int bytes) {
  const gib = 1024 * 1024 * 1024;
  const mib = 1024 * 1024;
  if (bytes >= gib) {
    return '${(bytes / gib).toStringAsFixed(2)} GiB';
  }
  return '${(bytes / mib).toStringAsFixed(1)} MiB';
}

String _actionLabel(_RecordingConditionsAction action) => switch (action) {
  _RecordingConditionsAction.requestMicrophonePermission => '授权麦克风',
  _RecordingConditionsAction.recheck => '重新检查',
  _RecordingConditionsAction.repairRuntime => '修复离线资源',
};
