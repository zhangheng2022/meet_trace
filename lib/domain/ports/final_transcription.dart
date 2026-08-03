import '../models/meeting.dart';
import '../models/transcript.dart';
import 'asr_engine.dart';

typedef FinalTranscriptionProgressCallback =
    void Function(AsrFinalizationProgress progress);

final class FinalTranscriptionResult {
  const FinalTranscriptionResult({
    required this.meeting,
    required this.snapshot,
  });

  final Meeting meeting;
  final TranscriptSnapshot snapshot;
}

abstract interface class FinalTranscriptionRunner {
  Future<FinalTranscriptionResult> transcribe({
    required String meetingId,
    String? retrySnapshotId,
    FinalTranscriptionProgressCallback? onProgress,
  });
}
