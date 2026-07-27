import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/asr/spike/asr_spike_models.dart';
import 'package:meettrace/data/services/asr/spike/sherpa_onnx_spike_runner.dart';
import 'package:meettrace/data/services/audio/spike/recording_continuity_probe.dart';

const _modelRoot = String.fromEnvironment('MEETTRACE_SPIKE_MODEL_ROOT');
const _sampleWave = String.fromEnvironment('MEETTRACE_SPIKE_SAMPLE_WAV');
const _outputRoot = String.fromEnvironment('MEETTRACE_SPIKE_OUTPUT_ROOT');
const _recordingSeconds = int.fromEnvironment(
  'MEETTRACE_SPIKE_RECORDING_SECONDS',
  defaultValue: 30,
);
const _modelFilter = String.fromEnvironment(
  'MEETTRACE_SPIKE_MODEL_FILTER',
  defaultValue: 'all',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final hasInputs =
      _modelRoot.isNotEmpty && _sampleWave.isNotEmpty && _outputRoot.isNotEmpty;

  testWidgets(
    'ASR 在独立 Isolate 运行时录音持续写入',
    (_) async {
      // 主机脚本会在 Flutter 完成测试 APK 的二次安装后再次授权。
      await Future<void>.delayed(const Duration(seconds: 3));
      final runner = SherpaOnnxSpikeRunner();
      final spec = AsrSpikeModelSpec.paraformer(
        rootPath: '$_modelRoot/$paraformerSpikeModelId',
      );
      final probe = RecordingContinuityProbe();

      final metrics = await probe.run(
        outputPcmPath: '$_outputRoot/recording-continuity.pcm',
        duration: const Duration(seconds: _recordingSeconds),
        concurrentWork: () async {
          await runner.run(spec: spec, wavePath: _sampleWave);
          await Future<void>.delayed(const Duration(seconds: 10));
        },
      );

      expect(metrics.bytesWritten, greaterThan(0));
      expect(metrics.isComplete, isTrue);
      final report = <String, Object>{
        'schemaVersion': 1,
        'asrModelId': spec.modelId,
        'metrics': metrics.toJson(),
      };
      await File('$_outputRoot/recording-continuity.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
      debugPrintSynchronously(
        'MEETTRACE_RECORDING_REPORT:${jsonEncode(report)}',
        wrapWidth: null,
      );
    },
    skip: !hasInputs || _modelFilter == 'qwen',
    timeout: const Timeout(Duration(minutes: 20)),
  );

  testWidgets(
    '筛选的模型均可转录同一音频并重复创建释放',
    (_) async {
      final runner = SherpaOnnxSpikeRunner();
      final specs = [
        if (_modelFilter == 'all' || _modelFilter == 'paraformer')
          AsrSpikeModelSpec.paraformer(
            rootPath: '$_modelRoot/$paraformerSpikeModelId',
          ),
        if (_modelFilter == 'all' || _modelFilter == 'qwen')
          AsrSpikeModelSpec.qwen(rootPath: '$_modelRoot/$qwenSpikeModelId'),
      ];
      expect(specs, isNotEmpty);
      final report = <String, Object>{
        'schemaVersion': 1,
        'sampleContentStored': false,
        'modelFilter': _modelFilter,
        'runs': <Map<String, Object>>[],
      };
      final runs = report['runs']! as List<Map<String, Object>>;

      for (final spec in specs) {
        final results = await runner.run(spec: spec, wavePath: _sampleWave);
        expect(results, hasLength(2));
        for (final result in results) {
          final run = result.toJson();
          runs.add(run);
          // 只输出指标，不输出转录正文，供主机在测试失败时回收证据。
          debugPrintSynchronously(
            'MEETTRACE_ASR_RUN:${jsonEncode(run)}',
            wrapWidth: null,
          );
        }
      }

      final output = File('$_outputRoot/asr-results.json');
      await output.parent.create(recursive: true);
      await output.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
      debugPrintSynchronously(
        'MEETTRACE_ASR_REPORT:${jsonEncode(report)}',
        wrapWidth: null,
      );
      expect(runs.every((run) => run['resultWasReadable'] == true), isTrue);
      expect(runs.every((run) => run['emptyWindowCount'] == 0), isTrue);
    },
    skip: !hasInputs,
    timeout: const Timeout(Duration(minutes: 45)),
  );
}
