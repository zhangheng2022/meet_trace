# 会迹（MeetTrace）项目文档

> 文档只保留当前结论；决策历史由 Git 追溯，用户可见的版本变化见[更新日志](../CHANGELOG.md)。

## 从哪里开始

1. [README](../README.md)：产品与开发入口。
2. [Alpha PRD](product/Alpha_PRD_无登录版.md)：产品范围和验收的唯一事实源。
3. [DESIGN](../DESIGN.md)：UI；[技术方案](technical/端侧_SenseVoice_转录技术方案.md)：录音、模型和数据链路。
4. [质量与验收](quality/README.md)：门禁；[发布 Runbook](project/GitHub_版本发布流程.md)：维护者操作。

## 活动文档

| 文档 | 唯一职责 |
| --- | --- |
| [更新日志](../CHANGELOG.md) | 用户可见的版本变化与发布说明主源 |
| [Alpha PRD](product/Alpha_PRD_无登录版.md) | 产品范围、功能要求和验收 |
| [DESIGN](../DESIGN.md) | 交互、视觉与自适应规则 |
| [产品上下文](../PRODUCT.md) | 设计和文案所需的 PRD 摘要 |
| [技术方案](technical/端侧_SenseVoice_转录技术方案.md) | 端侧实现契约 |
| [质量与验收](quality/README.md) | 当前门禁和未闭环风险 |
| [发布 Runbook](project/GitHub_版本发布流程.md) | 发布、恢复和撤回操作 |
| [Sentry 配置](project/Sentry_配置.md) | 监控参数、隐私边界和符号上传 |
| [Code signing policy](../CODE_SIGNING_POLICY.md) | 未接入的 SignPath 申请政策 |
| [隐私政策](../PRIVACY.md) | 对外数据与网络披露 |
| [CI 规格](../spec/spec-process-cicd-flutter-ci.md) | 常规 CI 合同 |
| [Alpha Release 规格](../spec/spec-process-cicd-alpha-release.md) | 自动发布状态机与合同 |
| [AGENTS](../AGENTS.md) | 仓库协作约束 |

## 权威顺序

- 产品：PRD。
- UI：PRD → DESIGN → 实现。
- 技术：PRD → 技术方案 → 代码与测试。
- 发布：PRD → 发布规格 → 工作流与工具 → Runbook。
- 协作：上述事实源 → AGENTS。

工作流、代码、测试、Manifest 和主题令牌是各自行为的最终工程事实；文档不复制其可直接读取的完整内容。新文档只有在现有文档无法承担长期职责时才创建。重命名或删除文档后检查本地链接；修改代码后再运行 `graphify update .`。
