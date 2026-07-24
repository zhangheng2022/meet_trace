import 'dart:typed_data';

const recordingSampleRate = 16000;
const recordingChannelCount = 1;
const recordingBytesPerSample = 2;
const recordingBytesPerSecond =
    recordingSampleRate * recordingChannelCount * recordingBytesPerSample;

Duration recordingDurationForBytes(int bytes) {
  if (bytes < 0 || bytes.isOdd) {
    throw ArgumentError.value(bytes, 'bytes', '必须是非负且对齐 PCM16 样本边界');
  }
  return Duration(
    microseconds:
        bytes * Duration.microsecondsPerSecond ~/ recordingBytesPerSecond,
  );
}

final class RecordingPcmChunk {
  RecordingPcmChunk({required Uint8List bytes, required this.startByteOffset})
    : bytes = Uint8List.fromList(bytes) {
    if (startByteOffset < 0 || startByteOffset.isOdd) {
      throw ArgumentError.value(
        startByteOffset,
        'startByteOffset',
        '必须对齐 PCM16 样本边界',
      );
    }
    if (bytes.isEmpty || bytes.length.isOdd) {
      throw ArgumentError.value(bytes.length, 'bytes', '必须包含完整 PCM16 样本');
    }
  }

  final Uint8List bytes;
  final int startByteOffset;

  int get endByteOffset => startByteOffset + bytes.length;
  Duration get start => recordingDurationForBytes(startByteOffset);
  Duration get end => recordingDurationForBytes(endByteOffset);
}

final class RecordingArtifact {
  const RecordingArtifact({
    required this.meetingId,
    required this.audioPath,
    required this.bytes,
  });

  final String meetingId;
  final String audioPath;
  final int bytes;

  Duration get duration => recordingDurationForBytes(bytes);
}
