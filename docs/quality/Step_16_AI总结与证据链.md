# Step 16：AI 总结与证据链

> 状态：已完成
> 日期：2026-07-25

## 交付范围

- 定义纯 Dart `SummaryGenerationService` 能力端口、最小请求 schema 和结构化返回对象。
- `GenerateSummaryUseCase` 只读取当前活动、已完成的最终转录快照。
- 服务只返回 evidence segment IDs；证据时间区间和原文引用从本地最终快照生成。
- 未知 evidence ID 被丢弃，无有效证据的结论或行动项标记“待核对”。
- SQLite 在同一事务内保存完整摘要并激活会议活动摘要；证据与本地片段不一致时整体回滚。
- 新最终转录成功激活后，旧的已完成摘要标记为 `stale`。
- 总结任务单独记录 processing、completed 或 failed；失败不改变最终转录，可从详情页重试。
- 详情页使用 Forui 展示安全边界、生成中、失败、过期、概览、关键结论、行动项和原文证据。

## 隐私与事实边界

- 请求类型只包含 `schemaVersion`、片段 ID、最终文本和可选说话人标签。
- 请求类型不提供会议 ID、快照 ID、音频路径、音频字节、本地时间戳或会中临时转录字段。
- 云端返回的时间戳和引文不作为事实；展示内容只使用本地最终转录片段。
- 当前 Alpha 没有安全总结网关，也不在客户端保存永久 API 密钥。生产装配使用 `UnavailableSummaryGenerationService`，页面不显示生成按钮。
- 总结失败、超时或网关不可用均不改变会议和最终转录状态。

## 测试先行证据

第一轮 UseCase 测试因缺少总结 service、用例和 Repository 原子激活能力而编译失败；实现后同一组测试通过。Step 16 新增 16 项测试覆盖：

- 最终活动快照资格和最小请求字段。
- 本地证据时间、引文、去重及未知 ID 待核对。
- 安全网关不可用时不调用生成服务、不创建摘要。
- 生成失败保存独立失败状态且最终转录不受影响。
- 摘要原子激活后，辅助任务状态写入失败不会反向污染已生效摘要。
- 摘要保存与会议活动摘要原子激活。
- 转录并发变化时事务回滚。
- 伪造证据时间或引文被数据库拒绝。
- 新最终转录使旧摘要过期。
- ViewModel 加载、生成、失败和重试。
- Forui 安全关闭提示、证据和待核对状态。

## 自动化验证

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

结果：

- 全量 228 项测试通过。
- `flutter analyze --no-pub`：No issues found。
- Debug APK 构建通过，大小 `310,828,706` 字节。
- 构建只剩 `flutter_foreground_task` 上游 Built-in Kotlin 兼容警告。

## Android 端到端证据

设备：Android 16（API 36）x86_64 模拟器 `emulator-5554`。

1. 隔离 worktree 首次构建缺少 Git 忽略的 Flutter `GeneratedPluginRegistrant`，日志明确报类未找到；补齐与上一步一致的生成文件并重建后，插件注册和本地模型准备恢复。该生成文件不进入提交。
2. 使用 `adb install -r` 覆盖安装，保留既有已完成会议和最终转录。
3. 冷启动后会议列表和详情页均使用中文，既有最终转录、说话人标签和事实音频继续可见。
4. AI 总结卡明确显示“只基于当前最终转录生成；不会上传音频或会中临时文本”。
5. 生产能力明确显示“安全总结网关未配置”和“当前构建已关闭云端总结”，页面没有生成按钮。
6. 日志不再出现 `GeneratedPluginRegistrant`、`MissingPluginException` 或 `AndroidRuntime` 崩溃。

## 已知风险与下一步

- 当前交付完成总结领域、编排、存储和 UI 边界，但没有绕过安全要求接入任何云端提供商；配置安全网关属于后续独立部署工作。
- Step 17 负责证据点击定位、音频区间播放、转录编辑、分享、删除和诊断；本步骤只展示证据时间与原文。
- Android 验证覆盖生产安全关闭路径；真实云端响应、弱网、网关鉴权和服务端日志脱敏须在安全网关可用后补测。
