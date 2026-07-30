import 'dart:typed_data';

import '../../../domain/models/asr_preview.dart';

abstract interface class VoiceActivitySegmenter {
  int get sampleRate;

  List<VadSpeechSegment> accept(Float32List samples);

  List<VadSpeechSegment> flush();

  void reset({required int nextStartSample});

  void dispose();
}
