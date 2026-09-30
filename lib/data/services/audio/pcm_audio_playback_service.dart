import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

import '../../../domain/ports/audio_playback.dart';
import '../storage/app_file_layout.dart';
import 'pcm_wav_file_writer.dart';

abstract interface class DeviceAudioOutput {
  /// The completed file path identifies the exact playback, including delayed
  /// native events from a source that has already been replaced.
  Stream<String> get onCompleted;

  Future<void> playDeviceFile(String path);

  Future<void> stop();

  Future<void> dispose();
}

final class AudioplayersDeviceAudioOutput implements DeviceAudioOutput {
  AudioplayersDeviceAudioOutput({
    AudioPlayer? player,
    AudioPlayer Function()? playerFactory,
  }) : _initialPlayer = player,
       _playerFactory = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _playerFactory;
  final _completed = StreamController<String>.broadcast();
  AudioPlayer? _initialPlayer;
  AudioPlayer? _player;
  StreamSubscription<void>? _completionSubscription;
  bool _disposed = false;

  @override
  Stream<String> get onCompleted => _completed.stream;

  @override
  Future<void> playDeviceFile(String path) async {
    if (_disposed) throw StateError('Audio output is disposed');
    await stop();
    // A fresh native player gives completion events a stable source identity.
    // The optional injected player is retained for the first playback.
    final player = _initialPlayer ?? _playerFactory();
    _initialPlayer = null;
    _player = player;
    _completionSubscription = player.onPlayerComplete.listen((_) {
      if (_player == player && !_completed.isClosed) _completed.add(path);
    });
    await player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } finally {
      await _releasePlayer();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _releasePlayer();
      final initialPlayer = _initialPlayer;
      _initialPlayer = null;
      await initialPlayer?.dispose();
    } finally {
      await _completed.close();
    }
  }

  Future<void> _releasePlayer() async {
    final player = _player;
    final subscription = _completionSubscription;
    _player = null;
    _completionSubscription = null;
    try {
      await subscription?.cancel();
    } finally {
      await player?.dispose();
    }
  }
}

final class PcmAudioPlaybackService implements AudioPlaybackService {
  PcmAudioPlaybackService({
    required this.output,
    required AppFileLayout layout,
    required String meetingId,
    this.wavWriter = const PcmWavFileWriter(),
  }) : temporaryDirectory = layout.meetingPlaybackTempDirectory(meetingId) {
    _completionSubscription = output.onCompleted.listen((path) {
      final preview = _previewDirectory;
      if (_disposeRequested || preview == null || path != _previewPath) return;
      unawaited(
        _enqueue(() async {
          // A queued completion must never stop or remove a newer preview.
          if (_previewDirectory != preview) return;
          await output.stop();
          await _removePreview();
          _states.add(
            AudioPlaybackState(
              status: AudioPlaybackStatus.completed,
              startMs: _startMs,
              endMs: _endMs,
            ),
          );
        }).catchError((Object error) {
          if (!_disposeRequested && !_states.isClosed) {
            _reportFailure();
          }
        }),
      );
    });
  }

  final DeviceAudioOutput output;
  final String temporaryDirectory;
  final PcmWavFileWriter wavWriter;
  final StreamController<AudioPlaybackState> _states =
      StreamController.broadcast();

  late final StreamSubscription<String> _completionSubscription;
  int? _startMs;
  int? _endMs;
  Directory? _previewDirectory;
  bool _disposed = false;
  bool _disposeRequested = false;
  Future<void> _operationTail = Future.value();

  String get _previewPath =>
      p.join(_previewDirectory!.path, 'meettrace-audio-preview.wav');

  @override
  Stream<AudioPlaybackState> get states => _states.stream;

  @override
  Future<void> play({
    required String audioPath,
    required int startMs,
    required int endMs,
  }) {
    if (_disposeRequested || startMs < 0 || endMs <= startMs) {
      return Future.error(
        const AudioPlaybackException('playback.invalid_range'),
      );
    }
    return _enqueue(
      () => _play(audioPath: audioPath, startMs: startMs, endMs: endMs),
    );
  }

  Future<void> _play({
    required String audioPath,
    required int startMs,
    required int endMs,
  }) async {
    final source = File(audioPath);
    if (!await source.exists()) {
      throw const AudioPlaybackException('playback.audio_missing');
    }
    final startByte = startMs * pcmBytesPerMillisecond;
    final endByte = endMs * pcmBytesPerMillisecond;
    final sourceLength = await source.length();
    if (endByte > sourceLength) {
      throw const AudioPlaybackException('playback.range_out_of_bounds');
    }

    try {
      await output.stop();
      await _removePreview();
      final cache = await Directory(temporaryDirectory).create(recursive: true);
      _previewDirectory = await cache.createTemp('preview-');
      await wavWriter.write(
        sourcePath: source.path,
        targetPath: _previewPath,
        startByte: startByte,
        endByte: endByte,
      );
      _startMs = startMs;
      _endMs = endMs;
      await output.playDeviceFile(_previewPath);
      _states.add(
        AudioPlaybackState(
          status: AudioPlaybackStatus.playing,
          startMs: startMs,
          endMs: endMs,
        ),
      );
    } on AudioPlaybackException {
      await _cleanupFailedPlayback();
      rethrow;
    } on PcmWavWriteException catch (error) {
      await _cleanupFailedPlayback();
      _reportFailure();
      throw AudioPlaybackException(error.code);
    } on Object {
      await _cleanupFailedPlayback();
      _reportFailure();
      throw const AudioPlaybackException('playback.failed');
    }
  }

  @override
  Future<void> stop() {
    if (_disposeRequested) {
      return _operationTail;
    }
    return _enqueue(() async {
      await output.stop();
      await _removePreview();
      _states.add(const AudioPlaybackState(status: AudioPlaybackStatus.idle));
    });
  }

  @override
  Future<void> dispose() {
    if (_disposeRequested) {
      return _operationTail;
    }
    _disposeRequested = true;
    return _enqueue(() async {
      if (_disposed) {
        return;
      }
      _disposed = true;
      await _completionSubscription.cancel();
      try {
        try {
          await output.dispose();
        } finally {
          await _removePreview();
        }
      } finally {
        await _states.close();
      }
    });
  }

  Future<void> _removePreview() async {
    final preview = _previewDirectory;
    if (preview == null) return;
    if (await preview.exists()) {
      await preview.delete(recursive: true);
    }
    _previewDirectory = null;
  }

  Future<void> _cleanupFailedPlayback() async {
    try {
      await output.stop();
      await _removePreview();
    } on Object {
      // Keep the path so stop/dispose can retry. Startup recovery also removes
      // abandoned meeting-scoped playback directories after process death.
    }
  }

  void _reportFailure() {
    _states.add(
      const AudioPlaybackState(
        status: AudioPlaybackStatus.failed,
        errorCode: 'playback.failed',
      ),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = Completer<void>();
    _operationTail = _operationTail.then((_) async {
      try {
        await operation();
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
