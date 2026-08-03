---
type: "query"
date: "2026-08-03T10:19:01.582048+00:00"
question: "runtime_asset_installers.dart 与 downloadable_model_service.dart 是否存在循环依赖"
contributor: "graphify"
outcome: "corrected"
correction: "旧版 data 无环结论不成立；当前已通过共享类型模块与守卫回归测试修复。"
source_nodes: ["runtime_asset_installers.dart", "downloadable_model_service.dart", "model_download_types.dart"]
---

# Q: runtime_asset_installers.dart 与 downloadable_model_service.dart 是否存在循环依赖

## Answer

Expanded from graph vocab: [runtime, asset, installer, downloadable, model, service, result, cancellation, token, progress, import, dependency]. 源码复核确认旧结构存在双向 import；守卫因漏掉裸相对 import 而误绿。共享类型已迁移到 model_download_types.dart，补强守卫后循环消失。

## Outcome

- Signal: corrected
- Correction: 旧版 data 无环结论不成立；当前已通过共享类型模块与守卫回归测试修复。

## Source Nodes

- runtime_asset_installers.dart
- downloadable_model_service.dart
- model_download_types.dart