import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

import '../../../domain/ports/audio_playback.dart';
import 'pcm_wav_file_writer.dart';

abstract interface class DeviceAudioOutput {
  Stream<void> get onCompleted;

  Future<void> playDeviceFile(String path);

  Future<void> stop();

  Future<void> dispose();
}

final class AudioplayersDeviceAudioOutput implements DeviceAudioOutput {
  AudioplayersDeviceAudioOutput({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<void> get onCompleted => _player.onPlayerComplete;

  @override
  Future<void> playDeviceFile(String path) async {
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final class PcmAudioPlaybackService implements AudioPlaybackService {
  PcmAudioPlaybackService({
    required this.output,
    required String temporaryDirectory,
    this.wavWriter = const PcmWavFileWriter(),
  }) : temporaryDirectory = p.normalize(p.absolute(temporaryDirectory)) {
    _completionSubscription = output.onCompleted.listen((_) {
      if (!_disposeRequested && !_states.isClosed) {
        _states.add(
          AudioPlaybackState(
            status: AudioPlaybackStatus.completed,
            startMs: _startMs,
            endMs: _endMs,
          ),
        );
      }
    });
  }

  final DeviceAudioOutput output;
  final String temporaryDirectory;
  final PcmWavFileWriter wavWriter;
  final StreamController<AudioPlaybackState> _states =
      StreamController.broadcast();

  late final StreamSubscription<void> _completionSubscription;
  int? _startMs;
  int? _endMs;
  bool _disposed = false;
  bool _disposeRequested = false;
  Future<void> _operationTail = Future.value();

  String get _previewPath =>
      p.join(temporaryDirectory, 'meettrace-audio-preview.wav');

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
      await Directory(temporaryDirectory).create(recursive: true);
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
      rethrow;
    } on PcmWavWriteException catch (error) {
      _states.add(
        const AudioPlaybackState(
          status: AudioPlaybackStatus.failed,
          errorCode: 'playback.failed',
        ),
      );
      throw AudioPlaybackException(error.code);
    } on Object {
      _states.add(
        const AudioPlaybackState(
          status: AudioPlaybackStatus.failed,
          errorCode: 'playback.failed',
        ),
      );
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
      await output.dispose();
      final preview = File(_previewPath);
      if (await preview.exists()) {
        await preview.delete();
      }
      await _states.close();
    });
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
