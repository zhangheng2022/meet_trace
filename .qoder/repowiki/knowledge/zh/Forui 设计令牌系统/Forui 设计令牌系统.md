---
kind: external_dependency
name: Forui 设计令牌系统
slug: forui
category: external_dependency
category_hints:
    - framework_behavior
    - sdk_real_api
scope:
    - '**'
---

### Forui 设计令牌系统
- Flutter UI 主题生成工具，将 DESIGN.md 中的 YAML frontmatter 令牌转换为 Dart 代码
- 配置输出路径：主题到 lib/theme/theme.dart，样式到 lib/theme/styles/
- 与 .impeccable/design.json sidecar 配合，提供机器可读的设计规范
- 支持色阶 tonalRamp、组件 HTML/CSS 片段、narrative 镜像等设计资产
- 更新 DESIGN.md 时必须同步重生成 design.json 和主题代码
- verify exact API/params against official docs: forui CLI 文档确认令牌转换流程