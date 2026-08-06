# 会迹（MeetTrace）Step 14：最终转录快照与完整音频重处理

> 状态：历史实现证据（已完成）
> 日期：2026-07-25

> 本文记录当时的实现与验证快照，不定义当前产品范围或发布状态；当前要求以 [PRD V0.7](../product/Alpha_PRD_无登录版.md) 和[质量证据索引](./README.md)为准。

## 交付范围

- 录音封存后创建带稳定 ID、会议 ID 和来源模型版本的 `processing` 快照。
- 默认按本场锁定的精确模型 ID/版本创建 Engine，只读取会议完整事实 PCM，不读取会中临时转录。
- Engine 使用编排层提供的 snapshot ID 生成片段；编排层校验会议归属、快照类型/状态、模型归属、音频边界和片段重叠。
- SQLite 事务保存完整快照，以预期旧 active ID 做 CAS，原子切换 `activeTranscriptSnapshotId`、完成会议并清除旧摘要。
- 失败尝试保存为 `failed`，保留事实音频、旧活动快照和旧摘要；同一失败 snapshot ID 可幂等重试。
- 完成页只列出当前已安装且已校验的模型，重新转录生成独立快照，成功后才替换活动结果。
- 启动恢复会补激活已完成但未激活的最终快照，同时恢复会议 `completed` 状态并清除过期摘要。

## 关键边界

- `FinalTranscriptionService` 没有预览文本输入，最终事实文本无法由会中片段拼接产生。
- `TranscriptSnapshot` 构造器拒绝跨快照、跨模型和重复片段；编排层额外拒绝越界与重叠。
- Factory 只按明确的 SenseVoice ID、版本、语言和 ITN 创建一个 Engine，不自动回退或混用输出。
- processing/failed 快照不会成为总结输入；只有 `final + complete + active` 快照满足后续总结前置条件。
- 重转录期间旧活动快照和摘要仍可保留；只有新快照事务激活成功时摘要引用才失效。

## 自动化验证

```powershell
flutter pub get
dart format lib test
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

结果：

- 新增 13 项领域、Repository、最终转录编排、ViewModel 和 Forui 组件测试。
- 全量 197 项测试通过。
- `flutter analyze --no-pub`：No issues found。
- Debug APK 构建通过，大小 `310,772,502` 字节。
- 构建只剩 `flutter_foreground_task` 上游 Built-in Kotlin 兼容警告；`storage_space` 警告未再出现。

## Android 端到端证据

设备：Android 16（API 36）x86_64 模拟器 `emulator-5554`。

1. `flutter pub get` 完成插件注册表生成后，Debug APK 安装、冷启动和本地模型准备成功。
2. 新建会议并授予麦克风/通知权限，UI 显示录音持续和实时转录正常。
3. 结束会议后形成 `563,200` 字节事实 PCM，按 16 kHz 单声道 PCM16 折算约 17.6 秒。
4. 详情页自动使用本场锁定的 SenseVoice 处理完整事实音频，显示来源模型和两个带时间戳最终片段。
5. 页面显示“重新转录会生成独立快照；成功后才替换当前结果”，当前只列出已安装的 SenseVoice；同模型重转录可触发并返回完成态。
6. 事实音频和 SQLite 数据库继续保存在应用私有目录，进程持续存活，无 AndroidRuntime 崩溃。

## 已知风险与下一步

- 模拟器麦克风输入不构成准确率评测语料；仍需按当前 PRD 在目标实体设备上记录 SenseVoice RTF、延迟、内存、能耗、温控和关键事实召回。
- 其他模型待定，因此 Alpha 不承诺或测试跨模型重转录。
- 当前仅完成最终转录快照；说话人分离属于 Step 15，AI 总结与证据链属于 Step 16。

## 2026-08-05 性能边界更新

- 当前实现仍以完整事实 PCM 为唯一输入，但最终 ASR 先流式运行 Silero VAD，只把语音区间送入独立的 SenseVoice Engine。
- 窗口固定为前后 200 ms 上下文、最长 15 秒、500 ms 重叠；同一语音段的重叠窗口文本确定性合并为一个最终片段。
- 全静音输入不初始化 SenseVoice，生成空的 `complete` 快照；VAD 任意失败会在首个 ASR 调用前复位文件并回退完整 PCM 固定窗口。
- 自动化覆盖静音跳过、延迟初始化、长语音窗口和 VAD 回退；目标真机仍须重新记录 RTF、内存、能耗、温控与关键事实召回率，且召回不得低于变更前基线。
