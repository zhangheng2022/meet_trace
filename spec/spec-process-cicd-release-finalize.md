---
title: CI/CD Workflow Specification - Finalize Alpha Release
version: 2.0
date_created: 2026-08-06
last_updated: 2026-08-06
owner: MeetTrace maintainers
tags: [process, cicd, github-actions, release, approval]
---

## Workflow Overview

**Purpose**: 在双平台候选完成后执行唯一一次人工批准，验证同 SHA 证据并将 Android Draft 公开为 GitHub Pre-release；也支持公开后只补 TestFlight 链接或说明。
**Trigger Events**: 仅接受统一编排器的 `workflow_call`。
**Target Environment**: `github-release`，配置一名维护者为 required reviewer，并允许发起者自审。

## Modes

| Mode | Preconditions | Mutation |
|---|---|---|
| `candidate` | 当前 run 的 Android/iOS job 成功；Release 是 Draft prerelease | 校验 APK 与双平台清单，上传最终清单，公开原 Draft |
| `metadata` | 同一标签已是公开 prerelease | 校验既有 APK/清单后，只更新发布说明和 TestFlight 链接 |

## Requirements

- 标签必须是指向 `candidate_sha` 的 annotated tag，版本必须与 `pubspec.yaml` 一致。
- `candidate` 模式只从当前编排运行下载 Android/iOS 非敏感 Artifact；两份清单的 release ID、SHA、version、run ID 和 workflow 来源必须一致。
- Draft APK 的名称、大小和 SHA-256 必须与 Android 清单一致；公开动作不得重建 APK。
- `metadata` 模式不得上传、覆盖或删除任何 Release 资产，只能修改正文。
- TestFlight URL 若存在必须匹配 `https://testflight.apple.com/join/<code>`；缺失时公开说明显示“待提供”。
- 不读取或验证产品门禁报告。人工批准人负责确认双平台实际验收结果。

## Failure and Recovery

- 审批前可在 Draft 阶段重跑整个编排器；候选资产按相同标签/SHA 替换。
- 身份、清单或 APK 摘要不一致时拒绝公开。
- 已公开版本只允许 metadata 模式；代码或二进制修复必须使用新发布标识。
- 严重问题版本保留标签和资产，以“已撤回，不建议安装”标记后向前修复。

## Version History

| Version | Date | Changes | Author |
|---|---|---|---|
| 2.0 | 2026-08-06 | 合并到统一编排器的一次批准，移除发布门禁和人工 run ID，增加 metadata-only 补链接 | Codex |

## Related Specifications

- [统一 Alpha 发布](spec-process-cicd-alpha-release.md)
- [Android Alpha 候选](spec-process-cicd-android-alpha.md)
- [iOS TestFlight 候选](spec-process-cicd-ios-testflight.md)
