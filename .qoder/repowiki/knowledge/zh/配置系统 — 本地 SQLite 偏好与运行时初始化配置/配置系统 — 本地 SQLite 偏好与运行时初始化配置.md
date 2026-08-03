---
kind: configuration_system
name: 配置系统 — 本地 SQLite 偏好与运行时初始化配置
category: configuration_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - lib/main.dart
    - lib/data/services/storage/app_database.dart
    - lib/data/repositories/sqflite_model_preference_repository.dart
    - lib/data/repositories/sqflite_diarization_preference_repository.dart
    - lib/data/repositories/sqflite_runtime_download_consent_repository.dart
    - lib/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart
    - lib/app/meettrace_dependency_factories.dart
---

## 系统与架构

MeetTrace 没有使用通用的配置包（如 shared_preferences、flutter_config 等），而是基于 **SQLite（sqflite）** 自建了一个轻量级的应用级配置/偏好存储层。所有用户可变的运行时配置（默认 ASR 模型、说话人分离开关、移动端下载授权等）都持久化在 `app_settings` 表中，通过 Repository 模式暴露给上层 UseCase 和 ViewModel。

启动时配置由 `lib/main.dart` 统一编排：先初始化 Flutter 绑定 → 启用沉浸式状态栏 → 调用 `sherpaOnnxRuntimeInitializer.initialize()` 加载原生 ASR 引擎绑定 → 再启动应用根 Widget。ASR 引擎的配置（模型 ID、版本、语言、ITN 开关等）以 `SherpaOnnxRecognizerConfig` 对象形式在数据层构造并跨 Isolate 传递。

## 关键文件与位置

- `pubspec.yaml`：声明依赖（sqflite、path_provider、record、sherpa_onnx 等）、Flutter assets（模型清单 manifest.json、许可证文件）
- `lib/main.dart`：应用入口，顺序执行平台能力初始化与 ASR 运行时初始化
- `lib/data/services/storage/app_database.dart`：SQLite 数据库单例，定义 schema v1–v5，包含 `app_settings`（key/value 键值对表）及模型安装、任务队列等表
- `lib/data/repositories/sqflite_model_preference_repository.dart`：默认 ASR 模型偏好读写（key=`default_asr_model_id`）
- `lib/data/repositories/sqflite_diarization_preference_repository.dart`：说话人分离开关偏好（key=`speaker_diarization_enabled`）
- `lib/data/repositories/sqflite_runtime_download_consent_repository.dart`：移动端运行时资源下载授权（key=`runtime_mobile_download_consent`）
- `lib/data/services/asr/sherpa_onnx/sherpa_onnx_runtime_initializer.dart`：SherpaONNX 原生绑定的懒加载初始化器，封装初始化成功/失败状态
- `lib/app/meettrace_dependency_factories.dart`：组合根，将 storage、runtime、use_case 装配到各 ViewModel

## 架构与约定

1. **配置即键值对**：`app_settings` 表仅含 `key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER` 三列，所有偏好都是字符串序列化后的键值对，读取方自行解析（布尔用 `'true'/'false'` 字符串比较）。
2. **Repository 抽象**：每个偏好域一个 Repository 实现 `domain/ports/repositories.dart` 中定义的接口，便于测试替换。
3. **默认值回退**：当 key 不存在时，Repository 会回退到注册表或硬编码默认值（如 `registry.defaultModelId`）。
4. **事务写入**：所有写操作都在 `db.transaction` 中执行，保证 `updated_at` 时间戳原子更新。
5. **Schema 演进**：`AppDatabase.schemaVersion = 5`，通过 `onUpgrade` 按版本号增量迁移，v2 引入 `app_settings` 表，v3 引入模型相关表，v4 为 summaries 表添加 title 字段。
6. **运行时配置对象**：ASR 引擎配置通过 `SherpaOnnxRecognizerConfig` 类构造，支持 `senseVoice()` 工厂方法和 `fromMessage(Map)` 反序列化，用于跨 Isolate 通信。

## 约束与规则

- 所有偏好 key 以 `static const` 形式声明在对应 Repository 中，避免魔法字符串散落。
- `app_settings.updated_at` 始终写入 UTC 毫秒时间戳，用于审计与排序。
- 读操作若 key 不存在则返回领域默认值，而非抛错；写操作采用 update-or-insert 模式（先 update，影响行数为 0 时再 insert）。
- 模型 ID 写入前必须通过 `registry.requireById(modelId)` 校验，防止非法值入库。
- Alpha 阶段不支持从 v1 直接升级到 v5，升级路径被显式阻断并抛出 `UnsupportedAlphaInstallationException`。
- 运行时下载授权仅记录最后一次授予的 `resourceSetId`，覆盖式更新而非追加历史。

## 未覆盖场景

- 无 `.env` 文件或环境变量注入机制（除 Impeccable 工具链的环境变量外）。
- 无远程配置中心或 A/B 实验开关。
- 无独立的 feature flag 框架，功能开关通过 SQLite 中的 `app_settings` 键控制。
- 无配置文件热重载，修改需重启应用生效。