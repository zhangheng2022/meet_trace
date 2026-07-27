import 'dart:async';

enum EvidencePlaybackStatus { idle, playing, completed, failed }

final class EvidencePlaybackState {
  const EvidencePlaybackState({
    required this.status,
    this.startMs,
    this.endMs,
    this.errorCode,
  });

  final EvidencePlaybackStatus status;
  final int? startMs;
  final int? endMs;
  final String? errorCode;
}

final class EvidencePlaybackException implements Exception {
  const EvidencePlaybackException(this.code);

  final String code;
}

abstract interface class EvidencePlaybackService {
  Stream<EvidencePlaybackState> get states;

  Future<void> play({
    required String audioPath,
    required int startMs,
    required int endMs,
  });

  Future<void> stop();

  Future<void> dispose();
}
