# Step 13：会议主链与会中 UI

> 状态：已完成
> 日期：2026-07-24

## 交付范围

- 生产入口装配启动恢复、SQLite Repository、SenseVoice/VAD 初始化下载、精确 Engine Factory、可靠录音和 ASR 预览协调器。
- 会议列表覆盖加载、空白、正常、处理中和失败；使用主题断点在列表与网格间响应式切换。
- 开始会议页保留标题、全局默认、本场模型覆盖、显式回退和录音后模型锁定。
- 会中页覆盖时长、暂停/恢复、结束、实时转录正常、积压、转录暂停和仅录音。
- 录音活动时系统返回键不离开会中页；锁屏和后台由 Android microphone 前台服务继续维持事实录音。
- 结束后原子封存事实 PCM，保存会议 `processing` 状态并进入处理详情；最终转录属于 Step 14。
- `AndroidProcAsrDeviceRiskMonitor` 通过公开 procfs/sysfs 读取总/可用内存、进程 RSS 和可读温度节点，不新增 JNI、FFI 或原生桥接。

## 关键边界

- `View → ViewModel → Use Case / Port → Repository / Service 实现`：页面不访问 SQLite、文件、录音插件或 ONNX。
- 事实音频和预览仍为两条独立执行链；预览进入 `recordingOnly` 不会停止录音。
- 本场锁定的一个 Engine 同时服务会中预览；任何风险或错误都不自动切换模型。
- 设备风险门槛：可用内存或温控达到临界值时阻止推理；不可读维度保持 unknown，录音继续。

## 自动化验证

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

结果：

- 新增 11 项领域、ViewModel、组件和设备风险测试。
- 全量 184 项测试通过。
- `flutter analyze`：No issues found。
- Debug APK 构建通过。
- 构建只剩 `flutter_foreground_task` 上游 Built-in Kotlin 兼容警告；`storage_space` 警告未再出现。

## Android 端到端证据

设备：Android 16（API 36）x86_64 模拟器 `emulator-5554`。

1. Debug APK 安装与冷启动成功，进程持续存活。
2. 首次启动完成 239,549,735 字节 SenseVoice 和 212,860 字节 VAD 的应用私有目录下载与校验。
3. UI 树确认会议空状态、开始会议、SenseVoice 选择和开始录音入口。
4. 授予麦克风和通知权限后，录音时长持续增长，实时状态为“录音持续进行中/实时转录正常”。
5. 暂停后 UI 同时显示“录音已暂停/转录已暂停”，恢复后继续累计。
6. 结束后形成 `696,320` 字节事实 PCM，约 21 秒；详情页显示“事实音频已保存，正在处理”。
7. 返回列表后同一会议显示“处理中”和 `00:21`，AndroidRuntime/Flutter 日志无崩溃。

## 已知风险与下一步

- 模拟器没有可重复会议语音输入，本轮只证明真实采集、状态、封存和导航，不作为转录准确率证据。
- Mi 10 与最低目标实体设备仍需在 Step 18 校准麦克风阈值、后台/锁屏、procfs/sysfs 可读性、功耗和温控。
- 处理详情目前是明确占位状态；Step 14 必须从完整事实 PCM 创建、保存并激活最终转录快照。
