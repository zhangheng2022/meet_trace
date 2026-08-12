import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../../../keys.dart';
import '../../../../../../theme/theme.dart';
import '../../../view_models/list/meeting_list_view_model.dart';

final class MeetingHomePane extends StatelessWidget {
  const MeetingHomePane({
    required this.body,
    required this.total,
    required this.readiness,
    required this.startingMeeting,
    required this.onOpenRecordingConditions,
    required this.onRetryReadiness,
    required this.onStartMeeting,
    super.key,
  });

  final Widget body;
  final int? total;
  final MeetingReadinessViewState readiness;
  final bool startingMeeting;
  final VoidCallback? onOpenRecordingConditions;
  final Future<void> Function()? onRetryReadiness;
  final VoidCallback? onStartMeeting;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecordingSetupStrip(
            readiness: readiness,
            onOpenRecordingConditions: onOpenRecordingConditions,
            onRetry: onRetryReadiness,
          ),
          _MeetingSectionHeader(total: total),
          Expanded(child: body),
          if (onStartMeeting != null)
            _StartMeetingControl(
              isStarting: startingMeeting,
              onPress: onStartMeeting!,
            ),
        ],
      ),
    );
  }
}

final class _RecordingSetupStrip extends StatelessWidget {
  const _RecordingSetupStrip({
    required this.readiness,
    required this.onOpenRecordingConditions,
    required this.onRetry,
  });

  final MeetingReadinessViewState readiness;
  final VoidCallback? onOpenRecordingConditions;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    final presentation = _readinessPresentation(readiness);
    final retry = readiness.status == MeetingReadinessStatus.failed
        ? onRetry
        : null;
    final canOpenConditions = switch (readiness.status) {
      MeetingReadinessStatus.ready ||
      MeetingReadinessStatus.microphonePermissionRequired ||
      MeetingReadinessStatus.storageInsufficient ||
      MeetingReadinessStatus.defaultModelUnavailable => true,
      MeetingReadinessStatus.unchecked ||
      MeetingReadinessStatus.checking ||
      MeetingReadinessStatus.failed => false,
    };
    final VoidCallback? onPress = retry != null
        ? () => unawaited(retry())
        : canOpenConditions
        ? onOpenRecordingConditions
        : null;
    final trailingIcon = switch (readiness.status) {
      MeetingReadinessStatus.ready ||
      MeetingReadinessStatus.microphonePermissionRequired ||
      MeetingReadinessStatus.storageInsufficient ||
      MeetingReadinessStatus.defaultModelUnavailable =>
        FLucideIcons.chevronRight,
      MeetingReadinessStatus.failed => FLucideIcons.refreshCw,
      MeetingReadinessStatus.unchecked ||
      MeetingReadinessStatus.checking => null,
    };
    final content = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: appStyle.dividerWidth,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceMd,
          vertical: appStyle.spaceXs,
        ),
        child: Row(
          children: [
            Icon(presentation.icon, size: 19),
            SizedBox(width: appStyle.spaceSm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    key: const ValueKey('recording-setup-title'),
                    style: theme.typography.body.sm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: appStyle.space2Xs),
                  Text(
                    presentation.detail,
                    key: const ValueKey('recording-setup-detail'),
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (onPress != null && trailingIcon != null) ...[
              SizedBox(width: appStyle.spaceXs),
              Icon(
                trailingIcon,
                key: const ValueKey('recording-setup-trailing-icon'),
                size: 18,
                color: theme.colors.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    );
    if (onPress == null) {
      return content;
    }
    return FTappable(
      key: keys.meetings.listRecordingConditions,
      semanticsLabel: retry == null ? '查看录音条件' : '重新检查录音条件',
      onPress: onPress,
      child: content,
    );
  }
}

({IconData icon, String title, String detail}) _readinessPresentation(
  MeetingReadinessViewState readiness,
) => switch (readiness.status) {
  MeetingReadinessStatus.unchecked => (
    icon: FLucideIcons.fileAudio,
    title: '本地录音',
    detail: '使用默认模型',
  ),
  MeetingReadinessStatus.checking => (
    icon: FLucideIcons.fileAudio,
    title: '正在检查录音条件',
    detail: '麦克风、存储与默认模型',
  ),
  MeetingReadinessStatus.ready => (
    icon: FLucideIcons.circleCheck,
    title: '录音条件已就绪',
    detail: '音频仅保存在本机 · ${readiness.defaultModelName ?? '默认模型'}可用',
  ),
  MeetingReadinessStatus.microphonePermissionRequired => (
    icon: FLucideIcons.circleAlert,
    title: '需要麦克风权限',
    detail: _readinessDetail('开始会议时授权', readiness.issueCount),
  ),
  MeetingReadinessStatus.storageInsufficient => (
    icon: FLucideIcons.circleAlert,
    title: '存储空间不足',
    detail: _readinessDetail('至少保留 128 MB', readiness.issueCount),
  ),
  MeetingReadinessStatus.defaultModelUnavailable => (
    icon: FLucideIcons.circleAlert,
    title: '默认模型不可用',
    detail: '${readiness.defaultModelName ?? '当前模型'}需要处理',
  ),
  MeetingReadinessStatus.failed => (
    icon: FLucideIcons.circleAlert,
    title: '无法检查录音条件',
    detail: '点按重新检查',
  ),
};

String _readinessDetail(String primary, int issueCount) =>
    issueCount > 1 ? '$primary，另有 ${issueCount - 1} 项' : primary;

final class _MeetingSectionHeader extends StatelessWidget {
  const _MeetingSectionHeader({required this.total});

  final int? total;

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
        padding: EdgeInsets.symmetric(
          horizontal: appStyle.spaceMd,
          vertical: appStyle.spaceSm,
        ),
        child: Row(
          children: [
            Expanded(child: Text('会议', style: theme.typography.display.lg)),
            if (total case final count?)
              Text(
                '共 $count 场',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _StartMeetingControl extends StatefulWidget {
  const _StartMeetingControl({required this.isStarting, required this.onPress});

  final bool isStarting;
  final VoidCallback onPress;

  @override
  State<_StartMeetingControl> createState() => _StartMeetingControlState();
}

final class _StartMeetingControlState extends State<_StartMeetingControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool? _disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations != disableAnimations) {
      _disableAnimations = disableAnimations;
      _syncRotation();
    }
  }

  @override
  void didUpdateWidget(covariant _StartMeetingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStarting != oldWidget.isStarting) {
      _syncRotation();
    }
  }

  void _syncRotation() {
    if (widget.isStarting && _disableAnimations != true) {
      _rotation.repeat();
    } else {
      _rotation
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return FTappable(
      key: keys.meetings.listStartMeeting,
      style: const FTappableStyleDelta.delta(
        pressedEnterDuration: Duration.zero,
        pressedExitDuration: Duration.zero,
        motion: FTappableMotion.none,
      ),
      semanticsLabel: widget.isStarting ? '正在准备录音' : '开始会议',
      onPress: widget.isStarting ? null : widget.onPress,
      builder: (context, variants, child) {
        final pressed = variants.contains(FTappableVariant.pressed);
        return AnimatedContainer(
          key: const ValueKey('start-meeting-control-surface'),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          color: Color.lerp(
            theme.colors.primary,
            theme.colors.primaryForeground,
            pressed ? 0.12 : 0,
          ),
          child: child,
        );
      },
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: appStyle.controlHeight + appStyle.spaceMd,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isStarting)
                  RotationTransition(
                    key: const ValueKey('start-meeting-progress-icon'),
                    turns: _rotation,
                    child: Icon(
                      FLucideIcons.loaderCircle,
                      color: theme.colors.primaryForeground,
                    ),
                  )
                else
                  Icon(FLucideIcons.mic, color: theme.colors.primaryForeground),
                SizedBox(width: appStyle.spaceSm),
                Text(
                  widget.isStarting ? '正在准备录音…' : '开始会议',
                  style: theme.typography.body.lg.copyWith(
                    color: theme.colors.primaryForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }
}
