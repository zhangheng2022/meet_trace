# 会迹品牌资源

`stitch/meettrace-app-icon.svg` 和 `stitch/meettrace-mark-black.svg` 是唯一几何母版。Android/iOS 的 PNG、VectorDrawable 和启动资源均为生成物，不得单独改造型。

- Android Adaptive Icon 使用黑底、白色前景和单色主题图标，并检查系统常用遮罩。
- iOS AppIcon 使用无 Alpha 的黑底 PNG，由系统裁切圆角。
- `splash/` 只作为 `flutter_native_splash.yaml` 的输入；应用内品牌动效最终帧必须匹配 SVG。
- 原生启动标志与 Flutter 动效以 `88dp/pt` 交接，Flutter 最终收至 `52dp`。普通图使用 384×384 画布，Android 12 使用 1152×1152 透明画布；标志 Alpha 边界均为 352×292。

修改母版或启动图后运行：

```text
dart run flutter_native_splash:create --path=flutter_native_splash.yaml
flutter test test/architecture/branding_assets_test.dart
```
