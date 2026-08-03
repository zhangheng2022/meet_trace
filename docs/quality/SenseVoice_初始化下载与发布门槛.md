# 会迹（MeetTrace）SenseVoice 初始化下载与发布门槛

> 更新日期：2026-08-03
>
> 状态：活动；仓库门槛已通过，双平台目标真机证据阻塞

## 固定资产

| 资源 | 大小 |
| --- | ---: |
| SenseVoice `model.int8.onnx` | 239,233,841 B |
| SenseVoice `tokens.txt` | 315,894 B |
| Silero VAD | 212,860 B |
| 合计 | 239,762,595 B |
| 上限 | 300,000,000 B |

SenseVoice 使用不可变 revision `2365baeacb507f821a0c8120fcee3d484dba7a07`；准确 SHA-256 见技术方案和发布 Manifest。空间预检固定为 `805,306,368` 可用字节。

## 仓库门禁

- [x] Registry 只有 SenseVoice。
- [x] SenseVoice 与 VAD 权重不在 `pubspec.yaml` assets 中。
- [x] 固定下载总量低于十进制 300 MB。
- [x] Wi-Fi 自动、移动网络显式同意、同意绑定资源版本集合。
- [x] Range 续传、暂停保留分片、SHA-256 严格校验和原子激活。
- [x] 第二次启动离线快速检查。
- [x] 设置页无删除、等级和占位模型。
- [x] 会议锁定模型/版本/auto/ITN。
- [x] 旧 Alpha schema 阻断且不自动删除。
- [x] `flutter analyze` 最终复验：0 问题。
- [x] `flutter test` 最终复验：2026-08-03 修正 `local_runtime_asset_preparation_service_test.dart:101` 的旧哈希断言（旧前缀 `c45ba1` → 当前固定 Manifest `c71f0c…`）后，328 项全部通过。
- [x] Android Debug APK 构建与权重审计：`app-debug.apk` 构建成功，ASR/VAD 权重和用户数据命中数均为 0。
- [x] OCR workspace 模式复审全部 79 个可审文件；Critical/High 清零。
- [ ] Graphify 完全同步：`graphify update .` 已把代码图更新为 4,676 nodes / 6,274 edges / 396 communities，代码关系已同步；CLI 仍提示 Markdown 语义更新需要 AI 管线，且已有标签数量与当前 communities 不一致，不能把文档语义图视为完全同步。

## 外部门禁

- [ ] Android arm64 真机首次下载与断点续传。
- [ ] Android 30 分钟录音、RTF P95 `<0.5`、结果 P95 `≤3s`、关键事实召回率 `≥85%`、电量/温控/内存。
- [ ] iOS arm64 构建与 App bundle 权重审计。
- [ ] iPhone/iPad 首次下载、后台录音、系统中断、无障碍和同等性能指标。

外部门禁没有证据时发布结论为 `blocked`，不是 `go`，也不等同于实现失败。
