# 会迹（MeetTrace）Alpha 开发步骤

> 状态：活动；当前交付基线  
> 当前基线：SenseVoice 单模型、首次初始化下载
> 更新日期：2026-08-01

## 1. 本轮完成范围

- Registry 只保留唯一 SenseVoice descriptor，并固定 `auto + ITN`。
- 删除安装包内的 ASR/VAD 权重声明和非活动 Engine/Spike 接入。
- 固定 SenseVoice、Silero VAD HTTPS Manifest、大小、SHA-256、许可和十进制 300 MB 总量门禁。
- 实现 768 MiB 空间预检、移动网络版本绑定同意、HTTP Range、暂停保留分片、严格校验和原子激活。
- 实现第二次启动的完全离线快速检查和首次初始化阻断 UI。
- 接入官方 SenseVoice 配置，会议持久化并锁定 ID、版本、语言和 ITN。
- 设置页仅显示真实 SenseVoice，保留选择器及修复/暂停能力，不提供删除或占位模型。
- 数据库升级到 schema v5；旧 Alpha schema 只读阻断，不删除录音。
- 补充 domain/data/UI 自动化测试和安装包资源测试。

## 2. 交付顺序

1. 文档和 Manifest 固定产品参数。
2. Registry、Meeting、Port 和 Use Case 建立领域边界。
3. 下载、VAD、同意存储与初始化协调器实现。
4. SenseVoice Engine、Factory 和启动依赖装配。
5. 初始化页、设置页和错误/暂停状态接入。
6. SQLite schema 与旧安装阻断。
7. 格式化、静态检查、全量测试、Android 构建和 APK 审计。
8. OCR 审查全部源码 diff，修复 Critical/High 后复验。
9. 更新 Graphify 知识图谱。

## 3. 自动化命令

```powershell
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
```

构建后解包/列出 APK 内容，确认不存在 `.onnx`、SenseVoice 权重、Silero VAD 权重或其他模型资源。官方插件原生运行库不属于模型权重。

## 4. 发布状态

代码与 Windows 可执行的自动化、Android Debug 构建和包审计完成后，只代表仓库实现门槛。以下必须在外部目标环境留证：

- Android arm64 目标真机：首次下载、移动网络、暂停续传、30 分钟后台录音与性能指标。
- macOS/Xcode：`flutter build ios --debug --no-codesign` 和 IPA/App bundle 权重审计。
- iPhone/iPad：首次下载、后台音频、系统中断、Dynamic Type、VoiceOver、RTF/延迟/召回、电量与温控。

任一目标平台证据缺失时，双平台 Alpha 发布状态保持 `blocked`，不得把本地单元测试标记为真机通过。
