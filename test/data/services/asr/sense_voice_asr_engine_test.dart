import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/sense_voice_asr_engine.dart';
import 'package:meettrace/data/services/asr/sherpa_onnx/sherpa_onnx_adapter.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  test('使用已校验安装创建固定 auto 与 ITN 的 SenseVoice Engine', () async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    final workers = _WorkerFactory();
    final engine = SenseVoiceAsrEngine(
      installation: _installed(),
      workerFactory: workers,
    );

    await engine.initialize();

    expect(engine.descriptor, same(descriptor));
    expect(workers.configs.single.kind, SherpaOnnxRecognizerKind.senseVoice);
    expect(workers.configs.single.language, 'auto');
    expect(workers.configs.single.useInverseTextNormalization, isTrue);
    await engine.dispose();
  });

  test('拒绝版本、状态或字节数不匹配的安装记录', () {
    final valid = _installed();
    final invalid = ModelInstallation(
      modelId: valid.modelId,
      version: valid.version,
      installationType: valid.installationType,
      state: ModelInstallationState.failed,
      bytes: 0,
    );

    expect(
      () => SenseVoiceAsrEngine(installation: invalid),
      throwsA(isA<AsrEngineException>()),
    );
  });
}

ModelInstallation _installed() {
  final descriptor = AsrModelRegistry.alpha.defaultModel;
  return ModelInstallation(
    modelId: descriptor.modelId,
    version: descriptor.version,
    installationType: descriptor.installationType,
    state: ModelInstallationState.installed,
    installedPath: '/models/${descriptor.modelId}/${descriptor.version}',
    verifiedAt: DateTime.utc(2026, 8, 1),
    bytes: descriptor.requiredBytes,
  );
}

final class _WorkerFactory implements SherpaOnnxWorkerFactory {
  final List<SherpaOnnxRecognizerConfig> configs = [];

  @override
  Future<SherpaOnnxWorker> create(SherpaOnnxRecognizerConfig config) async {
    configs.add(config);
    return const _Worker();
  }
}

final class _Worker implements SherpaOnnxWorker {
  const _Worker();

  @override
  Future<SherpaOnnxRecognition> recognize(
    Float32List samples, {
    required int sampleRate,
  }) async => SherpaOnnxRecognition(
    text: '测试',
    sampleCount: samples.length,
    elapsed: Duration.zero,
  );

  @override
  Future<void> dispose() async {}
}
