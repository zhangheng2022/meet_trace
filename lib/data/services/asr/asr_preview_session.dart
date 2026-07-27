import '../../../domain/models/asr_preview.dart';
import '../../../domain/models/transcript.dart';

/// 会中转录预览的纯 Dart 契约。
///
/// 与具体 VAD/ASR 实现分离，使 UI、测试和 Web 组件预览不需要加载原生推理依赖。
abstract interface class AsrPreviewSession {
  Stream<TranscriptEvent> get events;

  Stream<AsrPreviewMetrics> get metricsChanges;

  AsrPreviewMetrics get metrics;

  Future<void> flush();

  Future<void> dispose();
}
