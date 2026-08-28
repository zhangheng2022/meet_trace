import '../../../domain/models/audio_source.dart';

const maximumSpeakerDiarizationFloatBytes = 128 * 1024 * 1024;

bool speakerDiarizationPcmFitsMemory(int pcmBytes) =>
    pcmBytes > 0 && pcmBytes <= maximumSpeakerDiarizationFloatBytes ~/ 2;

final class SherpaOnnxSpeakerDiarizationConfig {
  SherpaOnnxSpeakerDiarizationConfig({
    required this.segmentationModelPath,
    required this.embeddingModelPath,
    required this.sampleRate,
    required this.numThreads,
    required this.provider,
    required this.numClusters,
    required this.clusteringThreshold,
    required this.minDurationOn,
    required this.minDurationOff,
  }) {
    _requireText(segmentationModelPath, 'segmentationModelPath');
    _requireText(embeddingModelPath, 'embeddingModelPath');
    _requireText(provider, 'provider');
    if (sampleRate != 16000) {
      throw ArgumentError.value(sampleRate, 'sampleRate', '必须为 16000');
    }
    if (numThreads <= 0) {
      throw ArgumentError.value(numThreads, 'numThreads', '必须大于 0');
    }
    if (numClusters != -1) {
      throw ArgumentError.value(numClusters, 'numClusters', 'Alpha 必须自动估计人数');
    }
    if (!clusteringThreshold.isFinite ||
        clusteringThreshold <= 0 ||
        clusteringThreshold >= 1) {
      throw ArgumentError.value(
        clusteringThreshold,
        'clusteringThreshold',
        '必须位于 0 到 1 之间',
      );
    }
    if (!minDurationOn.isFinite || minDurationOn < 0) {
      throw ArgumentError.value(minDurationOn, 'minDurationOn', '不能为负数');
    }
    if (!minDurationOff.isFinite || minDurationOff < 0) {
      throw ArgumentError.value(minDurationOff, 'minDurationOff', '不能为负数');
    }
  }

  factory SherpaOnnxSpeakerDiarizationConfig.fromMessage(
    Map<Object?, Object?> message,
  ) {
    return SherpaOnnxSpeakerDiarizationConfig(
      segmentationModelPath: message['segmentationModelPath']! as String,
      embeddingModelPath: message['embeddingModelPath']! as String,
      sampleRate: message['sampleRate']! as int,
      numThreads: message['numThreads']! as int,
      provider: message['provider']! as String,
      numClusters: message['numClusters']! as int,
      clusteringThreshold: message['clusteringThreshold']! as double,
      minDurationOn: message['minDurationOn']! as double,
      minDurationOff: message['minDurationOff']! as double,
    );
  }

  final String segmentationModelPath;
  final String embeddingModelPath;
  final int sampleRate;
  final int numThreads;
  final String provider;
  final int numClusters;
  final double clusteringThreshold;
  final double minDurationOn;
  final double minDurationOff;

  Map<String, Object> toMessage() => {
    'segmentationModelPath': segmentationModelPath,
    'embeddingModelPath': embeddingModelPath,
    'sampleRate': sampleRate,
    'numThreads': numThreads,
    'provider': provider,
    'numClusters': numClusters,
    'clusteringThreshold': clusteringThreshold,
    'minDurationOn': minDurationOn,
    'minDurationOff': minDurationOff,
  };
}

final class SpeakerDiarizationWorkerSegment {
  const SpeakerDiarizationWorkerSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.speakerIndex,
  });

  final double startSeconds;
  final double endSeconds;
  final int speakerIndex;
}

abstract interface class SpeakerDiarizationWorker {
  Future<List<SpeakerDiarizationWorkerSegment>> diarize(AudioSource source);

  Future<void> cancel();

  Future<void> dispose();
}

abstract interface class SpeakerDiarizationWorkerFactory {
  Future<SpeakerDiarizationWorker> create(
    SherpaOnnxSpeakerDiarizationConfig config,
  );
}

final class SpeakerDiarizationWorkerException implements Exception {
  const SpeakerDiarizationWorkerException(this.code);

  final String code;

  @override
  String toString() => 'SpeakerDiarizationWorkerException($code)';
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, '不能为空');
  }
}
