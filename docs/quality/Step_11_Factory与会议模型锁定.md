# Step 11 Factory 与会议模型锁定

> 状态：代码、自动化测试和 Debug APK 构建通过
>
> 日期：2026-07-24
>
> 分支：`codex/alpha-step-11-model-lock`

## 结论

Step 11 已完成 Engine Factory、全局默认模型、本场覆盖、显式回退和会议模型锁定的代码闭环。UI 与 ViewModel 不导入 `ParaformerStandardAsrEngine` 或 `QwenAdvancedAsrEngine`；具体 Engine 只由 data/service 层 Factory 按已经确认的模型 ID 和精确版本创建。

本步骤交付的是可注入的设置、开始会议和录音态组件，以及会议创建/模型锁定协调。主导航、`ReliableRecordingService` 的真实启动和会中状态装配属于 Step 13，不能把本报告解释为完整会议录音主链已经可运行。

## 关键设计

- `SherpaOnnxAsrEngineFactory` 先校验模型已注册且版本与 Registry 完全一致，再创建标准或高级 Engine。
- Factory 不读取全局默认值、不选择本场覆盖、不自动回退；高级模型不可用时直接返回高级模型错误。
- 设置 ViewModel 使用同一条安装状态流完成初始化与持续监听，避免下载完成瞬间丢失状态更新。
- 只有 `installed` 模型可以写入全局默认；开始会议页的覆盖值只存在于本场，不修改默认设置。
- 高级模型不可用时先阻止开始，用户必须选择下载、明确改用标准模型或取消。显式回退同时保存请求模型、实际模型和中文原因。
- 用户确认后，Factory 按解析出的精确 ID/版本创建并初始化 Engine，会议随后进入 `recording`，领域模型与 ViewModel 同时拒绝再次切换。
- 录音态组件只显示锁定模型和版本，不包含单选框或切换按钮。
- 设置和会议组件均使用 Forui 与 `context.theme` 令牌。

## 测试先行证据

生产实现前，专项测试因 Factory、ViewModel 和 View 不存在而失败。完成实现后新增 20 项测试：

1. Factory 精确创建标准 Engine。
2. Factory 精确创建活动高级 Engine并正确处理租约。
3. Registry 版本不匹配时在读取安装记录前拒绝。
4. 高级模型不可用时不自动创建标准 Engine。
5. 设置 ViewModel 加载默认值和双模型状态。
6. 未安装模型不能成为默认值，安装后可以保存。
7. 下载、取消、重试和删除动作统一转发。
8. 设置页覆盖高级模型未下载、下载中、校验中、已安装、失败和空间不足六类状态。
9. 未下载状态可触发高级模型下载。
10. 开始会议继承默认，本场覆盖不修改默认值。
11. 高级模型不可用时先阻止开始，显式回退后记录原因。
12. 开始后 ViewModel 和 `Meeting` 都拒绝更改模型。
13. 开始会议页模型选择默认折叠。
14. 高级模型不可用时显示下载、改用标准和取消。
15. 录音态只显示锁定模型且没有切换入口。

其中状态矩阵使用参数化组件测试，因此总测试用例数为 20。

## 已运行验证

```text
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

- Step 11 定向测试：20/20 通过。
- 全量自动化测试：154/154 通过。
- 静态分析：0 issue。
- Debug APK：构建通过。
- 构建仍提示 `flutter_foreground_task` 与 `storage_space` 使用旧式 Kotlin Gradle Plugin；这是 Step 07 已记录的既有警告。

### 2026-07-24 后续维护

- `storage_space` 已替换为 `disk_space_2` 1.0.13，磁盘容量读取统一收口到 `DeviceFreeSpaceService`。
- Android 根工程中针对旧插件的全局 `compileSdk` 覆盖已移除；当前构建只保留 `flutter_foreground_task` 的上游 Kotlin 插件兼容警告。

## 后续边界

- Step 12 将实现 VAD、积压恢复和有界预览队列。
- Step 13 将把会议列表、开始会议、真实录音服务和会中状态接入可运行主导航。
- 高级模型设备风险目前通过注入的 `AsrDeviceRiskMonitor` 进入 Factory；Android 平台监视器和会中风险呈现仍须在后续装配。
- Mi 10 正式 Qwen Engine 复测仍沿用 Step 10 的设备安装阻塞状态，不属于本步骤的完成条件。
