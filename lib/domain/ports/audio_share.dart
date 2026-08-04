enum AudioShareOutcome { completed, dismissed, unavailable }

final class AudioShareStorageSnapshot {
  const AudioShareStorageSnapshot({
    required this.pcmBytes,
    required this.wavBytes,
    required this.freeBytes,
  });

  final int pcmBytes;
  final int wavBytes;
  final int freeBytes;

  int get shortageBytes => wavBytes > freeBytes ? wavBytes - freeBytes : 0;
  bool get hasEnoughSpace => shortageBytes == 0;
}

final class AudioShareException implements Exception {
  const AudioShareException(this.code, {this.shortageBytes});

  final String code;
  final int? shortageBytes;
}

abstract interface class AudioShareService {
  Future<AudioShareStorageSnapshot> inspect({required String audioPath});

  Future<AudioShareOutcome> share({
    required String meetingId,
    required String meetingTitle,
    required String audioPath,
    required int expectedPcmBytes,
  });
}
