# Android Alpha 设备矩阵

> 状态：Step 00 已完成，Step 01 进行中
> 更新日期：2026-07-24

## 平台基线

| 项目 | 当前基线 |
|---|---|
| 最低 Android 版本 | Android 7.0 / API 24 |
| Alpha 必验 ABI | `arm64-v8a` |
| Flutter | stable 3.44.7 |
| Dart | 3.12.2 |
| Android 编译 SDK | Flutter 工具链默认值，当前环境为 SDK 36 |
| Java/Kotlin 字节码目标 | Java 17 / JVM 17 |

`android/app/build.gradle.kts` 显式固定 `minSdk = 24`。`arm64-v8a` 是 Alpha 必须验证的 ABI，不限制开发阶段的通用 Debug APK；升级 Flutter 或官方 `sherpa_onnx` 包时，不得静默提高最低系统版本，增加发布 ABI 前必须重新检查 APK 体积和真机兼容性。

## 开发与验收设备

| 角色 | 设备 | 系统/ABI | 当前状态 | 用途 |
|---|---|---|---|---|
| 主开发机 | Xiaomi Mi 10（约 8 GB RAM） | Android 11 / API 30 / arm64-v8a | 旧模型历史证据不可作为 SenseVoice 验收 | SenseVoice 下载、UI、录音和模型功能冒烟 |
| 最低系统设备 | 待提供的 API 24 arm64 真机 | Android 7.0 / arm64 | 未就绪 | 最低系统安装、权限、录音恢复 |
| 低端性能设备 | 待选择的 4 GB RAM arm64 真机 | Android 9～11 / arm64 | 未就绪 | SenseVoice RTF、延迟、内存、耗电和温控 |

## 使用规则

- 模拟器不能替代 ASR、录音连续性、耗电和温控验收。
- 通用 Debug APK 可以包含多个 ABI；发布产物的 ABI 拆分策略在 Step 18 确认。
- Mi 10 只能证明主开发链可运行，不能代表最低设备门槛。
- 必须补齐低端性能设备和当前 SenseVoice 指标，才能做 Go/No-Go。
- Step 18 发布前必须补齐最低系统设备，并保存设备型号、系统、ABI、内存和测试结果。
- 设备序列号不进入仓库。
