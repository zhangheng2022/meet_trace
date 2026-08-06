---
title: CI/CD Workflow Specification - iOS TestFlight Candidate
version: 2.0
date_created: 2026-08-05
last_updated: 2026-08-06
owner: MeetTrace maintainers
tags: [process, cicd, github-actions, ios, signing, testflight]
---

## Workflow Overview

**Purpose**: 为统一 `Alpha Release` 编排器构建 App Store 分发签名 IPA、验证签名并上传 TestFlight。
**Trigger Events**: 仅接受 `workflow_call`；Android Draft 候选成功后自动调用。
**Target Environments**: 最新稳定 macOS/Xcode、Flutter stable、`testflight` Environment、App Store Connect。

## Inputs and Outputs

| Input | Required | Contract |
|---|---|---|
| `release_id` | 是 | 与 Android Draft 标签一致 |
| `candidate_sha` | 是 | 与 Android 候选完全相同 |
| `release_notes` | 否 | TestFlight 构建说明 |

IPA 仅直接上传 TestFlight；Actions Artifact 只保存非敏感清单、摘要、审计和工具链信息，不保存 IPA。

## Requirements

- 校验 annotated tag、候选 SHA、`master` 可达性和 marketing version。
- 自动技术检查由上游编排器统一执行；本工作流保留 unsigned bundle 审计、签名材料校验、IPA 审计和来源证明。
- 每次运行/重试生成唯一构建号，避免 App Store Connect 拒绝重复构建号。
- Job 绑定 `testflight` Environment 以读取签名 Secrets，但该 Environment 不配置人工审批；唯一公开批准位于 `github-release`。
- 工作流不得写 GitHub Release、不得上传 IPA 到 GitHub、不得读取产品门禁 JSON。
- TestFlight 上传成功仅表示提交给 Apple；外部测试链接可在首次公开时提供，也可在获批后单独补充。

## Failure and Recovery

- 签名、profile、IPA 或上传失败：同一 Draft 候选可重跑，使用新构建号。
- App Store Connect 后台处理失败：保留 Draft，修复后重跑；不得公开错误身份的候选。
- 标签、SHA 或版本不一致：在读取签名材料前失败。

## Version History

| Version | Date | Changes | Author |
|---|---|---|---|
| 2.0 | 2026-08-06 | 改为统一入口内部工作流，移除重复质量检查、产品门禁和 Draft 指针写入 | Codex |

## Related Specifications

- [统一 Alpha 发布](spec-process-cicd-alpha-release.md)
- [Android Alpha 候选](spec-process-cicd-android-alpha.md)
