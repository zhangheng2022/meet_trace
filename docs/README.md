# 会迹（MeetTrace）项目文档

> 状态：活动；项目文档唯一导航入口
>
> 更新日期：2026-08-14
>
> 原则：仓库只保留当前仍需维护的文档，阶段记录和旧方案由 Git 历史追溯。

## 阅读顺序

1. 从根目录 [README](../README.md) 了解产品和开发入口。
2. 以 [Alpha PRD](./product/Alpha_PRD_无登录版.md) 判断产品范围与验收标准。
3. UI 变更查 [DESIGN](../DESIGN.md)，录音、模型和数据链路查[技术方案](./technical/端侧_SenseVoice_转录技术方案.md)。
4. 测试与发版先查[质量与验收](./quality/README.md)，再按 [GitHub Alpha 发布流程](./project/GitHub_版本发布流程.md)操作。

## 活动文档

| 文档 | 职责 | 权威级别 |
|---|---|---|
| [Alpha PRD](./product/Alpha_PRD_无登录版.md) | 产品范围、P0、功能要求和验收标准 | 产品唯一事实源 |
| [DESIGN](../DESIGN.md) | 交互、视觉、组件和三平台自适应规则 | 设计权威，服从 PRD |
| [产品上下文](../PRODUCT.md) | 用户、定位和产品原则的精简上下文 | PRD 派生摘要 |
| [端侧转录技术方案](./technical/端侧_SenseVoice_转录技术方案.md) | 固定资源、初始化、录音、ASR、分离、快照和分享契约 | 技术权威，服从 PRD |
| [质量与验收](./quality/README.md) | 自动化门禁、设备矩阵、未闭环风险和证据要求 | 当前质量入口 |
| [GitHub Alpha 发布流程](./project/GitHub_版本发布流程.md) | 三平台签名、候选、TestFlight/MSIX、GitHub Pre-release、自动更新和撤回 Runbook | 发布操作入口；Store 验收与公开未闭环前仍含目标合同 |
| [Sentry 配置](./project/Sentry_配置.md) | 运行时采样、隐私边界和符号上传 | 监控 Runbook |
| [Code signing policy](../CODE_SIGNING_POLICY.md) | 待审核 SignPath 路线的角色、可签名内容、批准与撤回规则 | 未来直发签名政策；当前 Store 发布不使用 |
| [隐私政策](../PRIVACY.md) | 本机数据、网络访问、平台诊断差异和删除方式 | 对外隐私披露 |
| [Flutter CI/CD 工作流规格](../spec/spec-process-cicd-flutter-ci.md) | 常规 CI、平台选择、稳定 Gate 与发布工作流契约 | 工作流维护规格 |
| [AGENTS](../AGENTS.md) | 架构、实现、测试、审查和安全约束 | 仓库协作规则 |

根目录 README 只介绍项目；PRODUCT 只提供产品上下文；两者不得扩展 PRD。工作流的真实行为以 `.github/workflows/` 和相应守卫测试为准，Runbook 只解释维护者操作。

## 冲突处理

1. 产品范围：PRD 优先。
2. UI：PRD → DESIGN → 当前实现。
3. 技术：PRD → 技术方案 → 当前代码与测试。
4. 发布：PRD → 质量与验收 → 当前工作流 → 发布 Runbook。
5. 协作流程：上述事实源 → AGENTS。

## 维护规则

- 文档只写当前结论；旧版本、阶段完成记录、旧测试数量和旧构建体积不在活动文档中累积。
- 一次性审计、开发阶段清单、历史 Step 验收报告和通用工具教程不进入 `docs/`。
- 新文档必须承担现有文档无法覆盖的长期职责；否则更新现有事实源。
- 产品范围变化先改 PRD，再同步 DESIGN、PRODUCT、技术方案、质量文档和 AGENTS。
- 工作流或平台门槛变化时，同步质量文档和发布 Runbook；不要复制整份 YAML 行为规格。
- 质量证据必须带提交 SHA、日期、环境、设备和命令；旧证据不能证明新候选。
- 重命名或删除文档后检查全仓 Markdown 本地链接，并运行 `graphify update .`。

## 非文档事实源

- `.github/workflows/`：CI 和发版行为。
- `lib/`、`test/`、平台目录：实际实现与自动化验证。
- `docs/quality/alpha_release_input.json`：可选的非阻断验收记录模板。
- `.impeccable/design.json`、`forui.yaml`、`lib/theme/`：设计令牌的工程落点。
- Git 历史：所有已删除方案、审计快照和阶段证据的唯一追溯入口。
