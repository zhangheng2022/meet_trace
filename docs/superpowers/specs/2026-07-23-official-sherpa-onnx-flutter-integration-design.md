# 官方 sherpa-onnx Flutter 包集成设计

> 状态：待书面复核
> 日期：2026-07-23
> 决策：方案 A

## 1. 目标

Meetily 通过官方 `sherpa_onnx` Flutter/Dart 包接入 Paraformer 标准模型和 Qwen3-ASR 高级模型。项目不自建或维护 sherpa-onnx 原生桥接。

## 2. 强制约束

项目不得：

- 自行编写 sherpa-onnx JNI 桥接。
- 自行编写或生成 sherpa-onnx C API 的 Dart FFI 绑定。
- 为 sherpa-onnx 维护 `ffigen` 配置和生成文件。
- 在仓库中维护 sherpa-onnx C/C++ 源码、CMake 构建链或自编译 `.so`。
- 手工把 sherpa-onnx 原生库放入项目 `jniLibs`。
- 因官方 Flutter API 缺少能力而绕过本决策增加私有原生接口。

官方 Flutter 包内部仍会使用原生运行库；“不自建原生桥接”是指该边界由官方包提供和维护，Meetily 不复制这部分职责。

## 3. 依赖与版本

- `pubspec.yaml` 直接依赖官方 `sherpa_onnx` Flutter 包。
- 版本必须固定到 Day 1 真机 Spike 验证通过的版本，不使用无上限的浮动依赖。
- 原生 Android 运行库由官方 Flutter 包及其平台包提供。
- 构建产物仍需检查目标 ABI、原生库重复项、APK 体积和许可证。
- 模型文件继续由 Meetily 的 ModelManager 管理，不交给依赖包决定产品生命周期。

## 4. 应用层边界

```text
View / ViewModel
  → Use Case
    → Repository
      → AsrCoordinator
        → AsrEngine
          ├─ ParaformerStandardAsrEngine
          └─ QwenAdvancedAsrEngine
                ↓
          官方 sherpa_onnx Dart API
                ↓
          官方包维护的原生运行时
```

Meetily 自己实现的两个 Engine 只是 Dart 业务适配器，负责：

- 将 `AsrModelDescriptor` 转换为官方包的识别器配置。
- 从 ModelManager 获取已校验模型路径。
- 管理识别器初始化、调用、释放和应用级取消。
- 将官方返回值转换为统一 `TranscriptEvent` 和 `TranscriptSnapshot`。
- 记录模型 ID、版本、阶段、RTF 和结构化错误。
- 隔离 UI、领域层和第三方包。

Engine 不得包含 `DynamicLibrary.open`、C 指针管理、JNI 调用或自定义 ABI 声明。

## 5. Day 1 Go/No-Go

在继续正式 ASR 实现前，必须用官方 Flutter 包在目标 Android 真机验证：

1. Paraformer 标准模型可以初始化并处理 5 分钟样本。
2. Qwen3-ASR 0.6B INT8 高级模型可以初始化并处理同一份样本。
3. 官方 API 能满足模型配置、音频输入、结果读取和资源释放。
4. 应用可把推理放到不阻塞 UI 和录音写入的执行链。
5. Debug APK 包含正确目标 ABI，且没有重复原生库。
6. 记录官方包版本、平台包版本、设备、ABI、RTF、内存和异常。

## 6. 官方包能力不足时

处理顺序固定为：

1. 检查官方较新稳定版本是否支持。
2. 检查官方示例和公开 API 是否已有等价能力。
3. 在兼容范围内调整模型配置或目标模型版本。
4. 若仍不满足，停止该模型的正式实现并更新 PRD/技术方案。

不得把“自建 FFI/JNI 桥接”作为回退方案。标准模型失败时仍保留可靠录音和仅录音模式；高级模型失败不得影响标准模型。

## 7. 测试

- 用 fake adapter 测试两个 Engine 的业务转换，不在普通单元测试加载原生库。
- 用真机集成测试验证官方包初始化、识别、释放和重复创建。
- 对官方包升级执行两个模型的完整回归和 APK 内容检查。
- 故障注入证明第三方包异常不会终止录音。
- 版本验证结果进入双模型评测记录。

## 8. 文档影响

书面复核后同步：

- `AGENTS.md`：删除 ffigen、自建原生桥接和自管 FFI 约束。
- `docs/研会_AI_Alpha_PRD_无登录版.md`：Day 1 门槛改为官方 Flutter 包验证。
- `docs/端侧双模型转录技术方案.md`：原生桥接章节改为官方包集成边界。
- `docs/Codex_Alpha_开发步骤.md`：删除 ffigen/JNI/C++/jniLibs 任务，Step 08 改为官方包集成。
- `docs/README.md`：技术方案说明删除“FFI”措辞。

该决策不改变双模型、会议模型锁定、录音优先、最终转录和隐私边界。
