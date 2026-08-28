import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/domain/models/recording.dart';

final class TestRecordingPreviewSink implements RecordingPreviewSink {
  const TestRecordingPreviewSink(this.callback);

  final Future<void> Function(RecordingPcmChunk chunk) callback;

  @override
  Future<void> add(RecordingPcmChunk chunk) => callback(chunk);
}
