<div align="center">
  <img src="assets/branding/stitch/meettrace-app-icon.svg" width="112" alt="会迹 MeetTrace 图标">
  <h1>会迹（MeetTrace）</h1>
  <p><strong>本地优先、可核对、不会为推理牺牲录音的会议记录应用。</strong></p>
  <p>Flutter · Android / iOS · 端侧 ASR · 本地事实音频</p>
</div>

<div align="center">
  <strong><a href="https://github.com/zhangheng2022/meet_trace/releases/download/v1.0.0-alpha.2/meettrace-v1.0.0-alpha.2-android-arm64.apk">下载 Android 测试 APK（v1.0.0-alpha.2）</a></strong>
  · <a href="https://github.com/zhangheng2022/meet_trace/releases/tag/v1.0.0-alpha.2">发布说明</a>
  · <a href="docs/README.md">项目文档</a>
</div>

会迹是一款采用 MIT License、面向个人会议记录的开源 Flutter 应用。它持续保存设备上的事实音频，并使用端侧模型生成会中预览和最终转录；网络或推理异常不能中断录音。

> [!WARNING]
> **项目仍处于 Alpha 阶段，不适合不可恢复的重要录音。** Android 是当前主要验证基线；iOS 已有构建和 TestFlight 上传证据，但目标真机验收尚未闭环。说话人分离还存在已接受的上游内存风险，失败时会降级为单一说话人结果，不影响事实录音和最终文本。

## 安装测试版

- APK 仅支持 Android 7.0+ 的 `arm64-v8a` 设备，需要允许当前来源安装未知应用。
- 首次启动约下载 286.3 MB 运行资源，并要求应用所在卷至少有 1 GiB 可用空间。
- 应用不提供登录或云同步；卸载会删除本机数据，Alpha 升级也可能清除旧数据并重新下载模型。
- iOS 仅通过 TestFlight 分发；当前外部测试链接待提供。

全部公开版本见 [GitHub Releases](https://github.com/zhangheng2022/meet_trace/releases)。

## 核心能力

- 可靠的本地会议录音、检查点与异常恢复，音频写入和推理解耦。
- SenseVoice 端侧会中预览与完整音频最终转录，使用 Silero VAD 控制预览任务。
- Pyannote + 3D-Speaker 离线说话人分离；失败时发布可用的单一说话人结果。
- 最终结果播放、重试、说话人标签修订，以及相互独立的文本和音频分享。
- 首次初始化下载、断点续传、严格哈希校验和资源修复。

登录、跨设备同步、云端 ASR、AI 总结、日历机器人和会议中切换模型不在当前 Alpha 范围。完整范围以 [Alpha PRD](docs/product/Alpha_PRD_无登录版.md) 为准。

## 隐私与数据边界

- 音频、转录、模型和派生数据默认保存在应用私有目录。
- 只有用户主动分享文本或二次确认分享音频时，数据才进入系统分享面板。
- 音频分享从事实 PCM 生成临时 WAV，完成、取消或失败后清理，不改写源录音。
- Release 默认启用 Sentry 远程诊断，但不主动附加事实音频、WAV、转录快照或说话人结果。
- 删除会议会级联删除该会议的音频、转录、标签和处理记录。

## 平台状态

| 平台 | 最低目标 | 状态 |
|---|---:|---|
| Android | API 24 / Android 7.0 | 当前开发与验证基线 |
| iOS | iOS 15.0 | 构建与 TestFlight 最低基线；当前设备真机验收未闭环 |
| 其他平台 | — | 不属于 Alpha 支持范围 |

## 技术概览

项目遵循 `View → ViewModel → Use Case / Port → Repository / Service`。Domain 保持纯 Dart，UI 不直接访问 SQLite、HTTP、录音插件或 ONNX；ASR 仅通过官方 `sherpa_onnx` Flutter/Dart 包接入。

运行时固定使用 SenseVoice INT8、Silero VAD、Pyannote INT8 和 3D-Speaker。模型权重不进入 APK/IPA，而是在首次初始化时按固定 Manifest 下载并校验。详细设计见[技术方案](docs/technical/端侧_SenseVoice_转录技术方案.md)，当前设备与发布门槛见[质量与验收](docs/quality/README.md)。

## 开始开发

环境要求：Flutter stable、Dart 3.12+；Android 使用 JDK 17，iOS 需要 macOS、Xcode 和 CocoaPods。

```bash
git clone https://github.com/zhangheng2022/meet_trace.git
cd meet_trace
flutter pub get
flutter run -d <device-id>
```

提交前至少运行：

```bash
dart format lib test
flutter analyze
flutter test
```

调试构建命令：

```bash
flutter build apk --debug
flutter build ios --debug --no-codesign
```

正式候选必须从统一 `Alpha Release` 入口生成；Android 与 iOS 同一 SHA 验收通过后才公开原 Android APK，iOS 不向 GitHub 上传 IPA。维护者操作见 [GitHub Alpha 版本发布流程](docs/project/GitHub_版本发布流程.md)。

## 参与贡献

开始修改前请阅读：

- [项目文档中心](docs/README.md)：活动文档、权威关系和阅读路径。
- [Alpha PRD](docs/product/Alpha_PRD_无登录版.md)：产品范围与验收标准。
- [交互与视觉规范](DESIGN.md)：Forui、主题和双平台 UI 规则。
- [仓库协作指南](AGENTS.md)：架构、测试、审查和安全约束。

产品范围或 P0 验收变化必须先更新 PRD。不要提交录音、模型权重、密钥、`build/` 或 `coverage/`。当前质量状态和剩余门槛见[质量与验收](docs/quality/README.md)。

## 许可证

项目代码基于 [MIT License](LICENSE) 开源。第三方依赖与模型适用各自许可证，来源、固定哈希和许可文本见 [assets/licenses](assets/licenses/)。
