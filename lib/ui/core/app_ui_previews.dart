// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
// Hallmark · preview: UI-01 shared foundations · theme: Shadcn Neutral

import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';
import 'package:forui/forui.dart';

import '../../app/application.dart';
import '../../theme/theme.dart';
import 'app_page_body.dart';
import 'app_state_panel.dart';
import 'app_status_notice.dart';

@Preview(name: '状态反馈 · 浅色', group: 'UI-01 共享组件', size: Size(375, 760))
Widget appStatusNoticesPreview() => const Application(
  home: FScaffold(
    header: FHeader(title: Text('状态反馈')),
    child: AppPageBody(
      width: AppPageWidth.reading,
      child: _StatusNoticePreviewContent(),
    ),
  ),
);

@Preview(
  name: '状态反馈 · 深色',
  group: 'UI-01 共享组件',
  size: Size(375, 760),
  brightness: Brightness.dark,
)
Widget appStatusNoticesDarkPreview() => appStatusNoticesPreview();

@Preview(name: '空白状态 · 320', group: 'UI-01 共享组件', size: Size(320, 640))
Widget appEmptyStatePreview() => Application(
  home: FScaffold(
    header: const FHeader(title: Text('会议')),
    child: AppStatePanel.empty(
      icon: FLucideIcons.calendar,
      title: '还没有会议',
      message: '开始录音后，会议会安全地保存在这台设备上。',
      actionLabel: '开始会议',
      onAction: () {},
    ),
  ),
);

@Preview(name: '错误状态 · 414', group: 'UI-01 共享组件', size: Size(414, 640))
Widget appErrorStatePreview() => Application(
  home: FScaffold(
    header: const FHeader(title: Text('会议')),
    child: AppStatePanel.error(
      title: '会议加载失败',
      message: '本地数据仍保留在设备上，请重试。',
      actionLabel: '重试加载',
      onAction: () {},
    ),
  ),
);

final class _StatusNoticePreviewContent extends StatelessWidget {
  const _StatusNoticePreviewContent();

  @override
  Widget build(BuildContext context) {
    final gap = context.theme.style.app.spaceSm;
    return ListView.separated(
      itemCount: _samples.length,
      separatorBuilder: (_, _) => SizedBox(height: gap),
      itemBuilder: (_, index) {
        final sample = _samples[index];
        return AppStatusNotice(
          tone: sample.tone,
          title: sample.title,
          message: sample.message,
        );
      },
    );
  }
}

const _samples = <({AppStatusTone tone, String title, String message})>[
  (tone: AppStatusTone.info, title: '正在准备最终转录', message: '事实音频已安全保存。'),
  (tone: AppStatusTone.recording, title: '正在录音', message: '实时转录变慢不会影响事实音频。'),
  (
    tone: AppStatusTone.warning,
    title: '实时转录出现积压',
    message: '录音仍在继续，稍后会从事实音频恢复。',
  ),
  (
    tone: AppStatusTone.error,
    title: '实时转录已停止',
    message: '事实音频仍在继续保存，结束后可以重试转录。',
  ),
  (tone: AppStatusTone.success, title: '事实音频已保存', message: '现在可以安全退出会议。'),
];
