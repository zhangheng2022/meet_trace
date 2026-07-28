---
version: 1
slug: "ui-features-meetings-views-meeting-list-view-dart"
primary_target: "lib/ui/features/meetings/views/meeting_list_view.dart"
related_targets: ["lib/ui/core/app_ledger.dart","test/ui/features/meetings/views/meeting_list_view_test.dart"]
---

# 首页 / 会议账本

- 范围与模式：`meeting_list_view.dart`，Operate。
- 用户任务：确认麦克风、存储与默认模型的真实预检状态，快速扫描会议，继续当前会议或开始新会议。
- 主要操作：开始会议；手机点击会议直接打开，平板先选择并在事实预览中打开完整记录。
- 真实内容：录音预检状态、会议日期、时间、标题、录音时长、处理状态、事实音频保存状态、本场模型。
- 方向：参考图锁定的黑白时间账本。手机是全宽连续账本，平板是左侧账本与右侧事实预览的主从工作台。
- 记忆点：贯穿日期列的时间轨，以及始终贴底的黑色“开始会议”操作。
- 约束：顶部真实预检使用“状态标题 + 事实说明”两层排版，第二行负责说明“音频仅保存在本机”和当前可用模型，不把全部信息串成一段长句；底部只保留黑色“开始会议”主操作，不常驻重复说明。“实时转录仅供参考”仅在录音语境中出现。不得虚构剩余容量、预计时长、实时转录正文或装饰波形；必须保留 Android/iOS 安全区、系统返回和字体缩放。
