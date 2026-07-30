import 'dart:async';
import 'dart:typed_data';

import '../../../domain/models/asr_preview.dart';

abstract interface class VoiceActivitySegmenter {
  int get sampleRate;

  FutureOr<List<VadSpeechSegment>> accept(Float32List samples);

  FutureOr<List<VadSpeechSegment>> flush();

  FutureOr<void> reset({required int nextStartSample});

  FutureOr<void> dispose();
}
