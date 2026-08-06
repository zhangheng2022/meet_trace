# 会迹（MeetTrace）Android Alpha 设备矩阵

> 状态：活动；V1.0 仓库实现、说话人分离与目标真机发布证据阻塞
> 更新日期：2026-08-06

## 平台基线

| 项目 | 当前基线 |
|---|---|
| 最低 Android 版本 | Android 7.0 / API 24 |
| Alpha 必验 ABI | `arm64-v8a` |
| Flutter | stable 3.44.7 |
| Dart | 3.12.2 |
| Android 编译 SDK | Flutter 工具链默认值，当前环境为 SDK 36 |
| Java/Kotlin 字节码目标 | Java 17 / JVM 17 |
| Alpha 应用标识 | `com.meettrace.app`；Debug APK 已由 `aapt` 复验 |
| Alpha 分发 | `com.meettrace.app` 签名 `arm64-v8a` APK；双平台验收后由当前仓库 GitHub Pre-release 公开安装 |

`android/app/build.gradle.kts` 显式固定 `minSdk = 24`。`arm64-v8a` 是 Alpha 必须验证的 ABI，不限制开发阶段的通用 Debug APK；升级 Flutter 或官方 `sherpa_onnx` 包时，不得静默提高最低系统版本，增加发布 ABI 前必须重新检查 APK 体积和真机兼容性。

## 开发与验收设备

| 角色 | 设备 | 系统/ABI | 当前状态 | 用途 |
|---|---|---|---|---|
| 功能冒烟 | Pixel 10 AVD | Android 16 / API 36 / x86_64 | 已完成首次初始化、断网重启、录音、封存、最终转录和系统 WAV 分享；取消分享及冷启动缓存恢复已通过 | 仅验证功能主链，不替代 arm64 真机、接收端播放、性能、后台或温控证据 |
| 主开发机 | Xiaomi Mi 10（约 8 GB RAM） | Android 11 / API 30 / arm64-v8a | 已连接；旧 `com.example.meettrace` 已按不保留策略卸载，新 `com.meettrace.app` 安装等待 MIUI 的 USB 安装确认 | 286.3 MB 初始化、UI、录音、联合最终处理、标签和 WAV 分享冒烟 |
| 最低系统设备 | 待提供的 API 24 arm64 真机 | Android 7.0 / arm64 | 未就绪 | 最低系统安装、权限、录音恢复 |
| 低端性能设备 | 待选择的 4 GB RAM arm64 真机 | Android 9～11 / arm64 | 未就绪 | SenseVoice 与说话人分离 RTF/DER/人数误差、内存、耗电和温控 |

## 使用规则

- 模拟器不能替代 ASR、说话人分离、录音连续性、耗电和温控验收。
- 通用 Debug APK 可以包含多个 ABI；公开 Alpha APK 必须只包含 `arm64-v8a`，工作流解包审计后才允许进入 Draft Release。
- Mi 10 只能证明主开发链可运行，不能代表最低设备门槛。
- 必须补齐低端性能设备、当前 SenseVoice 指标和普通话说话人分离指标，才能做 Go/No-Go。
- 发布前必须补齐最低系统设备，并保存设备型号、系统、ABI、内存和测试结果。
- 文本分享与音频分享分别验证；音频分享必须二次确认，临时 WAV 在完成、取消和失败后均无残留。
- 设备序列号不进入仓库。

## 2026-08-04 Pixel 10 模拟器冒烟证据

- 环境为 Android 16 / API 36 / x86_64；安装并启动 `com.meettrace.app` 成功。
- 首次初始化完成全部固定运行时资产下载、校验与激活；关闭 Wi-Fi 和移动数据后强停重启，5 秒内直接进入首页且未重复下载。
- 麦克风与通知权限授予后录音前台服务启动，`recording.pcm.tmp` 持续增长并写入检查点；结束后原子封存为 `fact.pcm`，约 1 分 27 秒、2.8 MB。
- SenseVoice 最终转录完成；模拟器无有效语音输入，按 15 秒窗口输出空白标点。说话人分离不可用时按单一说话人正常降级。
- 独立音频分享确认页准确显示会议名、`01:27`、`2.7 MiB WAV` 和敏感信息提醒；系统分享面板仅收到 `meeting-audio.wav`，源 `fact.pcm` 保持不变。
- 修复后复验：系统分享面板打开期间 `cache/share_plus/meeting-audio.wav` 保持可用；取消并回到应用后，插件缓存与应用自有分享临时目录均已删除，强停冷启动也能恢复清理旧插件缓存，事实源 `fact.pcm` 大小不变。取消/冷启动子项已通过；接收端完成分享、播放及 arm64 真机全路径仍需外部门禁留证，不能据此宣称 AT-18 整项通过。
