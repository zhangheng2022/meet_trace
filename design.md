---
name: 会迹 MeetTrace
description: 事实音频优先的安静会议记录控制台
colors:
  background: "#FFFFFF"
  foreground: "#0A0A0A"
  card: "#FFFFFF"
  surface-raised: "#FAFAFA"
  primary: "#171717"
  primary-foreground: "#FAFAFA"
  secondary: "#F5F5F5"
  secondary-foreground: "#171717"
  muted: "#F5F5F5"
  muted-foreground: "#525252"
  border: "#E5E5E5"
  destructive: "#DC2626"
  recording: "#DC2626"
  warning: "#B45309"
  success: "#15803D"
  focus-ring: "#525252"
  dark-background: "#0A0A0A"
  dark-foreground: "#FAFAFA"
  dark-card: "#171717"
  dark-surface-raised: "#171717"
  dark-primary: "#E5E5E5"
  dark-primary-foreground: "#171717"
  dark-secondary: "#262626"
  dark-secondary-foreground: "#FAFAFA"
  dark-muted: "#262626"
  dark-muted-foreground: "#A3A3A3"
  dark-border: "rgba(255, 255, 255, 0.10)"
  dark-destructive: "#FF6467"
  dark-recording: "#FF6467"
  dark-warning: "#FBBF24"
  dark-success: "#4ADE80"
  dark-focus-ring: "#D4D4D4"
typography:
  display:
    fontFamily: "system-ui, Roboto, 'Noto Sans SC', sans-serif"
    fontSize: "20px"
    fontWeight: 400
    lineHeight: 1.75
    letterSpacing: "normal"
  title:
    fontFamily: "system-ui, Roboto, 'Noto Sans SC', sans-serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.75
    letterSpacing: "normal"
  body:
    fontFamily: "system-ui, Roboto, 'Noto Sans SC', sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  label:
    fontFamily: "system-ui, Roboto, 'Noto Sans SC', sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.25
    letterSpacing: "normal"
rounded:
  2xs: "4px"
  xs: "6px"
  sm: "8px"
  md: "10px"
  lg: "14px"
  xl: "18px"
  2xl: "22px"
  3xl: "26px"
  pill: "100px"
spacing:
  2xs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  2xl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.primary-foreground}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "14px 12px"
    height: "44px"
  button-primary-large:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.primary-foreground}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "16px 12px"
    height: "48px"
  button-outline:
    backgroundColor: "{colors.card}"
    textColor: "{colors.secondary-foreground}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "14px 12px"
    height: "44px"
  input:
    backgroundColor: "{colors.card}"
    textColor: "{colors.foreground}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px"
    height: "44px"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
  status-notice:
    backgroundColor: "{colors.card}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
---

# Design System: 会迹（MeetTrace）

## Overview

**Creative North Star: "安静的录音控制台"**

会迹是一套以操作为中心的 Android + iOS 自适应工作台：它像一台始终在场、从不喧哗的录音控制台，
优先让用户确认事实音频是否安全、会议处于什么状态、下一步能做什么。界面不借助品牌蓝、
渐变或装饰性图形制造“智能感”，而是依靠黑白明度、稳定结构、准确文案与稀少的语义色
建立可信度。

视觉基础采用 shadcn/ui Neutral 的语义关系，并映射到 Flutter/Forui。浅色主题是清晰的
白色工作面，深色主题是独立设计的近黑控制台；两者都让正文和主操作保持高对比。录音红、
警告琥珀与成功绿只用于真实状态，而且始终与图标和文字共同出现。

组件保持紧凑、稳定、可预期。Android 触控区域符合 48 dp 基线，iOS 符合 44 pt 基线；
控件使用 Forui 的 superellipse 圆角，反馈就地发生，不通过大幅位移、庆祝动画或布局重排争夺注意力。

**Key Characteristics:**

- shadcn/ui Neutral 黑白语义体系，浅色与深色分别编排。
- 事实状态先于 AI 能力，录音安全信息始终拥有最高视觉优先级。
- 主操作使用近黑或近白，不把语义颜色消费在普通操作上。
- 4 pt 间距节奏、紧凑圆角、极浅结构阴影与清晰边界。
- 中文真实文案、Lucide 线性图标、非颜色单一编码。

## Colors

调色板以黑白灰控制层级，以少量领域语义色表达无法被中性色替代的状态。

### Primary

- **控制台黑** (#171717): 浅色主题的主操作、选中状态和最高强调表面。
- **反相控制白** (#E5E5E5): 深色主题中的主操作，使操作在近黑背景上保持清晰。

### Secondary

- **静音灰面** (#F5F5F5 / #262626): 次操作、悬停、选择背景和支持性表面。
- **低声说明** (#525252 / #A3A3A3): 辅助说明、占位和次级元数据；
  浅色值比 shadcn 默认 Neutral 更深，以满足会迹既有的 7:1 阅读对比门槛。

### Tertiary

- **事实录音红** (#DC2626 / #FF6467): 仅用于正在录音、录音相关危险与明确错误。
- **负载琥珀** (#B45309 / #FBBF24): 用于 ASR 积压、温控、空间和其他可降级风险。
- **完整性绿** (#15803D / #4ADE80): 用于事实音频已保存、模型已校验等可验证结果。

### Neutral

- **控制台白** (#FFFFFF): 浅色应用画布。
- **控制台黑** (#0A0A0A): 深色应用画布，不由浅色主题机械反转生成。
- **墨黑正文 / 反相白正文** (#0A0A0A / #FAFAFA): 正文和主要图标。
- **面板表面** (#FFFFFF / #171717): 卡片、输入、Dialog 与浮层。
- **结构边界** (#E5E5E5 / rgba(255, 255, 255, 0.10)): 卡片、输入、分隔和轮廓控件的 1 px 边界。
- **焦点环** (#525252 / #D4D4D4): 键盘或无障碍焦点，必须立即出现。

**The Black-and-White First Rule.** 普通操作、选择和页面层级先使用黑白灰；语义色不能成为装饰。

**The Factual Red Rule.** 红色只表示正在录音、不可恢复的危险或明确错误，并且必须同时显示图标或文字。

**The Composed Dark Rule.** 深色主题使用独立的表面和文本关系，不对浅色值做自动反相。

## Typography

**Display Font:** Platform system UI (Roboto on Android, San Francisco on iOS, system Chinese fallback)
**Body Font:** Platform system UI (Roboto on Android, San Francisco on iOS, system Chinese fallback)
**Label/Mono Font:** Platform system UI

**Character:** 字体保持中性、清晰和低戏剧性，让状态文案与证据内容成为主角。标题不依赖斜体、
全大写或夸张字重制造层级，层级主要来自字号、位置和留白。

### Hierarchy

- **Display** (System UI, Regular, 20sp/pt, line-height 1.75): 页面内主要区段标题和空白状态标题。
- **Title** (System UI, Regular, 18sp/pt, line-height 1.75): 卡片标题、状态标题和页面次级标题。
- **Body** (System UI, Regular, 16sp/pt, line-height 1.5): 主要说明、转录与表单内容。
- **Label** (System UI, Regular, 14sp/pt, line-height 1.25): 时间、状态、辅助说明和紧凑控件标签。

Forui touch 字阶还提供 10、12、22、30、36、48、60、72、96 与 108 px 档位，但新页面
只应选择已有语义角色，不能为单个页面任意创建字号。正文阅读区域限制在 720 px 内，
时间、容量、进度和时间戳使用 tabular figures 保持数字位置稳定。

**The Quiet Type Rule.** 同一页面使用尽可能少的字号角色；强调先调整信息结构，再考虑增加字重或字号。

**The Real Copy Rule.** 控件使用明确中文动词，错误说明发生了什么、事实音频是否安全以及下一步操作。

## Layout

页面由 `FScaffold`、`FHeader`、`AppPageBody` 和可选 `AppBottomActionBar` 组成。
`AppPageBody` 统一安全区、16 px 页面留白与三种内容宽度：紧凑内容 480 px、阅读内容
720 px、宽工作台 1200 px。底部关键操作使用同样的宽度约束，不覆盖可滚动正文。

空间系统使用 4 pt 基线：4、8、12、16、24、32、48 px。12–16 px 用于同组内容，
24–32 px 用于区段分隔，48 px 只用于明显的大区段或最小触控尺寸。标题上方的间距应
大于标题与其说明之间的间距。

响应式只读取父约束：

- **Compact**：小于 600 px，单列，关键操作靠近底部安全区。
- **Medium**：600–839 px，按内容需要使用更宽阅读区或有限双列。
- **Expanded**：840 px 及以上，允许主从或双栏工作台。
- **Ultra-wide checkpoint**：1024 px，用于验证 1200 px 最大工作台与上下文栏布局。

会议列表在 expanded 宽度使用两列；录音与结果页面可以把事实区和转录/上下文区拆为
稳定双栏。宽屏不是手机页面等比拉伸，正文仍保持阅读宽度。

**The Constraint-Driven Rule.** 响应式只依据可用宽度，不读取设备型号、方向或平台字符串。

**The Stable Fact Rule.** ASR 降级、新转录或错误提示不得移动计时、事实音频状态和主要操作的位置。

## Elevation & Depth

系统平面为主。背景、卡片和次级表面通过 Neutral 明度差与 1 px 边界建立层级；
阴影仅用于需要从当前层级抬起的卡片或浮层。当前 Forui 主题只有一个极浅结构阴影：
向下偏移 1 px、模糊 2 px、黑色 5% 透明度。深色主题主要依赖表面明度和半透明白边界，
不使用发光描边。

### Shadow Vocabulary

- **结构微影** (`box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05)`): 卡片和浮层的最低限度空间分离。

**The Flat-by-Default Rule.** 静止页面保持平面；只有真正高于当前表面的组件才能使用阴影。

**The One-Depth-Signal Rule.** 同一组件优先选择边界或阴影中的一种，不叠加宽阴影与明显边框。

## Shapes

Forui 使用轻微连续曲率的 superellipse，而非夸张胶囊。圆角比例为 4、6、8、10、
14、18、22 与 26 px；100 px pill 只用于确实需要胶囊轮廓的小型 Badge 等紧凑元素。

按钮、输入与焦点轮廓通常使用 10 px；卡片使用 14 px；Dialog 和较高层级容器按
Forui 组件语义选择 10–18 px。所有边界默认 1 px。圆角不能替代信息分组，也不能把
每个文本区段变成独立卡片。

**The Compact Curve Rule.** 常规操作控件保持 8–10 px 紧凑曲率，禁止把普通按钮做成胶囊。

**The Container Restraint Rule.** 卡片只用于真实分组或可交互条目，不把连续阅读内容切成嵌套卡片。

## Components

组件以 Forui `F*` 控件为实现基座，项目共享组件只增加产品语义、布局约束和状态文案。

### Buttons

- **Shape:** 10 px superellipse；主要手机操作的视觉高度为 48 px，默认控件至少 44 px。
  Android 关键触控目标至少 48×48 dp，iOS 至少 44×44 pt。
- **Primary:** 浅色使用控制台黑与反相白文字，深色使用反相控制白与近黑文字。
- **Outline:** 卡片表面、1 px 结构边界和前景色文字；按下或悬停切换到静音灰面。
- **Ghost:** 默认透明，只在悬停、按下或选中时出现静音灰面。
- **Destructive:** 使用淡红表面和事实录音红文字；不可把删除操作伪装成普通主按钮。
- **Focus / Pressed:** 焦点环立即出现；按下反馈保持就地，不等待动画结束再触发操作。

### Badges

- **Style:** 仅承载短状态，使用 Neutral 次级表面；错误或空间不足使用 destructive 变体。
- **State:** Badge 必须包含明确文字，不能只显示颜色点，也不能承担主要操作。

### Cards / Containers

- **Corner Style:** 14 px superellipse。
- **Background:** 使用卡片表面；浅色与画布相同，靠边界、内容结构或微影分组。
- **Shadow Strategy:** 仅使用“结构微影”，不叠加装饰阴影。
- **Border:** 根据具体 Forui 组件使用 1 px Neutral 边界。
- **Internal Padding:** 默认 16 px；紧凑子组使用 12 px。

### Inputs / Fields

- **Style:** 卡片表面、1 px 输入边界、10 px superellipse，touch 模式默认至少 44 px 高。
- **Focus:** 使用高对比焦点环，不通过布局变化表达焦点。
- **Error / Disabled:** 错误使用 destructive 语义并提供恢复文案；禁用必须在附近说明原因。

### Navigation

页面上下文由 `FHeader` 提供。会议列表使用根 Header，子页面使用 nested Header 与明确返回语义。
页面必须通过 Flutter 原生 route 进入：Android 系统返回/预测返回与页面返回一致，iOS 保留
push 转场和左边缘返回手势；返回图形使用平台自适应 `BackButtonIcon`。当前产品没有底部导航，
设置是会议工作区的次级入口。

### Status Notice

`AppStatusNotice` 是会迹的签名状态组件。它以 `FAlert` 为结构，同时使用 Lucide 图标、
明确标题、可选说明和语义色图标，覆盖信息、录音、警告、错误与成功。标题先说明事实，
说明文字再解释影响和下一步；ASR 问题必须明确“录音仍在继续”。

### State Panel

`AppStatePanel` 统一页面级 loading、empty 和 error。空白状态由当前事实、用途说明和单一
下一步组成；错误状态保留原位恢复操作；没有回调时不渲染伪禁用按钮。

## Do's and Don'ts

### Do:

- **Do** 使用 shadcn/ui Neutral 语义关系映射 Forui，而不是在功能页面硬编码黑白灰。
- **Do** 让事实音频状态、计时和主要操作先于实时转录与 AI 辅助信息。
- **Do** 使用 4 pt 间距、480/720/1200 px 内容宽度和 600/840/1024 px 响应式检查点。
- **Do** 同时使用文字、图标和位置表达录音、错误、积压与完成状态。
- **Do** 为两端浅色、深色、手机/平板/多任务宽度和 2.0 字体缩放保留真实测试。
- **Do** 分别验证 Android 系统返回与 iOS 边缘返回、Dynamic Type 和 VoiceOver。
- **Do** 使用明确中文动词，并在失败文案中说明事实音频是否安全。

### Don't:

- **Don't** 使用品牌蓝、渐变、玻璃拟态、发光描边或装饰性彩色背景制造“AI 感”。
- **Don't** 把红、琥珀或绿用于普通按钮、装饰图标或无状态含义的强调。
- **Don't** 使用卡片套卡片、同尺寸功能卡矩阵或把连续转录拆成大量独立容器。
- **Don't** 使用装饰性波形、循环呼吸动画、滚动揭示或会延迟高频操作的动效。
- **Don't** 只靠颜色区分状态，也不要用模糊的 toast 替代页面内事实说明。
- **Don't** 在功能组件中硬编码颜色、圆角、字号、断点或重复间距。
- **Don't** 把 Android 前台服务、返回图形和导航转场原样移植到 iOS，反之亦然。
