# Meetily 文档索引

> 状态：当前文档入口
> 更新日期：2026-07-23

## 活动文档

按优先级阅读：

1. [研会 AI Android Alpha PRD V0.5](./研会_AI_Alpha_PRD_无登录版.md)
   产品范围、用户流程、功能需求、质量门槛和 AT-01～AT-16 的唯一事实源。
2. [端侧双模型转录技术方案](./端侧双模型转录技术方案.md)
   将 PRD 约束落实为录音、模型管理、官方 sherpa-onnx Flutter 包、双 ASR Engine、存储和降级架构。
3. [Codex Alpha 开发步骤](./Codex_Alpha_开发步骤.md)
   当前仓库从应用壳到双模型 Alpha 的执行顺序、测试要求和完成看板。
4. [双模型设计规格](./superpowers/specs/2026-07-23-dual-asr-model-design.md)
   2026-07-23 已批准决策的审计记录；若与当前 PRD 冲突，以 PRD 为准并同步修订规格。
5. [官方 sherpa-onnx Flutter 包集成规格](./superpowers/specs/2026-07-23-official-sherpa-onnx-flutter-integration-design.md)
   2026-07-23 已批准的依赖边界：只使用官方 Flutter/Dart 包，不自建原生桥接。

实施证据：

- [Android Alpha 设备矩阵](./quality/Android_Alpha_设备矩阵.md)：最低 SDK、目标 ABI、开发设备和待补齐的验收设备。

## 文档关系

```text
PRD（做什么、为什么、如何验收）
  → 技术方案（怎样设计）
    → Codex 开发步骤（按什么顺序实现）
      → 代码、测试、真机报告（实现证据）
```

`AGENTS.md` 是仓库级执行约束，必须与以上活动文档一致。

## 当前实现状态

截至 2026-07-23，仓库只有 Flutter/Forui 应用壳和一个壳层测试。录音、数据库、模型管理、双 ASR Engine、页面和总结均未实现。开发从 Codex 步骤的 Step 00 开始，Step 01 双模型真机 Spike 是继续 ASR 主链的 Go/No-Go。

## 维护规则

- 改变 P0、验收标准或产品边界：先更新 PRD。
- 改变模型、接口、数据链或降级策略：同步更新技术方案。
- 改变开发顺序、文件落点或质量门槛：同步更新 Codex 开发步骤。
- 每次文档变更检查相对链接、模型 ID、日期和术语。
- 活动文档不保留“旧版”“备选版”并列副本；历史内容从 Git 查看。
- DOCX/PDF 如需交付，必须从当前 Markdown 基线生成，不作为独立事实源。
- 下载模型、真实录音、评测语料、密钥、`build/` 和 `coverage/` 不得提交。

## 已清理的旧基线

以下内容不再作为仓库活动文档：

- 云端实时 ASR 方案：Alpha 不使用云端 ASR。
- Qwen3-ASR 单模型方案：由标准 Paraformer + 高级 Qwen3-ASR 双模型方案替代。
- 旧版 PRD DOCX：内容与 Markdown 基线分叉，已移除。

需要追溯时使用 Git 历史，不要重新引用旧文件路径。
