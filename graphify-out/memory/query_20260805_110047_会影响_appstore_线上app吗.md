---
type: "query"
date: "2026-08-05T11:00:47.518352+00:00"
question: "会影响 appstore 线上app吗"
contributor: "graphify"
outcome: "useful"
source_nodes: ["spec-process-cicd-ios-testflight.md", "Dependent Workflows"]
---

# Q: 会影响 appstore 线上app吗

## Answer

Expanded from original query via graph vocab: [app, build, distribution, release, store, test, workflow]. 不影响 App Store 当前线上版本。Fastfile 仅调用 upload_to_testflight，并设置 distribute_external=false、notify_external_testers=false；仓库没有 upload_to_app_store、deliver、提交审核或正式发布动作。手工触发后只会在同一 App Store Connect 应用记录中新增一个 TestFlight 构建。只有后续人工选择该构建、提交 App Review 并执行发布，才会更新线上 App。

## Outcome

- Signal: useful

## Source Nodes

- spec-process-cicd-ios-testflight.md
- Dependent Workflows