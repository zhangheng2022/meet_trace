# Step 15：说话人分离降级

> 状态：已完成
> 日期：2026-07-25

## 交付范围

- 定义纯 Dart `SpeakerDiarizationService` 能力端口和可替换实现边界。
- `SpeakerDiarizationCoordinator` 只处理当前活动、已完成的最终转录快照与完整事实音频。
- 按时间区间最大重叠把服务结果映射到既有片段；无重叠片段回退 `speaker-1`。
- 超时、空结果、能力不可用、资源或服务异常统一降级为单一说话人，不改变最终转录 `complete` 状态。
- 自动能力开关保存到 `app_settings`；稳定处理任务保存完成、失败和错误码，重开详情页可恢复状态。
- SQLite 受限更新只修改 `speaker_id`；用户可批量重命名同一说话人的全部片段。
- 详情页使用 Forui 展示能力开关、处理中、完成、降级、重试和人工标签状态。

## 关键边界

- 说话人增强不能读取会中临时转录，也不能处理 processing、failed、temporary 或非活动快照。
- 映射和人工标签都不能改变片段 ID、原文、时间轴、置信度、模型 ID 或模型版本。
- 说话人失败不写入会议失败状态，不阻塞最终转录查看，也不阻塞 Step 16 读取活动最终快照生成总结。
- 当前 PRD、Registry 和发布 Manifest 没有批准独立说话人模型；生产使用 `UnavailableSpeakerDiarizationService` 显式关闭自动能力，同时保留人工标签。
- 后续自动实现必须先补齐模型来源、许可、Manifest、体积和设备门槛，并继续通过 Dart service 端口接入，不得自建 JNI/FFI 原生桥接。

## 测试先行证据

第一轮定向测试因缺少领域模型、service、Repository 方法和编排器而编译失败；实现后同一组测试通过。新增 15 项测试覆盖：

- 成功区间映射和无重叠回退。
- 服务异常、能力不可用与超时降级。
- 关闭能力时不调用服务、不改写标签。
- 未完成、临时或非活动快照资格拒绝。
- 人工重命名同一说话人的全部片段。
- SQLite 开关持久化、标签无损更新和非法输入拒绝。
- ViewModel 最终转录/说话人错误隔离、失败任务重开恢复。
- Forui 能力不可用、降级提示和人工标签交互。

## 自动化验证

```powershell
dart format lib test
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug --no-pub
```

结果：

- 全量 212 项测试通过。
- `flutter analyze --no-pub`：No issues found。
- Debug APK 构建通过，大小 `310,798,558` 字节。
- 构建只剩 `flutter_foreground_task` 上游 Built-in Kotlin 兼容警告。

## Android 端到端证据

设备：Android 16（API 36）x86_64 模拟器 `emulator-5554`。

1. fresh install 后首次 worktree 构建因 Windows 软链接检查中断，缺失 Git 忽略的 Flutter `GeneratedPluginRegistrant`，页面显示本地能力准备失败；补齐与 Step 14 相同的 Flutter 生成文件并重建后，插件注册、冷启动和本地模型准备正常。该生成文件不进入提交。
2. 新建会议，授予麦克风和通知权限，录音持续并显示实时转录正常。
3. 结束会议后由本场锁定的标准 Paraformer 生成已完成最终快照，详情页显示来源模型、带时间戳原文和“说话人 1”。
4. 自动开关明确显示“当前构建未配置已验证的本地说话人模型，可继续手工标注”，没有静默加载未知权重或切换其他模型。
5. 页面提供按说话人聚合的人工标签输入和保存动作，保存后显示“说话人标签已保存”；进程保持存活，日志无 `GeneratedPluginRegistrant`、Flutter 或 AndroidRuntime 崩溃。

## 已知风险与下一步

- Android 设备验证覆盖生产“能力不可用”降级路径；多说话人成功映射、超时和服务异常由可注入 fake 服务覆盖，尚无真实说话人模型准确率证据。
- 若产品决定引入真实说话人模型，属于模型/许可/体积和设备门槛变化，必须先更新 PRD、技术方案和发布 Manifest。
- Step 16 应只读取当前活动且已完成的最终快照；无论说话人任务是完成、失败还是关闭，都不得阻塞总结与证据生成。
