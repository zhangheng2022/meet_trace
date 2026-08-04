# 会迹品牌资源

## 母版

- `stitch/meettrace-app-icon.svg`：黑底白标应用图标。
- `stitch/meettrace-mark-black.svg`：透明背景黑色标志。

SVG 是唯一几何母版。`android/app/src/main/res/` 与
`ios/Runner/Assets.xcassets/` 中的 PNG、VectorDrawable 和启动资源均为平台生成结果，
不得单独修改造型。

## 使用边界

- Android Adaptive Icon 由黑色背景、白色前景和单色主题图标组成；前景按
  108dp 画布的光学安全区布局，必须在系统圆形、圆角矩形与方圆形遮罩下复核，
  不得直接按可见遮罩边缘放大。
- iOS AppIcon 使用不含 Alpha 通道的黑底 PNG，由系统负责圆角遮罩。
- 应用内品牌动效由 Flutter 路径绘制，最终帧必须与 SVG 标志一致。
- 原始 Stitch 截图只用于来源核对，不进入 Flutter `assets` 清单。
