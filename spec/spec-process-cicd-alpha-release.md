---
title: CI/CD Workflow Specification - Alpha Release
version: 1.3
date_created: 2026-08-20
last_updated: 2026-08-22
owner: MeetTrace Maintainers
tags: [process, cicd, github-actions, release, android, ios, windows, auto-update]
---

# Alpha Release 端到端工作流规格

## Workflow Overview

**Purpose**：从 `master` 的单一不可变提交生成 Android、iOS、Windows Alpha 候选，在 Store 状态经受保护人工证明或可选 API 验证后公开 GitHub Pre-release 和签名自动更新指针。

**Trigger Events**：仅允许维护者手动启动；发布标识必填，发布说明、TestFlight 外部链接和恢复参数可选。

**Target Environments**：`android-alpha`、`testflight`、`windows-alpha`、`github-release`。

## Execution Flow Diagram

```mermaid
flowchart TD
  A[手动输入发布标识] --> B[解析不可变候选与模式]
  B --> C[技术质量门禁]
  C --> D[Android 签名候选]
  C --> E[iOS TestFlight 候选]
  C --> F[Windows Store 候选]
  D --> G[三平台候选一致性校验]
  E --> G
  F --> G
  G --> H{github-release 人工批准}
  H --> I{Store 核验模式}
  I -->|manual| J[记录受保护人工证明]
  I -->|api| K[查询并验证 Store submission]
  J --> L{公开、同版本、仅 x64?}
  K --> L
  L -->|否| O[失败关闭；保留 Draft 与候选]
  L -->|是| M[公开原 Draft 为 Pre-release]
  M --> N[原子前移签名更新指针]
  N --> P[写入发布与 Store 审计摘要]
```

## Jobs & Dependencies

| Job | Purpose | Dependencies | Execution Context |
|---|---|---|---|
| prepare | 解析 candidate、resume、metadata 模式和共享构建号 | 无 | Linux，只读仓库 |
| quality | 运行统一 Flutter 技术门禁 | prepare | 可复用质量工作流 |
| android | 构建、签名、审计并暂存唯一公开 APK | prepare, quality | `android-alpha` |
| ios | 构建、签名、审计并上传 TestFlight | prepare, quality | `testflight` |
| windows | 构建、审计并保存固定 Store 身份 MSIX 候选 | prepare, quality | `windows-alpha` |
| publish | 复核三平台、证明 Store 生产状态、公开 Release 与更新指针 | prepare, android, ios, windows | `github-release`，需人工批准；API 核验可选 |

## Requirements Matrix

### Functional Requirements

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---|---|
| REL-001 | 单一入口绑定 `master` 不可变提交 | High | 候选 SHA 属于 `master`，tag 与 Draft Release 均绑定该 SHA |
| REL-002 | 三平台使用同一发布标识、营销版本和共享构建号 | High | 三份候选清单逐字段一致 |
| REL-003 | Android 仅公开签名 `arm64-v8a` split APK | High | Release 中恰有一个预期 APK；共享构建号从 `2001` 开始，Android 输入基础构建号 `1` 后由默认 ABI 偏移生成相同的真实 `versionCode=2001`，摘要和签名身份匹配候选证据 |
| REL-004 | iOS 仅上传 TestFlight | High | GitHub Release 与 Artifact 均不公开 IPA |
| REL-005 | Windows 仅通过固定 Microsoft Store 产品分发 | High | Store ID、包身份、Publisher、PFN、版本映射和 x64 架构匹配固定合同 |
| REL-006 | Store 正式版本先于 GitHub 与更新指针公开 | High | `github-release` 审批人逐项确认并提交精确 Store/状态/版本/x64/SHA-256 评论，或 API 回执证明 submission 为 `Published`、`Public` 且包含同一 `1.0.<build>.0` x64 包，否则失败关闭 |
| REL-007 | 公开需要一次 `github-release` 人工批准 | High | `manual` 模式必须从本次运行的审批 API 核验环境、状态、审批人和精确评论；未批准时不公开 Draft、不写更新指针 |
| REL-008 | 更新指针签名且单调前移 | High | 私钥对应客户端公钥；新构建号递增；写入携带上一 blob 身份 |
| REL-009 | 失败恢复不得重建成功候选 | Medium | resume 模式复核原运行和 Artifact 后继续，不重复 TestFlight/Store 上传 |
| REL-010 | 撤回不删除或覆盖资产 | High | 原 Release/tag/APK/Store submission 保留，指针状态只从公开转为撤回 |

### Security Requirements

| ID | Requirement | Implementation Constraint |
|---|---|---|
| SEC-001 | 发布凭据只在受保护 Environment 可见 | PR、常规 CI、候选 Artifact 和日志不得接收凭据 |
| SEC-002 | 无 Entra 时不得伪造 API 凭据 | `manual` 模式不读取 Partner Center Secrets；`api` 模式仅在最终批准 job 中读取最小权限凭据 |
| SEC-003 | Store 回执必须标明证据来源且不得包含凭据 | 人工回执标记 `manualEnvironmentApproval` 并记录审批人、精确合同评论及其摘要，API 回执标记 `partnerCenterApi`；均只保留候选与非敏感状态字段 |
| SEC-004 | 第三方 Actions 不得漂移 | 所有 Action 固定不可变提交；工具版本固定并受守卫测试约束 |
| SEC-005 | 自动更新私钥不得落盘到仓库或 Artifact | 仅通过进程环境传递，日志不得回显 |

## Input/Output Contracts

### Inputs

| Input | Type | Required | Contract |
|---|---|---:|---|
| release_id | string | 是 | `v<semver>-alpha.<positive>`，营销版本与候选一致 |
| release_notes | string | 否 | 公开说明附加内容，不改变候选身份 |
| ios_testflight_external_url | string | 否 | 仅接受 TestFlight 官方 join URL |
| resume_run_id | positive integer | 否 | 仅引用同工作流、同候选且三平台成功的运行 |
| withdraw_update | boolean | 否 | 仅允许现有公开版本从自动发现中撤回 |
| repair_update_pointer | boolean | 否 | 仅允许现有公开版本重签同一指针 |
| store_verification_mode | choice | 否，默认 `manual` | `manual` 使用受保护审批证明；`api` 在审批后调用 Partner Center API |

### Secrets & Variables

| Scope | Name | Purpose |
|---|---|---|
| android-alpha | Android 签名与 Sentry Secrets | 签名、证书身份校验、符号上传 |
| testflight | App Store Connect、iOS 签名与 Sentry Secrets | TestFlight 上传和符号上传 |
| github-release | `APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64` | 签名自动更新 envelope |
| github-release（仅 `api`） | `PARTNER_CENTER_TENANT_ID` | Store API 租户身份 |
| github-release（仅 `api`） | `PARTNER_CENTER_SELLER_ID` | Store Seller 身份 |
| github-release（仅 `api`） | `PARTNER_CENTER_CLIENT_ID` | Store API 客户端身份 |
| github-release（仅 `api`） | `PARTNER_CENTER_CLIENT_SECRET` | Store API 客户端凭据 |

### Outputs

| Output | Retention/Visibility | Contract |
|---|---|---|
| Android APK + public candidate manifest | GitHub Pre-release，长期公开 | 不可覆盖、不可删除、与候选摘要一致 |
| iOS signed evidence | Actions Artifact，受限保留 | 不含 IPA |
| Windows Store candidate evidence | Actions Artifact，受限保留 | MSIX 不进入 GitHub Release |
| Store production receipt | Actions summary/evidence，不含 Secret | 标明人工或 API 核验模式，并绑定同版本 production submission 合同与候选身份 |
| signed `alpha.json` | `updates/alpha` 分支 | 原子写入、签名有效、构建号不回退 |

## Execution Constraints

- 同一时间最多运行一个 Alpha Release；已有运行不得被新运行取消。
- Android 与 Windows 候选 job 最长 90 分钟，iOS 候选 job 最长 120 分钟，最终公开 job 最长 30 分钟。
- 发布候选必须来自 `master` 历史；禁止移动既有 tag。
- 既有共享构建号低于 `2001` 时，下一候选一次性从 `2001` 开始，随后连续递增。Android schema 2 候选的包基础构建号固定为共享构建号减 `2000`，保留 Flutter 默认 ARM64 `+2000` ABI 偏移，使 APK 实际 `versionCode`、iOS 构建号和 Windows Store 第三段一致。签名更新指针必须携带候选清单实测的 Android `versionCode`，客户端不得自行推导。
- 仅当前公开 Alpha 受支持。工作流可安全分发更高构建号，但不得把版本递增、更新 Manifest 或平台商店入口解释为任意旧 Alpha 可系统升级、兼容旧数据或完成迁移；Alpha 不提供降级或迁移合同。破坏性版本必须在应用内安装前提示全部本地数据清除范围并取得确认，录音或最终处理期间不得强制安装、退出或清理。
- Microsoft Store 首次产品提交、Private audience 和 Flight 的人员/组配置属于 Partner Center bootstrap；`manual` 模式由审批人核对正式 submission，并逐字复制 Windows job 生成的 `STORE <Store ID> Published Public <版本> x64 <MSIX SHA-256>` 评论；`api` 模式由工作流复核，不得把人工证据描述为自动化查询。
- `manual` 模式未从本次运行找到匹配的 `github-release` 已批准记录，或 `api` 模式验证失败、超时、凭据缺失时，保持 Draft 和旧更新指针，不得降级放行。

## Error Handling Strategy

| Error Type | Response | Recovery Action |
|---|---|---|
| 技术或平台构建失败 | 阻断候选 | 修复后以同发布标识重试；只复用身份匹配的不可变资产 |
| TestFlight/Store 候选失败 | 阻断统一公开 | 修复平台分发后重试，不公开部分候选 |
| 人工核对发现 Store 状态或包不匹配 | 不批准 `github-release`，保持等待或取消 | 在 Partner Center 完成同一包的正式认证，再使用原候选恢复 |
| Store API/认证失败 | `api` 模式阻断最终公开并输出非敏感诊断 | 修复 Environment/Entra 配置后恢复，或新运行显式选择 `manual` 并重新承担人工核对责任 |
| GitHub Release 公开失败 | 保留 Draft 或已公开状态，禁止盲目覆盖 | resume/metadata 模式重新核对不可变资产 |
| 更新指针写入冲突 | Release 状态保持可审计，旧指针不被覆盖 | 读取最新 blob 后按 repair 模式复核重试 |

## Quality Gates

| Gate | Criteria | Bypass Conditions |
|---|---|---|
| Flutter quality | format、analyze、tests 全部成功 | 无 |
| Platform identity | 三平台候选同 SHA/版本/构建号且身份固定 | 无 |
| Distribution | TestFlight 上传成功；Store production 人工或 API 回执绑定同一 x64 版本 | 无 |
| Human approval | `github-release` reviewer 批准；`manual` 评论逐字匹配候选合同 | 无普通批准、空评论或自动旁路 |
| Public integrity | Release 资产、签名指针、上一指针状态全部有效 | 无 |

## Monitoring & Observability

- Job summary 记录候选 SHA、发布标识、共享构建号、三平台结果、Store 核验模式、可用的 submission ID、状态、版本和更新指针状态。
- Store API 错误仅记录状态码与去敏错误信息；令牌、Client Secret 和 SAS URL 不得输出。
- 构建证据默认按工作流保留期自动过期；公开 Release 和 `updates/alpha` 历史长期保留。

## Edge Cases & Exceptions

| Scenario | Expected Behavior | Validation Method |
|---|---|---|
| Store 仍为 Private audience 或 Flight | 不公开 GitHub，不前移指针 | `manual` 审批人拒绝批准；`api` 检查可见性和状态 |
| Store 已公开但版本不同 | 不公开 | `manual` 逐项核对；`api` 精确比较 `1.0.<shared build>.0` |
| Store submission 同时含非 x64 包 | 不公开 | `manual` 核对包列表；`api` 检查架构集合 |
| TestFlight 外部链接缺失 | 允许公开，但说明标记待提供 | Release notes 检查 |
| 同版本已撤回 | 禁止重新公开 | 签名指针状态迁移检查 |
| 首个 schema 2 统一候选 | 共享构建号为 `2001`；Android 基础构建号为 `1`、实际 `versionCode` 为 `2001`；iOS 与 Windows 同为 `2001`；不声明兼容任何旧 Alpha 安装或数据 | 三平台候选清单、APK badging 和客户端安装前验包测试 |
| API 返回未知状态或关键字段类型错误 | `api` 模式失败关闭 | 严格枚举状态并校验关键 schema；无关新增字段可忽略 |

## Validation Criteria

- VLD-001：规格、workflow、守卫测试对 Job 依赖和单一批准顺序描述一致。
- VLD-002：守卫测试证明 `manual` 为无 Secret 默认路径、查询本次运行审批记录、严格匹配环境与候选合同评论且回执诚实标记证据来源；API 解析覆盖有效、非公开、版本错、架构错、字段缺失和未知状态。
- VLD-003：YAML/Actions 语法有效，第三方 Actions 固定完整提交。
- VLD-004：发布守卫证明 Store 验证发生在 Release 公开和更新指针写入之前。
- VLD-005：完整 Flutter 测试、静态分析和 OCR 审查通过。
- VLD-006：守卫测试证明保留 `--split-per-abi`，共享构建号从 `2001` 连续递增，Android 基础构建号等于共享构建号减 `2000`，APK 实测 `versionCode` 与共享构建号相同并写入候选和签名更新指针；客户端按该实测值验包。

## Change Management

1. 先更新本规格与 PRD 发布合同。
2. 通过 PR 审查工作流、工具和守卫测试。
3. 在 `github-release` 保持 reviewer 保护；仅启用 `api` 模式时配置 Partner Center Secrets。
4. 以非公开候选验证人工拒绝路径；有 Entra 时再验证 API 查询和失败关闭。
5. 全部门禁通过且用户明确授权后合并；正式发版仍从单一 `Alpha Release` 入口启动。

## Version History

| Version | Date | Changes | Author |
|---|---|---|---|
| 1.0 | 2026-08-20 | 定义三平台候选、Store 生产验证、统一公开与签名更新指针的纵向合同 | Codex |
| 1.1 | 2026-08-20 | 增加无 Entra 的受保护人工证明默认路径，并保留可选 Partner Center API 核验 | Codex |
| 1.2 | 2026-08-21 | 保留 Android ABI split，将三平台实际构建号统一到 `2001` 起连续递增，并明确不兼容旧 Android Alpha 安装 | Codex |
| 1.3 | 2026-08-22 | 明确仅支持当前公开 Alpha，更新与统一发布不构成任意 Alpha 间安装或数据兼容承诺 | Codex |

## Related Specifications

- [Flutter CI/CD 工作流规格](./spec-process-cicd-flutter-ci.md)
- [Alpha PRD](../docs/product/Alpha_PRD_无登录版.md)
- [GitHub Alpha 发布流程](../docs/project/GitHub_版本发布流程.md)
- [代码签名策略](../CODE_SIGNING_POLICY.md)
