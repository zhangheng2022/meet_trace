---
version: 1
slug: "i-features-settings-views-model-settings-view-dart"
primary_target: "lib/ui/features/settings/views/model_settings_view.dart"
related_targets: ["lib/ui/core/app_ledger.dart","test/ui/features/settings/views/model_settings_view_test.dart"]
---

# 设置页

- 范围：`ModelSettingsView`；Operate 模式。
- 用户任务：快速确认界面偏好、后续新会议默认、本地资源状态，以及隐私与诊断边界。
- 约束：仅显示真实已有设置；外观与语言各只有一个入口，并在入口单行显示当前值；不得引入登录、同步、云端能力或 AI 总结。
- 方向：贴近原生设置列表：少量分组标题、连续紧凑行、弱分隔线与灰阶选中态。所有宽度保持居中单列；外观、语言、新会议默认与本地资源直接可见，麦克风、存储与诊断等低频内容收进“更多设置”渐进展开。
- 记忆点：同列章节共享白色纸面与细分隔线，选项组保留原生可识别交互；无配置摘要、无卡片网格。

## Direction contract

THESIS: 设置页是一张连续的本地配置账本，拒绝重复摘要与碎片化卡片。

OWN-WORLD: 暖白纸面、共享边缘、细分隔线和灰阶选中态；章节图标只负责定位。

STORY: 用户依次确认界面、后续新会议、本地资源，以及隐私与诊断边界。

FIRST VIEWPORT: 所有宽度只保留一条阅读线；先展示外观、语言、新会议默认与本地资源，再以折叠行提供麦克风、存储与诊断。

FORM: 采用候选列表第 2 位的连续分组构图，seed key `comp-a`；只保留一个语言入口，不实现草图中的虚构设置。

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## 实装清单

| 要素 | 语法与尺度 | 实现介质 |
| --- | --- | --- |
| 页面外壳 | 现有文字标题与原生返回，16px 页面留白 | `FScaffold` / `FHeader` |
| 连续账本 | 页面纸面直接承载分组，无外层卡片；组内上下 1px 规则线 | Flutter `Column` / `DecoratedBox` |
| 章节标题 | 13–14px 中字重分组标签，下方 8px 间距 | Flutter 语义组件 |
| 互斥偏好 | 48px 以上触控行、当前值尾随；点按后以灰阶选中态确认 | `FSelectMenuTile` / `FSelectTile` |
| 状态与数值 | 尾部对齐、表格数字、2.0 字体缩放时纵向堆叠 | 现有设置状态组件 |
| 响应式 | 所有宽度居中单列，最多使用阅读宽度；低频内容默认折叠 | `AppPageBody` / `FAccordion` |

未决项：无。
