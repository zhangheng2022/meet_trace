import 'dart:typed_data';

import '../../../domain/models/asr_preview.dart';

abstract interface class VoiceActivitySegmenter {
  int get sampleRate;

  Future<List<VadSpeechSegment>> accept(Float32List samples);

  Future<List<VadSpeechSegment>> flush();

  Future<void> reset({required int nextStartSample});

  Future<void> dispose();
}
