# Meetily 文档索引

> 状态：当前文档入口
> 更新日期：2026-07-24

## 活动文档

按优先级阅读：

1. [研会 AI Android Alpha PRD V0.5](./研会_AI_Alpha_PRD_无登录版.md)
   产品范围、用户流程、功能需求、质量门槛和 AT-01～AT-16 的唯一事实源。
2. [端侧双模型转录技术方案](./端侧双模型转录技术方案.md)
   将 PRD 约束落实为录音、模型管理、官方 sherpa-onnx Flutter 包、双 ASR Engine、存储和降级架构。
3. [Codex Alpha 开发步骤](./Codex_Alpha_开发步骤.md)
   当前仓库从应用壳到双模型 Alpha 的执行顺序、测试要求和完成看板。
4. [Git 分支与 Worktree 约定](./Git_分支与_Worktree_约定.md)
   Alpha 步骤分支、隔离 worktree、合并和安全清理规则。
5. [双模型设计规格](./superpowers/specs/2026-07-23-dual-asr-model-design.md)
   2026-07-23 已批准决策的审计记录；若与当前 PRD 冲突，以 PRD 为准并同步修订规格。
6. [官方 sherpa-onnx Flutter 包集成规格](./superpowers/specs/2026-07-23-official-sherpa-onnx-flutter-integration-design.md)
   2026-07-23 已批准的依赖边界：只使用官方 Flutter/Dart 包，不自建原生桥接。

实施证据：

- [Android Alpha 设备矩阵](./quality/Android_Alpha_设备矩阵.md)：最低 SDK、目标 ABI、开发设备和待补齐的验收设备。
- [Step 01 双模型真机 Spike](./quality/Step_01_双模型真机_Spike.md)：官方包、模型文件、APK、录音解耦和真机复测状态。
- [Step 07 可靠录音与崩溃恢复](./quality/Step_07_可靠录音与崩溃恢复.md)：事实 PCM、检查点、原子封存、异常恢复和 Mi 10 后台录音证据。
- [Step 08 官方 sherpa-onnx Flutter 包集成](./quality/Step_08_官方_sherpa-onnx_Flutter_包集成.md)：一次性 bindings、isolate worker、结构化错误、重复创建和 APK 审计证据。

## 文档关系

```text
PRD（做什么、为什么、如何验收）
  → 技术方案（怎样设计）
    → Codex 开发步骤（按什么顺序实现）
      → 代码、测试、真机报告（实现证据）
```

`AGENTS.md` 是仓库级执行约束，必须与以上活动文档一致。

## 当前实现状态

截至 2026-07-24，Step 00、Step 02～08 已完成，Step 01 的外部验收项仍在执行。仓库已固定官方 `sherpa_onnx` 1.13.4，加入双模型 Spike、录音连续性探针、逐窗口诊断和 APK 检查脚本；Mi 10 录音完整率 99.54%，Paraformer 15 秒窗口两轮均为 20/20 可读、RTF 约 0.0214，Qwen3-ASR 峰值 RSS 约 2.92 GiB且首结果约 18～20 秒，因此 Step 01 当前为预备 Conditional Go。Step 02～04 已建立领域契约、事实存储、双模型 Registry、Manifest/文件校验、默认模型设置和显式选择规则；Step 05 已把 `81,904,027` 字节 Paraformer INT8 运行文件纳入 APK。Step 06 已实现 Qwen3-ASR 六文件按需下载、2 GiB 空间预检、网络确认、HTTPS Range 续传、取消/重试、严格校验、SQLite v3 原子活动版本、持久化租约和安全删除；高级权重不进入 APK。Step 07 已通过官方 `record` 和公开前台服务插件实现可靠事实录音。Step 08 已把官方包收敛为应用启动 bindings、独立 isolate worker、串行识别、资源释放、应用级取消和结构化错误边界；Mi 10 使用真实内置 Paraformer 完成两轮初始化、1 秒 PCM 推理、释放和重建。115 个自动化测试、静态分析、Debug APK、APK 内容检查和真机集成测试通过。精确转换权重的镜像许可元数据仍为空，来源 NOTICE 已记录上游 Apache-2.0 与转换来源；公开分发前仍须完成许可确认。具体双 Engine、会议业务流程和总结生成尚未实现。

## 维护规则

- 改变 P0、验收标准或产品边界：先更新 PRD。
- 改变模型、接口、数据链或降级策略：同步更新技术方案。
- 改变开发顺序、文件落点或质量门槛：同步更新 Codex 开发步骤。
- 每次文档变更检查相对链接、模型 ID、日期和术语。
- 活动文档不保留“旧版”“备选版”并列副本；历史内容从 Git 查看。
- DOCX/PDF 如需交付，必须从当前 Markdown 基线生成，不作为独立事实源。
- 除 PRD 指定随 APK 内置并带完整 Manifest/NOTICE 的标准模型外，下载模型、真实录音、评测语料、密钥、`build/` 和 `coverage/` 不得提交。

## 已清理的旧基线

以下内容不再作为仓库活动文档：

- 云端实时 ASR 方案：Alpha 不使用云端 ASR。
- Qwen3-ASR 单模型方案：由标准 Paraformer + 高级 Qwen3-ASR 双模型方案替代。
- 旧版 PRD DOCX：内容与 Markdown 基线分叉，已移除。

需要追溯时使用 Git 历史，不要重新引用旧文件路径。
