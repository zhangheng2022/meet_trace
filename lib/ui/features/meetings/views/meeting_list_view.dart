import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:meetily_ai/theme/theme.dart';

/// 会议列表的空白首页。
class MeetingListView extends StatelessWidget {
  const MeetingListView({required this.onStartMeeting, super.key});

  final VoidCallback onStartMeeting;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;

    return FScaffold(
      header: const FHeader(title: Text('会议')),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: theme.style.iconStyle.copyWith(
                  color: theme.colors.mutedForeground,
                  size: appStyle.emptyIconSize,
                ),
                child: theme.icons.calendar(context, semanticsLabel: '会议日历'),
              ),
              SizedBox(height: appStyle.spaceLg),
              Text(
                '还没有会议',
                style: theme.typography.display.lg,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: appStyle.spaceSm),
              Text(
                '开始录音后，会议会安全地保存在这台设备上。',
                style: theme.typography.body.md.copyWith(
                  color: theme.colors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: appStyle.spaceLg),
              FButton(
                onPress: onStartMeeting,
                mainAxisSize: MainAxisSize.min,
                child: const Text('开始会议'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
