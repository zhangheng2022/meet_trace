---
type: "query"
date: "2026-08-05T10:45:17.513158+00:00"
question: "为当前项目增加 GitHub iOS TestFlight 签名发布流水线需要复用哪些现有门槛"
contributor: "graphify"
outcome: "useful"
source_nodes: ["spec-process-cicd-ios-unsigned.md", "Audit Requirements", "Quality Gates"]
---

# Q: 为当前项目增加 GitHub iOS TestFlight 签名发布流水线需要复用哪些现有门槛

## Answer

Expanded from original query via graph vocab: [ios, flutter, build, distribution, github, inspect, runner, store, test, unsigned, workflow, audit]. 复用 spec-process-cicd-ios-unsigned.md 中的静态检查、自动化测试、unsigned Release bundle 审计与可追溯证据门槛；签名后改用独立的 codesign、embedded profile、Bundle ID、Team ID、构建号、IPA 结构与 SHA-256 校验，再用团队 App Store Connect API Key 通过 Fastlane 上传。

## Outcome

- Signal: useful

## Source Nodes

- spec-process-cicd-ios-unsigned.md
- Audit Requirements
- Quality Gates