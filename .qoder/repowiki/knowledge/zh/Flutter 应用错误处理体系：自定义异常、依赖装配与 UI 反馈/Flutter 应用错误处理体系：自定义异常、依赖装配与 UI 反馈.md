---
kind: error_handling
name: Flutter 应用错误处理体系：自定义异常、依赖装配与 UI 反馈
category: error_handling
scope:
    - '**'
source_files:
    - lib/data/services/storage/app_database.dart
    - lib/app/meettrace_dependencies.dart
    - lib/app/meettrace_storage_dependencies.dart
    - lib/app/meettrace_flow.dart
    - lib/ui/core/app_dialog.dart
    - lib/data/models/runtime/silero_vad_manifest.dart
---

该 Flutter 多端应用在错误处理上采用「分层抛出 + 统一捕获 + 用户友好提示」的模式，核心围绕自定义 Exception、依赖装配阶段的 try/catch 以及统一的对话框 UI 展开。

1. 系统/方法
- 使用 Dart 原生 `Exception`/`Error` 机制，通过自定义 `Exception` 子类表达业务级错误，而非返回码或字符串。
- 在依赖装配阶段集中使用 `try/on Object catch` 捕获所有异常，确保资源释放后再重新抛出，避免部分初始化成功导致的泄漏。
- 在 UI 层通过 FutureBuilder 的 `snapshot.hasError` 分支和统一的 `showAppAlertDialog` 向用户展示错误信息。

2. 关键文件与包
- `lib/data/services/storage/app_database.dart`：定义 `UnsupportedAlphaInstallationException`，在数据库 schema 升级路径中抛出，阻止不兼容的 Alpha 版本数据原地升级。
- `lib/app/meettrace_dependencies.dart`：顶层依赖装配入口，集中捕获 Storage/Runtime/Meeting 三层依赖创建过程中的异常，保证 dispose 顺序正确。
- `lib/app/meettrace_storage_dependencies.dart`：存储层依赖装配，同样使用 `_disposeStorage` 辅助函数统一回收资源并选择性保留错误。
- `lib/app/meettrace_flow.dart`：启动流程中使用 `FutureBuilder` 捕获依赖创建错误，区分 `UnsupportedAlphaInstallationException` 与普通错误，分别给出不同提示文案与重试逻辑。
- `lib/ui/core/app_dialog.dart`：提供 `showAppAlertDialog` 和 `showAppConfirmDialog` 两个统一对话框 API，所有错误提示均通过此接口呈现。
- `lib/data/models/runtime/silero_vad_manifest.dart`：模型清单解析时抛出 `FormatException`，用于校验 JSON 结构、字段类型与安全路径。

3. 架构与约定
- 异常分类：业务异常（如 `UnsupportedAlphaInstallationException`）实现 `Exception`；格式/契约错误使用 Dart 内置 `FormatException`。
- 资源清理优先：所有 `create()` 工厂方法内部维护局部变量记录已创建的资源，在 `catch` 块中按逆序调用 `dispose`/`close`，再通过 `preserveError` 参数控制是否保留原始异常。
- 启动门控：`MeetTraceBootstrap` 作为唯一入口，将依赖创建失败收敛到单一错误视图，避免崩溃白屏。
- UI 反馈统一：所有用户可见的错误消息都通过 `showAppAlertDialog` 弹出，标题语义化（如「无法开始会议」），消息内容针对具体场景定制。

4. 约定与约束
- 禁止直接 `throw 'string'`：所有可恢复的业务错误必须封装为 `Exception` 子类。
- 依赖装配必须包裹 try/catch：任何可能失败的 `create()` 方法需捕获 `Object` 并执行资源清理。
- UI 层不得直接使用 `print`/`debugPrint` 报告错误：必须通过 `showAppAlertDialog` 或路由跳转后的 ViewModel 状态反馈。
- 数据库升级路径中遇到不兼容旧版本必须抛出 `UnsupportedAlphaInstallationException`，由上层区分处理。