---
title: CI/CD Workflow Specification - Android Alpha Candidate
version: 2.0
date_created: 2026-08-06
last_updated: 2026-08-06
owner: MeetTrace maintainers
tags: [process, cicd, github-actions, android, signing, alpha]
---

## Workflow Overview

**Purpose**: 为统一 `Alpha Release` 编排器构建、签名并审计仅含 `arm64-v8a` 的 Android APK，将候选暂存到当前公开源码仓库的 GitHub Draft Release。
**Trigger Events**: 仅接受 `workflow_call`；不显示独立的 Run workflow 按钮。
**Target Environments**: Ubuntu、`android-alpha` Environment、GitHub Draft Pre-release。

## Inputs and Outputs

| Input | Required | Contract |
|---|---|---|
| `release_id` | 是 | `v<marketing-version>-alpha.<sequence>` |
| `candidate_sha` | 是 | 编排器锁定的 40 位提交 SHA |
| `release_notes` | 否 | Draft 阶段说明 |

输出签名 APK、APK SHA-256、签名证书 SHA-256、审计报告和 Android 候选清单。APK 只进入 Draft Release，不进入 Actions Artifact。

## Requirements

- 候选 SHA 必须可达 `master`，发布标识必须匹配 `pubspec.yaml` marketing version。
- 自动技术检查由上游编排器统一执行；本工作流只解析依赖并完成构建、签名、APK 审计与来源证明。
- 使用 `android-alpha` Environment 中的正式签名 Secrets；签名材料只存在于临时 Runner，结束时清理。
- 标签必须是指向候选 SHA 的 annotated tag。首次运行创建标签；Draft 重试只允许复用完全相同的标签身份。
- 相同发布标识在 Draft 阶段可重试，并使用 `--clobber` 替换候选资产。Release 已公开、不是 prerelease 或标签身份不同均立即失败。
- 工作流不得读取 `docs/quality/alpha_release_input.json`，不得运行产品门禁评估器。

## Quality Gates

| Gate | Criteria |
|---|---|
| Identity | release ID、marketing version、candidate SHA 一致 |
| Signing | APK v2/v3 签名有效且证书摘要匹配 |
| Package | 仅 `arm64-v8a`，无模型权重、私钥或禁入资产 |
| Distribution | 当前仓库保持 Draft + prerelease，候选资产可追溯 |

## Failure and Recovery

- 构建或上传失败：修复配置后用同一发布标识重跑；仅 Draft 资产可替换。
- Draft 被提前公开：拒绝重新构建或覆盖。
- 标签缺失时可创建；标签非 annotated、指向不同 SHA 或版本不匹配时拒绝处理。
- 公开后的修复必须使用新发布标识和新候选提交向前发布。

## Version History

| Version | Date | Changes | Author |
|---|---|---|---|
| 2.0 | 2026-08-06 | 改为统一入口内部工作流，移除产品门禁，允许同身份 Draft 重试 | Codex |

## Related Specifications

- [统一 Alpha 发布](spec-process-cicd-alpha-release.md)
- [最终公开发布](spec-process-cicd-release-finalize.md)
