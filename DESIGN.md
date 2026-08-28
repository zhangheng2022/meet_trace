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

## 定位

**Creative North Star: "安静的事实账本 / The Quiet Evidence Ledger"**

会迹把会议呈现为一本正在持续写入、可以逐层回溯的事实账本。纸面、时间轨道与专业录音设备的秩序感构成品牌识别；界面不靠品牌色或 AI 装饰制造“智能感”，而是让用户先确认录音是否安全，再阅读实时预览，最后回到带说话人标签的最终转录与对应音频。

这套系统的气质是冷静、明确、可靠、低噪声。信息密度接近原生记录工具：手机保持克制单列，平板将会议索引与事实详情并置；动效只确认操作与状态变化，不承担装饰。已确认的反向参照是卡片仪表盘、装饰性波形、彩色状态、渐变、玻璃、发光、漂浮阴影和虚构 AI 可视化。

- 连续记录条取代卡片网格，时间轨道贯穿会议、转录与音频核对。
- 纯灰阶语义，状态通过文字、图标、边界、位置和填充共同编码。
- 录音计时器是唯一允许占据超大字号的动态数字。
- 低曲率、细分隔线、静止状态零阴影。
- 手机单列直达任务，平板使用索引与事实工作区的主从布局。
- Android、iOS 与 Windows 共享视觉令牌，但保留各自原生导航、手势/键鼠、窗口、安全区和辅助技术语义。

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

## 色彩

颜色以文件头的令牌为准：暖白纸面、白色内容面、事实墨色与中性灰。所有语义状态必须同时使用文字、图标或边界，不能只靠颜色；实心墨色只给当前最重要的操作或状态，同一视口最多两个大面积墨块。

## 排版

使用平台系统无衬线体；字号、行高和字重以文件头令牌为准。全局只用 400、500、600 三档字重，时间与计时启用等宽数字。56px 级大号数字只属于录音计时器；紧凑手机可降至 40px，平板最大 64px。长文本阅读区最大宽度 760px。

## Layout

布局建立在 4pt 节奏上，复用 4、8、12、16、24、32、48 的间距级别。页面默认水平留白为 16px；紧凑表单最大宽度 520px，长文本阅读区最大宽度 760px，扩展工作台最大宽度 1280px。触控目标以 48×48 为共享下限，并在 iOS 上保留至少 44pt 的原生要求。

小于 600px 使用单列，关键操作固定在底部安全区，会议行点击后直接进入详情。600–839px 仍保持单一阅读顺序，只增加留白和内容宽度。840px 起允许主从布局：首页左侧为约 400–480px 的会议账本，右侧为事实预览；会议详情采用 280px 事实栏与转录工作区。1024px 是强制视觉检查点，不是另一套视觉语言。

Windows 窗口最小内容尺寸约为 840×640，因此默认进入现有 expanded 主从布局；窗口仍允许放大和最大化，不创建 Windows 专属业务页面。录音中 close 转入系统托盘时必须给出明确反馈，重新激活后恢复原导航和焦点上下文；空闲 close 正常退出。

列表、状态和转录按内容自然增高，不用固定高度裁切文本。必须在 320、375、414、768、1024 宽度以及 2.0 字体缩放下保持关键事实与操作可见，不产生横向溢出。

同类记录属于连续表面，以分隔线和时间轨组织。响应式只读取可用宽度，不读取设备型号、方向或平台字符串。ASR 状态变化不得移动计时器、事实音频状态、暂停或结束操作。

## 层级与形状

静止状态不使用阴影；层级依靠纸面差、1px 分隔线、2px 强边界、3px 状态轨和留白。圆角只使用文件头定义的 4/6/8/12px；连续账本内部行保持直角并共享边界，禁止胶囊、卡片套卡片和任意半径。

## Components

组件优先使用 Forui 的 `F*` 原语，通过 `context.theme` 与 `AppStyle` 取得令牌。Material 只负责应用外壳、平台集成或已记录的能力缺口。

### 通用控件

- 按钮和输入最小高度 48px；每页一个主操作。焦点使用清晰的 2px 轮廓，状态变化约 120ms，可中断；减少动态时即时切换。
- 输入标签始终在字段上方；错误和禁用必须有文案与非颜色线索，占位符不能替代标签。
- 容器默认 16px 内边距，紧凑行/通知 12px，录音仪器 24px；静止状态无阴影。

### Navigation

- **Style:** `FScaffold` 提供页面结构，标题直接、左对齐，页面级动作数量保持克制。
- **Android:** 保留系统预测返回、Material 导航语义与 Android 安全区。
- **iOS:** 保留边缘返回手势、Dynamic Type、VoiceOver 与 iOS 安全区。
- **Windows:** 保留窗口 close/minimize/maximize、鼠标悬停、Tab 焦点、Enter/Space 激活、系统托盘和 Windows 屏幕阅读器语义；单实例再次启动只聚焦已有窗口。
- **Tablet:** 首页账本行负责选择，右侧“打开完整记录”负责进入详情；手机账本行直接进入详情。

### Ledger Surface / Ledger Row

会议与转录共用的签名组件。每行包含 64px 时间列、连续事实轨、标题与时长、说话人标签、状态图标和事实文案；普通行垂直内边距为 12px。正在录音或被选中的行使用静默灰面，录音状态使用墨色徽标与文字，不使用彩色直播效果。长标题或长状态必须纵向堆叠，不能与尾部状态碰撞。

会议列表的重命名与删除共用向左滑动揭示的尾部操作区，不允许完整滑动直接执行。重命名使用静默灰面中性动作，打开预填当前标题的底部编辑面板；删除使用墨色破坏性动作，并再次确认将清除事实音频、转录、说话人标签、处理记录和分享临时文件。一次只能展开一行，点击行、滚动列表或展开其他行时收起。所有未删除状态均可重命名；录音中与后台处理中的会议只揭示重命名，不提供删除。辅助技术必须分别暴露“重命名”和“删除”的明确动作名称与结果反馈。

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
- **Do** 保留 Android、iOS 与 Windows 原生返回、手势/键鼠、窗口、安全区、字体缩放和辅助技术行为。
- **Do** 在紧凑手机、平板、Windows 840×640/1024px、浅色、深色和 2.0 字体缩放下验证真实内容与长文案。

### Don't:

- **Don't** 使用红、黄、绿、品牌蓝、渐变、玻璃、发光或 AI 装饰色。
- **Don't** 使用悬浮卡片网格、卡片套卡片、装饰性波形、重复时间刻度或虚构音量动画。
- **Don't** 用颜色单独表达录音、成功、警告、失败或模型状态。
- **Don't** 引入登录、同步、云端录音、虚构容量、虚构转录或未规划功能。
- **Don't** 在录音开始后暗中切换模型，或让派生处理状态干扰事实录音控制。
- **Don't** 为追求跨平台像素一致而覆盖 Android、iOS 与 Windows 的原生交互。
