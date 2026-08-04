import 'dart:async';

/// 事实音频播放能力端口；平台播放器实现位于 data/service 层。

enum AudioPlaybackStatus { idle, playing, completed, failed }

final class AudioPlaybackState {
  const AudioPlaybackState({
    required this.status,
    this.startMs,
    this.endMs,
    this.errorCode,
  });

  final AudioPlaybackStatus status;
  final int? startMs;
  final int? endMs;
  final String? errorCode;
}

final class AudioPlaybackException implements Exception {
  const AudioPlaybackException(this.code);

  final String code;
}

abstract interface class AudioPlaybackService {
  Stream<AudioPlaybackState> get states;

  Future<void> play({
    required String audioPath,
    required int startMs,
    required int endMs,
  });

  Future<void> stop();

  Future<void> dispose();
}
