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
- `splash/` 中的 PNG 由 SVG 母版派生，只作为
  `flutter_native_splash.yaml` 的生成输入；Android 与 iOS 平台启动文件统一通过
  `dart run flutter_native_splash:create` 重新生成。
- 原始 Stitch 截图只用于来源核对，不进入 Flutter `assets` 清单。

## 启动图光学尺寸

- 原生启动标志与 Flutter 品牌动效统一以 `88dp/pt` 为交接尺寸；Flutter 动效最终
  收至 `52dp`。
- 普通亮色、暗色启动图使用 `384x384px` 画布，标志 Alpha 边界为
  `352x292px`。
- Android 12 亮色、暗色启动图使用 `1152x1152px` 透明画布，但标志 Alpha
  边界为 `352x292px`，且必须保持在系统安全裁切区内。
- 修改启动源图后必须重新运行
  `dart run flutter_native_splash:create --path=flutter_native_splash.yaml`，并运行
  `test/architecture/branding_assets_test.dart` 校验源图与平台生成结果。
