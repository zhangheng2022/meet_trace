# 仓库指南

## 产品边界

Meetily 是两周交付的 Android Alpha，不提供登录或跨设备同步。本地音频是唯一事实源；推理变慢或失败时，录音必须继续。端侧 ASR 使用 sherpa-onnx 双模型：内置标准模型 `sherpa-onnx-paraformer-zh-small-2024-03-09` INT8，高级模型 `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25` 按需下载。设置保存全局默认，开始会议可覆盖本场选择；录音开始后模型锁定，所选模型同时负责会中和最终转录，不得自动切换或混合输出。AI 总结只能基于最终转录；使用云端 AI 时仅上传最终文本，并为关键结论保留带时间戳的原文证据。说话人分离属于可降级能力。扩展 P0 前必须先更新 PRD。

## 架构与项目结构

遵循 `View → ViewModel → Repository → Service`：

- `lib/ui/features/<feature>/{views,view_models}/`：精简页面和展示状态。
- `lib/ui/core/`：共享 Forui 组件和 UI 工具。
- `lib/domain/{models,use_cases}/`：业务概念和可复用编排。
- `lib/data/{models,repositories,services}/`：持久化、HTTP、音频、模型管理和 ASR 适配器。

UI 不得直接调用 ONNX、存储或 HTTP。两个模型分别实现统一 `AsrEngine`，由 Factory 按会议锁定的模型创建；具体 Engine 不得泄漏到 UI 或 ViewModel。音频写入与 ASR 必须独立运行；有界队列可以丢弃实时预览任务，但不能丢失录音。原生桥接代码放在 `android/`，`test/` 镜像源码路径，真机流程放在 `integration_test/`，需求和技术决策放在 `docs/`。

## Forui 优先

优先使用 Forui 的 `F*` 组件和 `context.theme` 令牌。仅在应用外壳、平台集成或已记录的能力缺口中使用 Material。禁止在功能组件中硬编码颜色、字体、圆角和重复间距；统一扩展 `lib/theme/`。CLI 管理的文件应通过 `dart forui theme create --preset aabbbc` 等命令重新生成。组件测试必须使用真实的 `Application`/`FTheme` 外壳。

## 技能与实现流程

新增功能或重构时使用 `flutter-apply-architecture-best-practices`。行为变更使用 `flutter-add-widget-test` 或 `dart-add-unit-test`，交付前使用 `dart-run-static-analysis`。集成 sherpa-onnx 时遵循 `dart-use-ffigen` 和 `dart-setup-ffi-assets`，必须从头文件生成绑定。变更产品范围或 P0 验收标准前运行 `$grill-me`。活动文档入口为 `docs/README.md`；旧方案不在 `docs/` 保留活动副本，历史由 Git 保存。

## 常用命令与质量门槛

- `flutter pub get`：解析依赖。
- `flutter run -d <device-id>`：在 Android 设备上运行。
- `dart format lib test integration_test`：格式化 Dart 源码。
- `flutter analyze`：执行 `flutter_lints` 静态检查。
- `flutter test`：运行单元测试和组件测试。
- `flutter test integration_test`：运行支持的设备流程。
- `flutter build apk --debug`：构建 Alpha 调试 APK。

测试文件使用 `*_test.dart`。优先覆盖录音连续性、模型校验、会议模型锁定、积压恢复、转录排序、快照原子切换、证据映射，以及 Forui 的加载、空白和错误状态。双模型必须在相同语料与设备上对比 RTF、延迟、内存、能耗、温控和关键事实召回率。

## 提交、PR 与安全

提交标题应简短并使用祈使语气，例如 `增加 ASR 积压恢复`。PR 必须引用对应 PRD 章节，说明用户影响，列出验证命令；UI 变更需附截图。禁止提交密钥、录音、下载的模型、`build/` 或 `coverage/`。
