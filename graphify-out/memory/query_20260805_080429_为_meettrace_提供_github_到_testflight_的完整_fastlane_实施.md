---
type: "query"
date: "2026-08-05T08:04:29.218430+00:00"
question: "为 MeetTrace 提供 GitHub 到 TestFlight 的完整 Fastlane 实施说明、步骤和三方依赖"
contributor: "graphify"
outcome: "useful"
---

# Q: 为 MeetTrace 提供 GitHub 到 TestFlight 的完整 Fastlane 实施说明、步骤和三方依赖

## Answer

推荐保留 ios-unsigned.yml 作为 PR 门禁，新增仅受保护 master 人工触发的 ios-testflight.yml；准备 Apple Distribution p12、App Store Connect profile、API Key 和 GitHub testflight Environment；新增 Gemfile/Gemfile.lock、Fastfile/Appfile、ExportOptions.plist；Fastlane 先取 TestFlight 最新 build number +1，Flutter 签名 build ipa，审计脚本增加 testflight 模式验证 embedded.mobileprovision、codesign、Team ID 和 entitlements，再由 pilot/iTMSTransporter 上传并分配内部组；签名 IPA不上传公共 Artifact，失败始终清理临时 keychain/profile/key。主要新增三方为 subosito/flutter-action@v2 和 fastlane 2.237.0/Bundler，不引入 match 或签名导入 Action。

## Outcome

- Signal: useful