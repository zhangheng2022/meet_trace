import 'dart:typed_data';

import '../../../domain/models/asr_model.dart';
import '../../../domain/models/audio_source.dart';
import '../../../domain/models/transcript.dart';

abstract interface class AsrEngine {
  AsrModelDescriptor get descriptor;

  Future<void> initialize();

  Stream<TranscriptEvent> get events;

  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  });

  Future<TranscriptSnapshot> finalizeMeeting(AudioSource source);

  Future<void> dispose();
}

abstract interface class AsrEngineFactory {
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
  });
}
