# Rust ASR 迁移阶段 1 审查

## 结论

阶段 1 判定为 **No-Go**，不得进入阶段 2，也不得把本阶段 Spike 代码合并到 `dev`。

`whisper-rs = 0.16.0` 依赖的 `whisper-rs-sys = 0.15.0` 无法在当前受支持的
Windows Android 构建环境中通过高层 API 完成交叉编译。继续需要 fork 或补丁三方
crate 的 `build.rs`，命中实施方案预先约定的硬停止条件。

## 审查范围

- Rust 1.88.0、`flutter_rust_bridge = 2.12.0` 与 Cargokit 最小桥接；
- Android/iOS 插件声明与移动端 FFI 健康探针；
- `whisper-rs = 0.16.0` 高层 API 的模型加载和两秒 Float32 PCM 推理探针；
- Windows → Android 交叉构建、错误传播和真机启动；
- 取消、释放和 100 次生命周期压力测试的可实现性。

FRB 自动生成的 Dart/Rust glue 仅通过可重复 codegen、编译和契约测试核对，不手工修改。
`graphify-out/` 是并行生成噪声，不属于本阶段变更。

## 已验证结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| Rust 工具链 | 通过 | `rustc/cargo 1.88.0`，已安装 3 个 Android Rust target |
| FRB codegen | 通过 | `flutter_rust_bridge_codegen 2.12.0` 可重复生成 |
| Rust 健康函数 | 通过 | `cargo fmt/clippy/test` 在未链接 whisper-rs 时通过 |
| Dart 生成接口契约 | 通过 | mock `RustLibApi` 的 Flutter 单测通过 |
| FRB Android 空桥接构建 | 通过 | APK 含 arm64-v8a、armeabi-v7a、x86_64 Rust `.so` |
| FRB Android 真机运行 | 阻塞 | 小米 Mi 10 返回 `INSTALL_FAILED_USER_RESTRICTED` |
| whisper-rs Windows 宿主构建 | 阻塞 | 缺少可无交互安装的 libclang；预生成 bindings 是 Linux 布局，Windows 尺寸断言失败 |
| whisper-rs Android 构建 | 失败 | Android Clang 报 `no such file or directory: '/utf-8'` |
| whisper-rs iOS 构建/真机 | 未执行 | 当前无 macOS/Xcode/iOS 真机 |
| 16 KB ELF 检查 | 未执行 | whisper-rs Android `.so` 未能生成 |
| 100 次加载/推理/取消/释放 | 未执行 | 移动端库未能构建，且取消 API 存在下述生命周期风险 |

## 阻断缺陷

### Critical：`whisper-rs-sys` 使用宿主条件配置目标 C++ 构建

`whisper-rs-sys 0.15.0/build.rs` 使用 `cfg!(target_os = "windows")` 判断运行
build script 的宿主，随后无条件向目标 C++ 编译加入 `/utf-8` 并声明链接
`advapi32`。Windows 宿主交叉编译 Android 时，日志同时出现：

```text
cargo:rustc-link-lib=advapi32
CMAKE_CXX_FLAGS= /utf-8 ... --target=armv7-linux-androideabi24
clang++: error: no such file or directory: '/utf-8'
```

这不是应用配置可以正确消除的目标差异；修复需要修改或 fork 三方 crate 的
`build.rs`。按阶段 1 硬门槛必须停止迁移。

### Critical（已修复于 Spike 胶水）：Windows Cargokit 吞掉构建失败

FRB 2.12.0 vendored `run_build_tool.cmd` 未把 Dart build tool 的非零退出码返回
Gradle。首次 whisper-rs 构建失败后，Gradle 仍报告 APK 构建成功，可能打包上一次
缓存的 Rust `.so`。Spike 已补充退出码保存与 `exit /B`，复测后 Gradle 正确失败。
若未来重新评估 FRB/Cargokit，必须保留此回归测试，不能仅凭 APK 文件存在判成功。

### High：安全取消回调存在所有权风险

`whisper-rs 0.16.0` 及其当前 master 的 `set_abort_callback_safe` 将双层 Box
转换为裸指针后，却把 `abort_callback_safe` 设为 `None`，未发现对应回收路径。
会中频繁窗口推理若用该高层 API 取消，存在逐次泄漏风险；绕过它需要 raw API 或
修补上游，同样不符合本阶段边界。

### High：官方未声明 Android/iOS 支持

`whisper-rs 0.16.0` README 明确只预期 Windows、macOS、Linux，其他平台由贡献者
自行修复。当前 Android 失败与这一支持边界一致，不能把“Rust 理论上跨平台”当成
双平台交付证据。

### High：双平台和真机证据缺失

Android 真机安装被设备策略阻止；iOS 构建机和真机缺失。即使 Android 编译问题
消失，也不能在缺少模型加载、推理、取消、100 次释放和 16 KB ELF 证据时越过门槛。

## 其他工程发现

- FRB 2.12.0 实际 `integrate` CLI 不支持文档中的
  `--integration-backend/--platforms` 参数，自动生成 Cargokit 多平台模板后需要收窄到
  Android/iOS。
- FRB 2.12.0 vendored Cargokit 使用已被 Gradle 9 删除的 `Project.exec()`；Spike
  依据 Gradle 官方 API 改为注入 `ExecOperations` 后，空桥接才可构建。
- Cargokit 默认执行 `rustup run stable`，并不严格遵守仓库固定的 1.88.0；要做到
  完全可复现还需继续修改 vendored Cargokit。
- `clang -c` 阶段的 `-Wl,-z,max-page-size=16384` warning 仍来自旧 C++ 构建链，
  与本次 Rust 构建失败无关，也不能替代 ELF LOAD alignment 检查。

## 决策与后续

1. 停止 Rust/FRB/whisper-rs 正式替换，不执行阶段 2–8，不合并 Spike 到 `dev`。
2. 继续使用当前官方 `whisper.cpp` Native Assets 实现；Rust 包装不会改变同一模型的
   识别质量，优先修复音频输入、VAD 分段、解码参数、语言设置和模型选型。
3. 若未来重新评估，必须先选择已正式支持 Android/iOS、目标条件正确、取消无泄漏的
   whisper-rs/whisper-rs-sys 版本，并重新更新 PRD 与阶段 1 门槛；不得维护私有 fork
   作为 Alpha 的隐性基础设施。

## OCR 委托审查结果

- 模式：workspace；
- OCR preview：65 个变更文件，其中 20 个可审查；FRB 自动生成 glue、
  `graphify-out/` 和未修改的 vendored Cargokit 按明确规则排除；
- OCR 默认按路径或扩展名排除的自定义 Rust 测试、`.cmd` 与 `.podspec` 已由审查代理
  额外手工纳入；
- 修复：生成 API 新增 probe 后，Dart mock 补齐对应方法；
- 修复：移动端限定代码的常量和校验函数增加目标条件，宿主
  `cargo clippy --all-targets -- -D warnings` 恢复通过；
- 修复：Cargokit Windows runner 正确向 Gradle 传播非零退出码，消除陈旧 `.so`
  被误报为成功 APK 的风险；
- 未解决 Critical/High：上游 Android 交叉编译失败、取消回调所有权风险、iOS 与真机
  证据缺失。这些问题依据硬门槛阻断迁移，不以私有补丁修复。

审查后验证：

```text
cargo fmt --check                         PASS
cargo clippy --all-targets -- -D warnings PASS
cargo test                                PASS（3）
flutter analyze                           PASS
flutter test                              PASS（328）
flutter build apk --debug                 FAIL（预期硬门槛：
  whisper-rs-sys 为 Android Clang 注入 /utf-8）
```
