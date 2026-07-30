# 会迹（MeetTrace）iOS Alpha 设备矩阵

> 状态：阻塞，等待 macOS/Xcode 与真机证据
> 更新日期：2026-07-30
> 上游需求：[Android + iOS Alpha PRD V0.8](../会迹_MeetTrace_Alpha_PRD_无登录版.md)

## 平台基线

| 项目 | 当前基线 |
|---|---|
| Flutter | stable 3.44.8 |
| iOS 最低版本 | 13.0 |
| 必验架构 | arm64 真机 |
| Bundle ID / 签名 | 当前仍为 `com.example.meettrace` 占位符，Apple Team 未配置；签名发布前必须替换 |
| 录音实现 | `record` 7.1.1 / AVFoundation |
| 端侧 ASR | 当前为官方 `whisper.cpp` v1.9.1 + Native Assets；目标 Rust/`whisper-rs` 仍待双平台 Hard Gate |
| 后台能力 | `UIBackgroundModes: audio`；不承诺用户强制结束后继续录音 |

## 必验设备

| 设备层级 | 目标 | 状态 | 必验内容 |
|---|---|---|---|
| 最低 iPhone | 待指定真实型号与系统版本 | 阻塞 | 30 分钟后台录音、标准模型、内存/温控、系统中断 |
| 当前 iPhone | 待指定真实型号与系统版本 | 阻塞 | 双模型、锁屏、切后台、分享、删除、VoiceOver |
| iPad | 待指定真实型号与系统版本 | 阻塞 | 横竖屏、Split View、Dynamic Type、主从布局 |

## 发布门槛

- `flutter build ios --debug --no-codesign` 在 macOS/Xcode 环境通过。
- 使用产品负责人确认的反向域名 Bundle ID 和 Apple Team 完成签名配置。
- Whisper Base 标准模型进入 iOS 构建产物，高级 Small 权重不进入安装包。
- 两个 ASR Engine 在 iOS arm64 真机完成初始化、识别、释放和重复创建。
- 30 分钟前台、锁屏和切后台录音完整率均为 100%。
- 系统音频中断可恢复；用户强制结束后不显示“仍在录音”，重启可恢复已落盘事实音频。
- Dynamic Type 2.0、VoiceOver、浅/深色、边缘返回和 iPad 多任务窗口通过。
- 权限用途、官方原生库、NOTICE/隐私清单、密钥和用户数据完成构建产物审计。

在以上证据闭环前，双平台 Alpha 发布门禁必须保持 `blocked`。
