---
kind: build_system
name: Flutter 多端构建与发布体系
category: build_system
scope:
    - '**'
source_files:
    - pubspec.yaml
    - analysis_options.yaml
    - android/build.gradle.kts
    - android/app/build.gradle.kts
    - tool/benchmarks/evaluate_alpha_release.dart
    - tool/benchmarks/inspect_debug_apk.ps1
---

## 1. 构建系统与工具链
- **核心框架**：Flutter（SDK ^3.12.2），通过 `pubspec.yaml` 统一管理 Dart/Flutter 依赖、资产与版本。
- **Android 构建**：Gradle Kotlin DSL（`android/build.gradle.kts` + `android/app/build.gradle.kts`），使用 `dev.flutter.flutter-gradle-plugin`，Java/Kotlin 目标为 17，minSdk=24。
- **iOS/macOS 构建**：Xcode 工程（`ios/Runner.xcworkspace`、`macos/Runner.xcworkspace`），通过 `.xcconfig` 管理 Debug/Release 配置。
- **Linux/Windows 桌面构建**：CMake 工程（各平台 `CMakeLists.txt` + `runner/` 原生入口）。
- **Web 构建**：标准 Flutter Web 输出（`web/index.html` + `manifest.json`）。

## 2. 关键构建文件与职责
- `pubspec.yaml`：声明应用名、版本（`1.0.0+1`）、SDK 约束、依赖、assets（模型清单与许可证文件）。
- `analysis_options.yaml`：启用 `flutter_lints`，开启 strict-casts/inference/raw-types 静态检查。
- `android/build.gradle.kts`：统一仓库源（google/mavenCentral），将构建产物重定向到根 `build/` 目录，提供 `clean` 任务。
- `android/app/build.gradle.kts`：定义 applicationId、minSdk/targetSdk、versionCode/versionName（由 Flutter 注入）、release 签名（当前用 debug 密钥）、Live Preview Replay 测试包后缀逻辑。
- `tool/benchmarks/evaluate_alpha_release.dart`：Alpha 发布门禁 CLI，读取 JSON 输入并输出结构化报告，根据决策设置退出码（0=go, 1=noGo, 2=blocked）。
- `tool/benchmarks/inspect_debug_apk.ps1`：Windows 端 APK 检查脚本。

## 3. 构建架构与约定
- **单仓多端**：一个 `pubspec.yaml` 驱动 Android/iOS/Linux/macOS/Windows/Web 六端构建，原生宿主工程按平台分目录组织。
- **版本策略**：`pubspec.yaml` 中 `version: 1.0.0+1`，Android 的 versionName/versionCode 与 iOS 的 CFBundleShortVersionString/CFBundleVersion 均由 Flutter 注入；可通过 `--build-name` / `--build-number` 覆盖。
- **构建产物隔离**：Android Gradle 将所有子项目构建目录统一到根 `build/` 下，避免散落。
- **测试专用包变体**：当 target 以 `integration_test/live_preview_replay_test.dart` 结尾或环境变量 `MEETTRACE_REPLAY_TEST_PACKAGE=true` 时，自动追加 `.replaytest` 后缀，生成独立测试包。
- **Assets 打包**：模型 manifest 与第三方许可证文件通过 `flutter.assets` 显式声明，随应用一起打包。

## 4. 质量与发布流程
- **静态分析**：`flutter analyze` 基于 `analysis_options.yaml` 执行 lint，IDE 与 CI 可集成。
- **单元测试/集成测试**：`test/` 与 `integration_test/` 目录，配合 `flutter test` 与 `flutter drive` 运行。
- **Alpha 发布门禁**：`tool/benchmarks/evaluate_alpha_release.dart` 作为发布前校验工具，依据输入 JSON 判定 go/noGo/blocked，并通过退出码供 CI 拦截。
- **桌面端构建**：Linux/macOS/Windows 分别通过各自平台的 CMake/Xcode 工程构建，遵循 Flutter 官方模板结构。

## 5. 约束与规范
- SDK 版本锁定为 `^3.12.2`，禁止随意升级。
- Android compileSdk/targetSdk 由 Flutter 插件动态提供，不得硬编码。
- Release 构建当前使用 debug 签名配置，正式发布需替换为正式签名。
- 所有 Lint 规则继承自 `package:flutter_lints/flutter.yaml`，仅允许通过 `// ignore:` 局部抑制。
- 包不发布到 pub.dev（`publish_to: 'none'`），为私有包。