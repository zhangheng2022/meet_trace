import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../domain/models/meeting.dart';
import '../../../../theme/theme.dart';

final class MeetingDetailView extends StatelessWidget {
  const MeetingDetailView({
    required this.meeting,
    required this.onBack,
    super.key,
  });

  final Meeting meeting;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final appStyle = theme.style.app;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('会议详情'),
        prefixes: [
          FHeaderAction(
            icon: theme.icons.arrowLeft(context, semanticsLabel: '返回会议列表'),
            onPress: onBack,
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(appStyle.spaceMd),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: appStyle.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(meeting.title, style: theme.typography.display.lg),
                SizedBox(height: appStyle.spaceMd),
                const FAlert(
                  title: Text('事实音频已保存，正在处理'),
                  subtitle: Text('最终转录和 AI 总结将在后续处理完成后显示。'),
                ),
                SizedBox(height: appStyle.spaceMd),
                FCard(
                  child: Padding(
                    padding: EdgeInsets.all(appStyle.spaceMd),
                    child: Text('音频位置：${meeting.audioPath ?? '尚未生成'}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
