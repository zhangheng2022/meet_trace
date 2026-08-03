---
kind: dependency_management
name: Flutter 依赖管理（pubspec + lockfile + skills-lock）
category: dependency_management
scope:
    - '**'
source_files:
    - pubspec.yaml
    - pubspec.lock
    - skills-lock.json
    - assets/models/manifest.json
    - assets/licenses/sense-voice-NOTICE.txt
    - assets/licenses/silero-vad-LICENSE.txt
---

本仓库使用 Flutter/Dart 生态的标准依赖管理体系，通过 `pubspec.yaml` 声明依赖、`pubspec.lock` 锁定版本，并额外使用 `skills-lock.json` 锁定 AI Skills 资源。整体策略如下：

1. **包管理器与声明文件**
   - 使用 `pub`（Flutter SDK 内置）作为包管理器。
   - 所有 Dart/Flutter 依赖在根目录 `pubspec.yaml` 中集中声明，分为 `dependencies`（运行时依赖）和 `dev_dependencies`（测试、lint、CLI 工具等开发期依赖）。
   - 项目明确设置 `publish_to: 'none'`，表明这是一个私有包，不发布到 pub.dev。

2. **版本约束与锁定机制**
   - `pubspec.yaml` 中对部分依赖使用精确版本号（如 `audioplayers: 6.8.1`、`record: 7.1.1`），对 UI 框架 `forui` 使用语义化版本范围 `^0.25.0`。
   - `pubspec.lock` 由 `pub` 自动生成，记录每个依赖的精确版本、sha256 校验和以及来源（`source: hosted`, `url: "https://pub.dev"` 或 `source: sdk`），确保构建可重复。
   - 所有第三方包均从官方 `pub.dev` 托管源拉取，未配置私有仓库或代理。

3. **平台相关依赖**
   - 音频录制与播放：`audioplayers`、`record` 及其各平台实现（android/ios/linux/macos/windows/web）。
   - 本地存储：`sqflite` + `sqflite_common_ffi`（桌面端 FFI 支持）+ `sqlite3`（dev 依赖，用于测试）。
   - 系统能力：`path_provider`、`connectivity_plus`、`share_plus`、`flutter_foreground_task`。
   - AI 推理：`sherpa_onnx` 及其多平台原生包（android_arm64/armeabi/x86/x86_64、ios、linux、macos、windows）。

4. **Skills 依赖锁定**
   - `skills-lock.json` 锁定 `.agents/skills/` 下的 AI Skills 资源，每个 skill 记录来源（GitHub 仓库）、路径和 `computedHash`，确保技能内容不可变。
   - Skills 来自多个上游：`dart-lang/skills`、`emilkowalski/skills`、`flutter/agent-plugins`、`mattpocock/skills`、`alibaba/open-code-review`、`obra/superpowers`。

5. **资产与许可证管理**
   - `pubspec.yaml` 的 `flutter.assets` 中声明模型清单与许可证文件（`assets/models/manifest.json`、`assets/licenses/*.txt`），随应用打包。
   - 模型权重本身不在包内，通过运行时按需下载（见 `assets/models/manifest.json`）。

6. **更新与维护约定**
   - `pubspec.yaml` 注释提示可使用 `flutter pub upgrade --major-versions` 进行大版本升级，或使用 `flutter pub outdated` 检查可用更新。
   - 未发现 CI/CD 中的自动依赖更新脚本，依赖更新为手动操作。

7. **无 vendoring / 无私有注册表**
   - 仓库未包含 `vendor/` 或 `packages/` 子模块，所有依赖通过 `pub get` 动态拉取。
   - 未配置 `pubspec_overrides.yaml`、`.pub-cache` 自定义源或 `PUB_HOSTED_URL` 环境变量。

关键文件：
- `pubspec.yaml` — 依赖声明与 Flutter 配置
- `pubspec.lock` — 依赖版本锁定
- `skills-lock.json` — AI Skills 资源锁定
- `assets/models/manifest.json` — 模型元数据清单
- `assets/licenses/*` — 第三方许可证文件