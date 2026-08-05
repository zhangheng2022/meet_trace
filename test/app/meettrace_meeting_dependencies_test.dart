import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/meettrace_meeting_dependencies.dart';
import 'package:meettrace/data/models/runtime/speaker_diarization_manifest.dart';
import 'package:meettrace/data/services/diarization/speaker_diarization_service.dart';

void main() {
  test('生产组合根工厂创建可用的 Sherpa 说话人分离服务', () {
    final service = createMeetTraceSpeakerDiarizationService(
      segmentationModelPath: '/models/segmentation/model.int8.onnx',
      embeddingModelPath: '/models/embedding/model.onnx',
      inference: const SpeakerDiarizationInferenceConfig(
        sampleRate: 16000,
        numThreads: 2,
        provider: 'cpu',
        numClusters: -1,
        clusteringThreshold: 0.5,
        minDurationOn: 0.3,
        minDurationOff: 0.5,
      ),
    );

    expect(service, isA<SherpaOnnxSpeakerDiarizationService>());
    expect(service.capability.isAvailable, isTrue);
    expect(
      service.config.segmentationModelPath,
      '/models/segmentation/model.int8.onnx',
    );
    expect(service.config.embeddingModelPath, '/models/embedding/model.onnx');
    expect(service.config.numClusters, -1);
    expect(service.config.clusteringThreshold, 0.5);
  });
}
