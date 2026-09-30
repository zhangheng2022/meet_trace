---
version: 1
slug: "ui-features-settings-views-transcription-sources-view-dart"
primary_target: "lib/ui/features/settings/views/transcription_sources_view.dart"
related_targets: ["lib/ui/features/settings/view_models/transcription_sources_view_model.dart", "lib/ui/core/app_text_field.dart", "test/ui/features/settings/views/transcription_sources_view_test.dart"]
---

# 转录来源

- 范围：`TranscriptionSourcesView` 的来源选择、来源管理与编辑表单；Operate 功能扩展。
- 产品依据：[PRODUCT](../../PRODUCT.md) 与当前 [Alpha PRD](../../docs/product/Alpha_PRD_无登录版.md)；视觉继承 [DESIGN](../../DESIGN.md) 的事实账本和现有 Forui 组件。
- 用户任务：区分本地与在线来源的能力，为本场明确选择来源，维护自己的在线配置与认证。
- 记录状态：2026-09-08，依据当前源码及下列组件截图；没有建立新视觉世界或新增共享令牌。

## Direction contract

THESIS: 先说明来源能力与音频发送边界，再让用户明确选择或修改配置。

OWN-WORLD: 继承暖白纸面、白色内容面、墨色文字、细边界和现有 Forui 字阶；实心操作用于选择，描边操作用于配置管理。

STORY: 查看来源和默认标记 → 明确选择，或进入在线配置 → 阅读认证规则并保存；在线发送确认由调用流程承接。

FIRST VIEWPORT: 文字标题与平台返回位于顶部，随后是锁定或隐私说明、固定本地来源、用户在线来源，以及添加入口；默认只是一条文字标记。

FORM: 所有宽度保持居中单列，沿用 `AppPageBody` 的紧凑内容宽度；每项来源由带内边距的 `FCard` 承载，编辑页按阅读顺序排列字段并折叠高级设置。

## 已实现的交互

| 页面状态 | 当前行为 |
| --- | --- |
| 为会议选择来源 | 每项提供“选择 / Select”；全局默认显示“默认 / Default”，不自动替用户确认。本地资源按需准备；在线来源由调用流程确认接收服务与发送费用。开始后锁定来源，转录失败仍继续录音；会后可明确换来源生成新稿。 |
| 管理来源 | 固定 SenseVoice 项仅提供设为默认；在线项提供设为默认、编辑、测试和删除。测试与删除先确认；测试发送生成的短音频，只验证协议连接。 |
| 编辑来源 | 提供名称、协议、完整地址、模型 ID 与 API Key；高级设置包含认证头 JSON、语言、提示、上传上限和超时。协议使用 Audio Transcriptions、Chat Audio、Realtime Transcription 正式名称。 |
| 能力说明 | Audio Transcriptions 与 Chat Audio 显示“仅会后转录 · 无实时字幕”；Realtime Transcription 显示实时字幕与会后独立转录。专有接口需要兼容网关。 |
| 保存与错误 | 忙碌时禁用保存及相关操作；错误使用静态本地化文案。跨服务地址修改缺少新认证时明确提示重新填写或清空，保留当前输入供修正。 |

API Key 和认证头均遮蔽输入，编辑时不回显已保存的秘密，并关闭输入建议与自动纠正。两项都留空且接收服务不变时保留原认证；修改任一项会整体替换认证，需填写所有必需认证头，空 JSON 对象 `{}` 表示明确清空。更改协议方案、主机或端口时不能静默沿用旧凭据；同一接收服务的路径修改可保留。帮助文字位于认证输入之前，高级区域首字段保留顶部间距，避免展开后遮挡浮动标签。

## 布局与组件事实

- 外壳、来源容器、操作、协议选择和高级展开分别使用 `FScaffold` / `FHeader`、`FCard`、`FButton`、`FSelectMenuTile` 和 `FAccordion`；所有颜色、字号和间距从既有主题取得。
- 标题、来源名称、能力说明和地址形成连续阅读层级；长地址与模型名允许换行，桌面继续使用紧凑单列，不扩展为配置仪表盘。
- 选择按钮用短动作文案；管理操作采用“编辑 / Edit”“测试 / Test”，保留页面标题与确认说明的完整语义。
- 编辑输入复用已记录的 `AppTextField` Material 能力缺口；平台返回使用 `AppBackIcon`，不把它们另立为本页的新组件规范。

## 证据与验收边界

| 已留存截图 | 证明的页面状态 |
| --- | --- |
| [中文选择页，360](../../docs/quality/screenshots/transcription-sources-zh-360.png) | 默认标记、明确选择、能力说明与窄屏换行。 |
| [英文选择页，360](../../docs/quality/screenshots/transcription-sources-en-360.png) | 短标题和选择动作、英文窄屏布局。 |
| [英文管理页，1100](../../docs/quality/screenshots/transcription-sources-1100.png) | 桌面居中单列，默认、编辑、测试、删除与添加入口。 |
| [编辑页，720](../../docs/quality/screenshots/transcription-editor-720.png) | 认证整体替换帮助、两项遮蔽、高级字段间距与跨服务认证提示。 |

截图由 [组件测试](../../test/ui/features/settings/views/transcription_sources_view_test.dart) 使用真实 `Application` / `FTheme` 生成，加载实际文字与图标字体，配置和认证均为测试数据。测试还覆盖英文 360 宽管理页、非默认来源选择，以及跨服务修改被阻止后补齐认证成功保存。

本次组件截图审查的结论为 ship，四项发现均已解决；结论仅覆盖上述页面与状态。它不代表真实在线服务的识别准确率、原生端到端流程、全部屏幕宽度、字体缩放或辅助技术均已验收。页面中的来源容器与表单构图只记录为此功能的现状，不提升为全局视觉规则；既有 DESIGN 与 sidecar 的其他漂移不在本次记录范围。
