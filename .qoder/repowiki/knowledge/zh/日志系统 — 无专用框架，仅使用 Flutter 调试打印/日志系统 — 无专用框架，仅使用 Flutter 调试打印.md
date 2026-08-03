---
kind: logging_system
name: 日志系统 — 无专用框架，仅使用 Flutter 调试打印
category: logging_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - lib/main.dart
    - integration_test/live_preview_replay_test.dart
    - integration_test/reliable_recording_test.dart
---

本仓库未实现专门的日志系统。代码中未发现任何第三方日志库（如 `logging`、`logger`、`flutter_logging` 等）的依赖或初始化代码，也未定义统一的日志级别、结构化字段或日志输出通道。

实际使用的日志方式：
- 仅在集成测试中使用 `debugPrintSynchronously` 进行调试输出（见 `integration_test/live_preview_replay_test.dart` 与 `integration_test/reliable_recording_test.dart`）。
- 业务代码中未见 `print`、`debugPrint`、`log` 等调用，说明当前版本未在生产代码中主动输出日志。
- `pubspec.yaml` 的 dependencies 与 dev_dependencies 中均无日志相关包。
- `lib/main.dart` 启动流程中也没有对日志框架进行初始化。

结论：该项目目前处于“无日志系统”状态，所有调试输出仅通过 Flutter SDK 提供的 `debugPrint*` API 在测试阶段使用，生产代码未引入结构化日志、分级控制或集中式日志收集机制。