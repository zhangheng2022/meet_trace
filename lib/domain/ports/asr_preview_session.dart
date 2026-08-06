import '../models/asr_preview.dart';
import '../models/transcript.dart';

/// 会中转录预览的纯 Dart 契约。
///
/// 与具体 VAD/ASR 实现分离，使 UI、测试和 Web 组件预览不需要加载原生推理依赖。
abstract interface class AsrPreviewSession {
  Stream<TranscriptEvent> get events;

  Stream<AsrPreviewMetrics> get metricsChanges;

  AsrPreviewMetrics get metrics;

  /// 在事实录音启动后异步准备会中预览模型。
  Future<void> initialize();

  Future<void> flush();

  /// 丢弃可丢弃的预览积压并在有界时间内停止预览。
  Future<void> stop();

  Future<void> dispose();
}
