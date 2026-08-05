---
type: "query"
date: "2026-08-05T05:07:32.269566+00:00"
question: "没有mac , 需要使用github 打包ips ,给我个方案"
contributor: "graphify"
outcome: "useful"
source_nodes: ["ios/RunnerTests/RunnerTests.swift", "reliable_recording_test.dart", "live_preview_replay_test.dart", "MeetTrace Flutter Package Manifest"]
---

# Q: 没有mac , 需要使用github 打包ips ,给我个方案

## Answer

Expanded from original query via vocab: [ios, build, github, actions, release, runner, bundle, audit, integration, test]. 推荐 GitHub Actions 双流水线：公开仓库使用固定 macos-15-intel/Xcode 16.4 和 Flutter 3.44.8。第一条无 Secrets，执行 analyze、test、flutter build ios --release --no-codesign、App 权重审计并上传明确标记为不可安装的 unsigned IPA/App；第二条仅 workflow_dispatch + 受保护 ios-release Environment，导入 Apple Distribution p12 和 App Store provisioning profile，flutter build ipa --release，上传签名 IPA/artifact，并用 App Store Connect API Key 上传 TestFlight。无 Apple Developer Program 只能做编译验证，无法安装普通 iPhone；GitHub runner 也不能替代实体 iPhone/iPad 的录音、锁屏、中断、分享和性能验收。

## Outcome

- Signal: useful

## Source Nodes

- ios/RunnerTests/RunnerTests.swift
- reliable_recording_test.dart
- live_preview_replay_test.dart
- MeetTrace Flutter Package Manifest