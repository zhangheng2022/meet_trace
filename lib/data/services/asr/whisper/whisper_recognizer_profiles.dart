import 'whisper_adapter.dart';

final class WhisperRecognizerProfile {
  const WhisperRecognizerProfile({
    required this.id,
    required this.decodingStrategy,
    required this.bestOf,
    required this.beamSize,
    required this.noContext,
    required this.suppressBlank,
    required this.temperature,
    required this.temperatureIncrement,
    this.initialPrompt,
  });

  final String id;
  final WhisperDecodingStrategy decodingStrategy;
  final int bestOf;
  final int beamSize;
  final bool noContext;
  final bool suppressBlank;
  final double temperature;
  final double temperatureIncrement;
  final String? initialPrompt;

  WhisperRecognizerConfig createConfig({
    required String modelId,
    required String modelVersion,
    required String modelPath,
    int threadCount = 2,
    String language = 'auto',
  }) {
    return WhisperRecognizerConfig(
      modelId: modelId,
      modelVersion: modelVersion,
      modelPath: modelPath,
      profileId: id,
      threadCount: threadCount,
      language: language,
      decodingStrategy: decodingStrategy,
      bestOf: bestOf,
      beamSize: beamSize,
      noContext: noContext,
      suppressBlank: suppressBlank,
      temperature: temperature,
      temperatureIncrement: temperatureIncrement,
      initialPrompt: initialPrompt,
    );
  }
}

const whisperBaselineRecognizerProfile = WhisperRecognizerProfile(
  id: 'baseline-fixed-greedy-v1',
  decodingStrategy: WhisperDecodingStrategy.greedy,
  bestOf: 5,
  beamSize: 5,
  noContext: true,
  suppressBlank: true,
  temperature: 0,
  temperatureIncrement: 0.2,
);

const whisperPreviewRecognizerProfile = WhisperRecognizerProfile(
  id: 'preview-greedy-low-latency-v1',
  decodingStrategy: WhisperDecodingStrategy.greedy,
  bestOf: 1,
  beamSize: 1,
  noContext: true,
  suppressBlank: true,
  temperature: 0,
  temperatureIncrement: 0,
);

const whisperFinalRecognizerProfile = WhisperRecognizerProfile(
  id: 'final-beam-quality-v1',
  decodingStrategy: WhisperDecodingStrategy.beamSearch,
  bestOf: 5,
  beamSize: 5,
  noContext: true,
  suppressBlank: true,
  temperature: 0,
  temperatureIncrement: 0.2,
);
