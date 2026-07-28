---
name: 会迹 · MeetTrace
description: 以连续时间账本守护本地事实音频的黑白会议记录系统
colors:
  paper: "#F7F7F5"
  ink: "#111111"
  sheet: "#FFFFFF"
  ink-inverse: "#FAFAF8"
  surface-muted: "#EFEFEC"
  ink-muted: "#52524E"
  rule: "#D8D8D3"
  rule-strong: "#8B8B85"
  night-paper: "#0D0D0D"
  night-ink: "#F4F4F1"
  night-sheet: "#151515"
  night-surface-muted: "#202020"
  night-ink-muted: "#B7B7B0"
  night-rule: "#343432"
  night-rule-strong: "#777772"
typography:
  display:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans SC', 'PingFang SC', sans-serif"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.8px"
  headline:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans SC', 'PingFang SC', sans-serif"
    fontSize: "20px"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "-0.2px"
  title:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans SC', 'PingFang SC', sans-serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.35
    letterSpacing: "-0.1px"
  body:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans SC', 'PingFang SC', sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: "normal"
  label:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans SC', 'PingFang SC', sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.35
    letterSpacing: "0.1px"
    fontFeature: "tabular-nums"
  recorder-time:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Noto Sans SC', 'PingFang SC', sans-serif"
    fontSize: "56px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "-1.8px"
    fontFeature: "tabular-nums"
rounded:
  xs: "4px"
  sm: "6px"
  md: "8px"
  lg: "12px"
spacing:
  "2xs": "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  "2xl": "48px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.ink-inverse}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px 16px"
    height: "48px"
  button-outline:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px 16px"
    height: "48px"
  text-field:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.sm}"
    padding: "12px"
    height: "48px"
  ledger-surface:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    width: "100%"
  ledger-row:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "0"
    padding: "12px 16px"
    width: "100%"
  ledger-row-selected:
    backgroundColor: "{colors.surface-muted}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "0"
    padding: "12px 16px"
    width: "100%"
  status-notice:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px"
    width: "100%"
  recorder-instrument:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "24px"
    width: "100%"
  bottom-action-bar:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    padding: "12px 16px 16px"
    width: "100%"
  scaffold-header:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.display}"
    padding: "16px"
    width: "100%"
---

# Design System: 会迹 · MeetTrace

## Overview

**Creative North Star: "安静的事实账本 / The Quiet Evidence Ledger"**

会迹把会议呈现为一本正在持续写入、可以逐层回溯的事实账本。纸面、时间轨道与专业录音设备的秩序感构成品牌识别；界面不靠品牌色或 AI 装饰制造“智能感”，而是让用户先确认录音是否安全，再阅读实时预览，最后回到最终转录与证据。

这套系统的气质是冷静、明确、可靠、低噪声。信息密度接近原生记录工具：手机保持克制单列，平板将会议索引与事实详情并置；动效只确认操作与状态变化，不承担装饰。已确认的反向参照是卡片仪表盘、装饰性波形、彩色状态、渐变、玻璃、发光、漂浮阴影和虚构 AI 可视化。

**Key Characteristics:**

- 连续记录条取代卡片网格，时间轨道贯穿会议、转录与证据。
- 纯灰阶语义，状态通过文字、图标、边界、位置和填充共同编码。
- 录音计时器是唯一允许占据超大字号的动态数字。
- 低曲率、细分隔线、静止状态零阴影。
- 手机单列直达任务，平板使用索引与事实工作区的主从布局。
- Android 与 iOS 共享视觉令牌，但保留各自原生导航、手势、安全区和辅助技术语义。

## Colors

配色是带轻微暖度的黑、白与中性灰；浅色主题像耐看的账本纸，深色主题像低反光录音设备面板。

### Primary

- **事实墨色（Fact Ink）** (#111111): 承载标题、主要文字、焦点环、最高优先级操作和需要强确认的状态。
- **反白纸墨（Inverse Paper Ink）** (#FAFAF8): 用于事实墨色之上的按钮文字、图标与状态标记。

### Neutral

- **账本纸面（Ledger Paper）** (#F7F7F5): 应用的浅色背景，和纯白记录表面形成轻微层次。
- **记录白页（Record Sheet）** (#FFFFFF): 列表、表单、状态通知和工作区的主要内容表面。
- **静默灰面（Quiet Surface）** (#EFEFEC): 选中、按下、弱分区与次级控件背景。
- **注释墨色（Annotation Ink）** (#52524E): 时间、来源、时长、解释和次级事实。
- **账本细线（Ledger Rule）** (#D8D8D3): 连续记录行、内容区与底部操作栏的常规分隔。
- **仪器强线（Instrument Rule）** (#8B8B85): 关键事实边界、输入边界和需要增强区分的状态轨。
- **夜间纸面（Night Ledger Paper）** (#0D0D0D): 深色主题的应用背景。
- **夜间事实墨色（Night Fact Ink）** (#F4F4F1): 深色主题的标题、主要文字与强状态。
- **夜间记录页（Night Record Sheet）** (#151515): 深色主题的事实内容表面。
- **夜间静默灰面（Night Quiet Surface）** (#202020): 深色主题的选中、按下和弱分区背景。
- **夜间注释墨色（Night Annotation Ink）** (#B7B7B0): 深色主题的时间、来源与解释。
- **夜间账本细线（Night Ledger Rule）** (#343432): 深色主题的常规分隔。
- **夜间仪器强线（Night Instrument Rule）** (#777772): 深色主题的关键边界与状态轨。

### Named Rules

**The Achromatic State Rule.** 所有语义状态都来自灰阶；录音、成功、警告和错误必须同时具有明确文字与非颜色线索。

**The Ink Block Rule.** 实心墨色只属于当前页面最重要的动作或状态；同一视口最多出现两个大面积墨块。

**The Warm Paper Rule.** 大面积背景优先使用略暖的账本纸面，纯白只留给承载事实内容的记录表面。

## Typography

**Display Font:** 平台系统无衬线体（Android：Roboto / Noto Sans SC；iOS：SF Pro / PingFang SC）

**Body Font:** 同一平台系统无衬线体

**Label/Mono Font:** 标签沿用系统字体；时间、时长和计时器启用等宽数字特性

**Character:** 字体保持原生、克制和高度可读。层级依靠字号、字重与留白，而不是全大写、装饰字体或过多字重；中文、数字和必要英文术语应在同一行中保持稳定节奏。

### Hierarchy

- **Display** (600, 32px, line-height 1.1): 页面主标题和最高层级结果；手机与平板都保持明确但不过度品牌化。
- **Headline** (600, 20px, line-height 1.25): 区段标题、工作区标题和重要分组。
- **Title** (600, 18px, line-height 1.35): 会议标题、列表主信息和状态标题。
- **Body** (400, 16px, line-height 1.55): 表单、说明、转录和详情正文；长文本阅读区最大宽度为 760px。
- **Label** (500, 13px, line-height 1.35): 时间、日期、状态、来源和度量；数字启用 tabular figures。
- **Recorder Time** (400, 56px, line-height 1.0): 录音页唯一的超大数字角色；紧凑手机可降至 40px，平板最大 64px。

### Named Rules

**The Instrument Number Rule.** 大号数字只属于正在变化的录音时间；普通时长、统计、模型信息和容量不得与计时器竞争。

**The Three-Weight Rule.** 全局只使用 400、500、600 三档字重，避免用粗细噪声代替信息层级。

## Layout

布局建立在 4pt 节奏上，复用 4、8、12、16、24、32、48 的间距级别。页面默认水平留白为 16px；紧凑表单最大宽度 520px，长文本阅读区最大宽度 760px，扩展工作台最大宽度 1280px。触控目标以 48×48 为共享下限，并在 iOS 上保留至少 44pt 的原生要求。

小于 600px 使用单列，关键操作固定在底部安全区，会议行点击后直接进入详情。600–839px 仍保持单一阅读顺序，只增加留白和内容宽度。840px 起允许主从布局：首页左侧为约 400–480px 的会议账本，右侧为事实预览；会议详情采用 280px 事实栏与证据工作区。1024px 是强制视觉检查点，不是另一套视觉语言。

列表、状态和转录按内容自然增高，不用固定高度裁切文本。必须在 320、375、414、768、1024 宽度以及 2.0 字体缩放下保持关键事实与操作可见，不产生横向溢出。

### Named Rules

**The Continuous Ledger Rule.** 同类记录属于同一张连续表面，以分隔线和时间轨组织；不得为每条记录制造独立圆角卡片。

**The Stable Fact Rule.** ASR 变慢、失败、恢复或产生新文本时，不得移动计时器、事实音频状态、暂停和结束操作。

**The Content-Driven Breakpoint Rule.** 响应式变化只由可用宽度决定，不读取设备型号、方向或平台字符串。

## Elevation & Depth

系统静止时不使用阴影。层级由账本纸面与记录白页的轻微明度差、1px 分隔线、2px 强边界、3px 状态轨、间距和排版建立；弹窗与平台覆盖层仍遵循 Forui 和系统原生语义，但不得把阴影扩散为全局装饰。

### Named Rules

**The Zero Resting Shadow Rule.** 页面、列表行、状态栏、卡片和内容分区在静止状态下阴影为零。

**The Structural Depth Rule.** 先使用边界、纸面差与空间关系表达层级，只有系统覆盖层可以获得临时悬浮语义。

## Shapes

形状语言接近 shadcn/ui 的克制几何：小而一致的圆角、清晰边界、没有软糖式胶囊容器。4px 用于微型标记，6px 用于输入和小控件，8px 用于按钮、状态通知和常规容器，12px 只用于录音仪器、空状态图标框和需要更完整包裹感的面板。

常规边界为 1px，关键事实边界为 2px，状态轨为 3px。连续账本内部行保持直角，只允许整张表面的外缘圆角；全宽首页账本可以移除外框，让页面本身成为表面。

### Named Rules

**The Low-Curvature Rule.** 圆角只表达组件边界，不承担亲和力装饰；禁止胶囊式大圆角卡片与任意半径。

**The Shared-Edge Rule.** 同一数据集合中的相邻记录共享边界，避免卡片套卡片和重复轮廓。

## Components

组件优先使用 Forui 的 `F*` 原语，通过 `context.theme` 与 `AppStyle` 取得令牌。Material 只负责应用外壳、平台集成或已记录的能力缺口。

### Buttons

- **Shape:** 克制圆角（8px），最小高度 48px。
- **Primary:** 事实墨色底与反白文字，正文层级 600 字重；每个页面只保留一个主操作。
- **Outline:** 记录白页底、仪器强线边界和事实墨色文字，用于暂停、恢复、取消和次级操作。
- **Ghost:** 无常驻容器，用于低优先级、局部且可撤销的操作。
- **Hover / Focus / Pressed:** 约 120ms ease-out；按下可轻微缩放或切换静默灰面，焦点必须有清晰的 2px 事实墨色轮廓。减少动态效果时立即切换状态。

### Cards / Containers

- **Corner Style:** 常规容器 8px，完整面板 12px，连续账本行 0px。
- **Background:** 记录白页；选中与按下使用静默灰面。
- **Shadow Strategy:** 静止状态无阴影，使用边界与纸面差。
- **Border:** 常规 1px 账本细线；关键事实和错误可增至 2px。
- **Internal Padding:** 默认 16px；紧凑行和状态通知使用 12px；录音仪器使用 24px。

### Inputs / Fields

- **Style:** 标签始终位于输入框上方；记录白页底、6px 圆角、1px 仪器强线边界，最小高度 48px。
- **Focus:** 2px 事实墨色焦点轮廓，并保留足够偏移避免覆盖边界。
- **Error / Disabled:** 使用明确文案、图标和边界变化；不依赖红色，也不以占位符代替标签。

### Navigation

- **Style:** `FScaffold` 提供页面结构，标题直接、左对齐，页面级动作数量保持克制。
- **Android:** 保留系统预测返回、Material 导航语义与 Android 安全区。
- **iOS:** 保留边缘返回手势、Dynamic Type、VoiceOver 与 iOS 安全区。
- **Tablet:** 首页账本行负责选择，右侧“打开完整记录”负责进入详情；手机账本行直接进入详情。

### Ledger Surface / Ledger Row

会议、转录和证据共用的签名组件。每行包含 64px 时间列、连续事实轨、标题与时长、状态图标和事实文案；普通行垂直内边距为 12px。正在录音或被选中的行使用静默灰面，录音状态使用墨色徽标与文字，不使用彩色直播效果。长标题或长状态必须纵向堆叠，不能与尾部状态碰撞。

### Status Notice

状态通知由 3px 竖轨、Lucide 图标、标题和事实说明组成。标题说明发生了什么，正文说明对事实音频的影响以及用户下一步；错误状态可使用 2px 外边界，但保持灰阶。

首页录音条件条必须读取麦克风权限、可用存储与默认模型的真实预检结果，区分检查中、已就绪、需要处理和检查失败；开始会议时再次预检，首页结果不得替代录音服务的最终权限与空间检查。

### Recorder Instrument

录音仪器按固定顺序展示：录音状态与“实时转录仅供参考”、待生成标题、大号计时器、真实时间刻度、事实音频保存状态、锁定模型、暂停/恢复与“结束并保存”。首页的“开始会议”直接进入录音，不设置标题、不选择模型；本场始终使用设置中的全局默认模型。最终转录完成后，AI 总结同时生成会议标题并替换“待生成标题”。时间刻度只表达经过时间，不模拟音量或生成装饰性波形。

### Bottom Action Bar

底部操作栏贴合安全区，以记录白页和顶部细分隔线与内容区分离。主按钮占满可用宽度；辅助文案位于按钮上方，直接说明动作的事实影响。首页允许将整个底栏作为事实墨色主操作面。

## Do's and Don'ts

### Do:

- **Do** 把会议、转录和证据组织到时间轨道，而不是创建新的卡片类型。
- **Do** 让事实音频状态、计时和结束操作永远先于实时转录与 AI 派生内容。
- **Do** 使用文字、图标、边界、位置和填充共同编码所有状态。
- **Do** 使用 Forui、`context.theme` 与 `AppStyle` 令牌实现组件。
- **Do** 保留 Android 与 iOS 原生返回、手势、安全区、字体缩放和辅助技术行为。
- **Do** 在紧凑手机、平板、浅色、深色和 2.0 字体缩放下验证真实内容与长文案。

### Don't:

- **Don't** 使用红、黄、绿、品牌蓝、渐变、玻璃、发光或 AI 装饰色。
- **Don't** 使用悬浮卡片网格、卡片套卡片、装饰性波形或虚构音量动画。
- **Don't** 用颜色单独表达录音、成功、警告、失败或模型状态。
- **Don't** 引入登录、同步、云端录音、虚构容量、虚构转录或未规划功能。
- **Don't** 在录音开始后暗中切换模型，或让派生处理状态干扰事实录音控制。
- **Don't** 为追求跨平台像素一致而覆盖 Android 与 iOS 的原生交互。
