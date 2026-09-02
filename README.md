<div align="center">
  <img src="assets/branding/stitch/meettrace-app-icon.svg" width="112" alt="会迹 MeetTrace 图标">
  <h1>会迹（MeetTrace）</h1>
  <p><strong>本地优先、可核对、不会为推理牺牲录音的会议记录应用。</strong></p>
  <p>Flutter · Android / iOS · Windows 规划中 · 端侧 ASR · 本地事实音频</p>
</div>

<div align="center">
  <strong><a href="https://github.com/zhangheng2022/meet_trace/releases/download/v1.0.0-alpha.10/meettrace-v1.0.0-alpha.10-android-arm64.apk">Android APK</a></strong>
  · <strong><a href="https://testflight.apple.com/join/awDT2K6Q">iOS TestFlight</a></strong>
  · <strong><a href="https://apps.microsoft.com/detail/9PHHSJMWK06G">Windows Microsoft Store</a></strong>
  <br>
  <a href="https://github.com/zhangheng2022/meet_trace/releases/tag/v1.0.0-alpha.10">v1.0.0-alpha.10 发布说明</a>
  · <a href="docs/README.md">项目文档</a>
</div>

会迹是一款面向个人会议记录的开源 Flutter 应用。事实音频保存在本机；会中预览、最终转录和说话人标签均可降级或重建，推理与网络异常不得中断录音。

> [!WARNING]
> 项目仍处于 Alpha 阶段，不适合不可恢复的重要录音。Windows 虽已进入 Microsoft Store，仍缺 AT-21～AT-26 的完整客户端生命周期闭环，因此标记为“规划中/未就绪”。

## 下载与边界

| 平台 | 入口 | 要求与状态 |
| --- | --- | --- |
| Android | [APK](https://github.com/zhangheng2022/meet_trace/releases/download/v1.0.0-alpha.10/meettrace-v1.0.0-alpha.10-android-arm64.apk) | Android 7.0+，仅 `arm64-v8a` |
| iOS | [TestFlight](https://testflight.apple.com/join/awDT2K6Q) | iOS 15.0+ |
| Windows | [Microsoft Store](https://apps.microsoft.com/detail/9PHHSJMWK06G) | Windows 10 22H2/11 x64；规划中/未就绪 |

首次启动约下载 286.3 MB 运行资源，并要求应用所在卷至少有 1 GiB 可用空间。Alpha 仅支持当前公开版本；升级或卸载可能清除本机会议、录音、模型和设置。

- 不提供登录、跨设备同步、云端 ASR、AI 总结或会中切换模型。
- 文本分享只使用最终转录；音频分享需独立入口和二次确认，临时 WAV 不改写事实 PCM。
- Android/iOS/Windows Release 默认启用可在设置中关闭的 Sentry 远程诊断。完整披露见[隐私政策](PRIVACY.md)。
- 当前 Windows 由 Microsoft Store 签名和分发；[Code signing policy](CODE_SIGNING_POLICY.md) 仅用于未接入的 SignPath 申请路线。

产品范围和验收只以 [Alpha PRD](docs/product/Alpha_PRD_无登录版.md) 为准。

## 开发

环境：Flutter stable、Dart 3.12+；Android 使用 JDK 17，iOS 需要 macOS、Xcode 和 CocoaPods。

```bash
git clone https://github.com/zhangheng2022/meet_trace.git
cd meet_trace
flutter pub get
flutter run -d '<device-id>'
```

提交前至少运行：

```bash
dart format lib test
flutter analyze
flutter test
```

项目采用 `View → ViewModel → Use Case / Port → Repository / Service`；Domain 为纯 Dart，UI 不直连存储、网络、录音插件或 ONNX。ASR 仅通过官方 `sherpa_onnx` 包接入，模型权重不进入 APK、IPA 或 MSIX。

## 文档

- [更新日志](CHANGELOG.md)
- [文档入口](docs/README.md)
- [Alpha PRD](docs/product/Alpha_PRD_无登录版.md)
- [设计系统](DESIGN.md)
- [技术方案](docs/technical/端侧_SenseVoice_转录技术方案.md)
- [质量与验收](docs/quality/README.md)
- [发布 Runbook](docs/project/GitHub_版本发布流程.md)
- [仓库协作指南](AGENTS.md)

## 许可证

代码采用 [MIT License](LICENSE)。第三方依赖与模型遵循各自许可证，固定来源与许可文本见 [assets/licenses](assets/licenses/)。
