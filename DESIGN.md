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
  recorder-waveform:
    backgroundColor: "{colors.sheet}"
    textColor: "{colors.ink}"
    mutedColor: "{colors.rule-strong}"
    baselineColor: "{colors.rule}"
    transition: "140ms interruptible ease-out"
    height: "84px"
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

# 会迹（MeetTrace）交互与视觉设计系统

## Overview

**Creative North Star: "安静的事实账本 / The Quiet Evidence Ledger"**

会迹把会议呈现为一本正在持续写入、可以逐层回溯的事实账本。纸面、时间轨道与专业录音设备的秩序感构成品牌识别；界面不靠品牌色或 AI 装饰制造“智能感”，而是让用户先确认录音是否安全，再阅读实时预览，最后回到带说话人标签的最终转录与对应音频。

这套系统的气质是冷静、明确、可靠、低噪声。信息密度接近原生记录工具：手机保持克制单列，平板将会议索引与事实详情并置；动效只确认操作与状态变化，不承担装饰。已确认的反向参照是卡片仪表盘、装饰性波形、彩色状态、渐变、玻璃、发光、漂浮阴影和虚构 AI 可视化。

**Key Characteristics:**

- 连续记录条取代卡片网格，时间轨道贯穿会议、转录与音频核对。
- 纯灰阶语义，状态通过文字、图标、边界、位置和填充共同编码。
- 录音计时器是唯一允许占据超大字号的动态数字。
- 低曲率、细分隔线、静止状态零阴影。
- 手机单列直达任务，平板使用索引与事实工作区的主从布局。
- Android 与 iOS 共享视觉令牌，但保留各自原生导航、手势、安全区和辅助技术语义。

## Brand Mark

- `assets/branding/stitch/meettrace-app-icon.svg` 是应用图标母版：黑色铺满方形画布，白色标志居中，不预制圆角或外框。
- `assets/branding/stitch/meettrace-mark-black.svg` 是应用内标志母版；浅色主题使用事实墨色，深色主题使用夜间事实墨色。
- 平台图标与启动位图从 SVG 母版生成，生成文件不得再次手工描摹、拉伸或改变内部交叉关系。
- 应用内标志只出现在启动与本地能力初始化品牌字标，以及会议列表首页左上角的静态图形 Logo 中；列表首页不在 Logo 旁重复显示“会迹”文字，会议详情、录音与设置等高频功能页继续使用文字标题。
- 原生启动屏由 `flutter_native_splash` 生成静态标志；原生屏退出后，Flutter 在 960ms 内完成一次“官方墨带连续写入 → 标志归位 → 中英文字标揭示”，亮色与暗色主题均使用各自前景色，不循环、不阻塞初始化，也不因阶段更新重播。
- Android“移除动画”或 iOS“减弱动态效果”开启时直接显示最终品牌状态；桌面图标与原生系统图标始终静态。

## Startup Flow

- 冷启动只有一张连续的“正在准备会迹”页面，不把本地数据恢复与离线资源准备表现为两个页面。
- Logo、标题、说明、内容位置和页面 identity 在准备期间保持稳定；仅更新 1–4 阶段名称、状态说明、下载进度与必要操作。
- 只有运行时资源确认就绪后才以一次淡入切换至会议首页；数据读取失败、空间不足、网络确认和资源失败继续提供明确的阻断与恢复操作。

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

小于 600px 使用单列，关键操作固定在底部安全区，会议行点击后直接进入详情。600–839px 仍保持单一阅读顺序，只增加留白和内容宽度。840px 起允许主从布局：首页左侧为约 400–480px 的会议账本，右侧为事实预览；会议详情采用 280px 事实栏与转录工作区。1024px 是强制视觉检查点，不是另一套视觉语言。

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

会议与转录共用的签名组件。每行包含 64px 时间列、连续事实轨、标题与时长、说话人标签、状态图标和事实文案；普通行垂直内边距为 12px。正在录音或被选中的行使用静默灰面，录音状态使用墨色徽标与文字，不使用彩色直播效果。长标题或长状态必须纵向堆叠，不能与尾部状态碰撞。

会议列表的删除属于低频破坏性操作：仅允许向左滑动揭示尾部墨色“删除”动作，不允许完整滑动直接执行。一次只能展开一行，点击行、滚动列表或展开其他行时收起；点击删除后必须再次确认将清除事实音频、转录、说话人标签、处理记录和分享临时文件。录音中与后台处理中的会议不提供该手势，详情页保留显式删除入口作为可发现性与辅助技术替代路径。

### Status Notice

状态通知由 3px 竖轨、Lucide 图标、标题和事实说明组成。标题说明发生了什么，正文说明对事实音频的影响以及用户下一步；错误状态可使用 2px 外边界，但保持灰阶。

首页录音条件条必须读取麦克风权限、可用存储与默认模型的真实预检结果，区分检查中、已就绪、需要处理和检查失败。预检条使用稳定的两层排版：第一行是当前状态标题，第二行是事实说明；不得把标题、存储事实和模型信息串成同一段长句。就绪状态的第二行同时说明“音频仅保存在本机”和当前可用模型。开始会议时再次预检，首页结果不得替代录音服务的最终权限与空间检查。

### Recorder Instrument

录音页顶部栏显示当前会议标题，录音仪器按固定顺序展示：录音状态、唯一的大号计时器、真实麦克风输入波形，以及无内嵌卡片的两行事实摘要（事实音频状态、锁定模型）。手机端使用 12px 仪器内边距和 48px 计时器，平板端保留 24px 内边距和 56px 计时器。暂停/恢复与“结束会议”固定在底部操作栏；“实时转录仅供参考”只在实时转录区出现一次。首页的“开始会议”直接进入录音，不设置标题、不选择模型；创建会议时按本地开始时间生成稳定标题，例如 `2026-08-03 14:30 会议`，本场始终使用设置中的全局默认模型。波形只能由已经写入事实音频的 PCM 音量驱动，以底部基线和仅向上生长的单边波形确认麦克风输入；手机高 52px，平板高 64px。新样本从当前画面状态开始 140ms 可中断过渡，并以短窗自适应增益增强安静输入的可见差异；系统要求减弱动态时立即更新。不得显示“时/分/秒”、重复时间刻度或把随机动画伪装为真实音频。

实时转录区将标题与当前状态合并到同一标题行，状态文案不重复“实时转录”；长警告允许在状态区内换行，不挤压标题与片段计数。片段计数仅在已有片段时显示；正常空状态只说明文字出现条件，积压、暂停和仅录音状态保留事实录音不受影响的明确说明。手机端不显示整块外围边框，平板双栏保留面板边界。实时预览片段按时间倒序显示，最新片段置顶；不额外添加“最新”标签，最终转录与底层事件仍保持时间正序。手机端转录行使用 8px 纵向内边距、64px 时间列和 8px 内容间距；平板端保留宽松尺寸。时间必须保持单行：一小时内使用 `MM:SS`，超过一小时使用 `H:MM:SS`。

### Final Result / Sharing

会议结束后只显示一个“正在生成最终结果”状态；内部可并行运行最终 ASR 与说话人分离，但界面不得先发布半成品。两条任务结束后一次切换到最终转录；分离失败时以明确的单一说话人降级文案发布，事实音频和最终文本仍可用。说话人标签可编辑，编辑操作只改变显示标签，不改变转录时间轴或源音频。

详情页把“分享文本”和“分享音频”作为两个独立动作。分享文本只包含标题、会议时间和带说话人/时间戳的最终转录。分享音频每次先显示会议名称、时长、文件大小和敏感信息提醒；用户再次确认后才生成 WAV 并打开系统分享面板。生成中、空间不足、取消、失败和完成都必须有明确状态，不得把临时文件伪装成永久副本。

### Bottom Action Bar

底部操作栏贴合安全区，以记录白页和顶部细分隔线与内容区分离。首页只保留占满可用宽度的事实墨色“开始会议”主操作；录音页只保留“暂停/继续”和“结束会议”，宽屏也不重复事实音频说明。“音频仅保存在本机”并入顶部真实预检，“实时转录仅供参考”只在录音语境中出现一次。

## Do's and Don'ts

### Do:

- **Do** 把会议、转录和音频核对组织到时间轨道，而不是创建新的卡片类型。
- **Do** 让事实音频状态、计时和结束操作永远先于实时转录与说话人派生内容。
- **Do** 使用文字、图标、边界、位置和填充共同编码所有状态。
- **Do** 让录音波形忠实反映已经写入的 PCM 音量，并允许反馈丢帧而不影响事实录音。
- **Do** 使用 Forui、`context.theme` 与 `AppStyle` 令牌实现组件。
- **Do** 保留 Android 与 iOS 原生返回、手势、安全区、字体缩放和辅助技术行为。
- **Do** 在紧凑手机、平板、浅色、深色和 2.0 字体缩放下验证真实内容与长文案。

### Don't:

- **Don't** 使用红、黄、绿、品牌蓝、渐变、玻璃、发光或 AI 装饰色。
- **Don't** 使用悬浮卡片网格、卡片套卡片、装饰性波形、重复时间刻度或虚构音量动画。
- **Don't** 用颜色单独表达录音、成功、警告、失败或模型状态。
- **Don't** 引入登录、同步、云端录音、虚构容量、虚构转录或未规划功能。
- **Don't** 在录音开始后暗中切换模型，或让派生处理状态干扰事实录音控制。
- **Don't** 为追求跨平台像素一致而覆盖 Android 与 iOS 的原生交互。
