---
kind: frontend_style
name: 会迹（MeetTrace）前端样式系统：Forui 设计令牌与灰阶账本风格
category: frontend_style
scope:
    - '**'
source_files:
    - pubspec.yaml
    - forui.yaml
    - DESIGN.md
    - lib/theme/theme.dart
    - lib/app/application.dart
    - lib/main.dart
---

## 系统与工具
- 使用 **Forui**（`forui: ^0.25.0`、`forui_cli: ^0.25.0`）作为跨平台 UI 组件库与设计令牌系统，Material 仅用于应用外壳与平台集成。
- 通过 `forui.yaml` 配置 CLI 输出路径：snippet 输出到 `lib`，style 输出到 `lib/theme/styles`，theme 输出到 `lib/theme/theme.dart`，字体下载到 `assets/fonts`。
- 主题由 Forui CLI 生成（`dart forui theme create --preset aabbbc`），在 `lib/theme/theme.dart` 中暴露 `lightTheme` / `darkTheme` 两个 `FThemeData`。
- 根入口 `lib/app/application.dart` 将 Forui 主题桥接为 Material 的 `toApproximateMaterialTheme()`，并通过 `FTheme` 包裹整个应用以启用 `context.theme`。

## 关键文件与包
- `pubspec.yaml`：声明 `forui`、`forui_cli` 依赖及 Flutter assets。
- `forui.yaml`：Forui CLI 输出目录约定。
- `DESIGN.md`：完整的设计系统规范（颜色、排版、间距、圆角、组件、响应式断点、Do/Don't 规则）。
- `lib/theme/theme.dart`：生成的主题入口，导出 light/dark 两套 `FThemeData`。
- `lib/app/application.dart`：应用外壳，注入 Forui 主题与本地化，并设置 MaterialApp 的 theme/darkTheme。
- `lib/theme/*.dart`（colors.dart、typography.dart、style.dart、icons.dart）：按 part 组织生成的颜色、排版、样式与图标令牌。
- `lib/main.dart`：引入 `system_ui.dart` 进行系统级 UI 配置。

## 架构与约定
- 设计令牌分层：`colors` → `typography` → `icons` → `style`，统一封装在 `FThemeData` 中，组件通过 `context.theme` 访问。
- 主题切换基于系统亮度：`Application` 根据 `Theme.brightnessOf(context)` 选择 light 或 dark 主题。
- 组件层优先使用 Forui 的 `F*` 原语，Material 仅处理平台外壳；业务 UI 位于 `lib/ui/features/...`。
- 响应式策略由 `DESIGN.md` 规定：320/375/414 单列，600–839px 增加留白，≥840px 主从布局，1024px 强制检查点；断点由可用宽度决定，不读取设备型号。
- 资产与字体：CLI 自动下载字体到 `assets/fonts`，模型清单与许可证放在 `assets/models` 与 `assets/licenses`。

## 视觉风格与约束
- 色彩体系为纯灰阶：浅色“账本纸面”+“记录白页”，深色“夜间纸面”+“夜间记录页”，状态通过文字、图标、边界与位置编码，禁止红/黄/绿/品牌蓝/渐变/玻璃/发光等装饰色。
- 排版采用系统无衬线体，层级仅用 400/500/600 三档字重；录音计时器是唯一允许超大字号的动态数字。
- 形状语言克制：4px/6px/8px/12px 四档圆角，常规 1px 分隔线，关键事实 2px，状态轨 3px；连续账本内部行保持直角。
- 阴影策略：静止状态零阴影，层级由纸面差、边界与空间关系表达；弹窗与覆盖层遵循 Forui/系统语义。
- 组件规范：按钮最小高度 48px、圆角 8px；输入框标签在上、6px 圆角、1px 强线边界；导航使用 `FScaffold`；Ledger Surface/Row 是会议-转录-证据的统一容器。
- Do/Don't 规则明确禁止悬浮卡片网格、装饰性波形、虚构 AI 可视化、登录/同步/云端录音等未规划功能。

## 约束来源
- `forui.yaml` 强制 CLI 输出路径约定。
- `DESIGN.md` 中的命名规则（如 “The Achromatic State Rule”、“Zero Resting Shadow Rule”、“Continuous Ledger Rule”）构成视觉与交互约束。
- `lib/app/application.dart` 通过 `FTheme` 与 `toApproximateMaterialTheme()` 强制所有 UI 走 Forui 令牌通道。
- `lib/theme/theme.dart` 注释指明主题由 Forui CLI 生成，修改需通过 CLI 流程而非手写。