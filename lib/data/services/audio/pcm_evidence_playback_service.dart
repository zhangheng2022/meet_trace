import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

import '../../../domain/ports/evidence_playback.dart';

const _sampleRate = 16000;
const _channels = 1;
const _bitsPerSample = 16;
const _bytesPerSample = _bitsPerSample ~/ 8;
const _bytesPerMillisecond = _sampleRate * _channels * _bytesPerSample ~/ 1000;

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

final class PcmEvidencePlaybackService implements EvidencePlaybackService {
  PcmEvidencePlaybackService({
    required this.output,
    required String temporaryDirectory,
  }) : temporaryDirectory = p.normalize(p.absolute(temporaryDirectory)) {
    _completionSubscription = output.onCompleted.listen((_) {
      _states.add(
        EvidencePlaybackState(
          status: EvidencePlaybackStatus.completed,
          startMs: _startMs,
          endMs: _endMs,
        ),
      );
    });
  }

  final DeviceAudioOutput output;
  final String temporaryDirectory;
  final StreamController<EvidencePlaybackState> _states =
      StreamController.broadcast();

  late final StreamSubscription<void> _completionSubscription;
  int? _startMs;
  int? _endMs;
  bool _disposed = false;

  String get _previewPath =>
      p.join(temporaryDirectory, 'meettrace-evidence-preview.wav');

  @override
  Stream<EvidencePlaybackState> get states => _states.stream;

  @override
  Future<void> play({
    required String audioPath,
    required int startMs,
    required int endMs,
  }) async {
    if (_disposed || startMs < 0 || endMs <= startMs) {
      throw const EvidencePlaybackException('playback.invalid_range');
    }
    final source = File(audioPath);
    if (!await source.exists()) {
      throw const EvidencePlaybackException('playback.audio_missing');
    }
    final startByte = startMs * _bytesPerMillisecond;
    final endByte = endMs * _bytesPerMillisecond;
    final sourceLength = await source.length();
    if (endByte > sourceLength) {
      throw const EvidencePlaybackException('playback.range_out_of_bounds');
    }

    try {
      await output.stop();
      await Directory(temporaryDirectory).create(recursive: true);
      final dataLength = endByte - startByte;
      final input = await source.open();
      final preview = File(_previewPath);
      final outputFile = await preview.open(mode: FileMode.write);
      try {
        await input.setPosition(startByte);
        final header = Uint8List(44);
        _writeWavHeader(header, dataLength);
        await outputFile.writeFrom(header);
        var remaining = dataLength;
        while (remaining > 0) {
          final chunk = await input.read(
            remaining > 64 * 1024 ? 64 * 1024 : remaining,
          );
          if (chunk.isEmpty) {
            throw const EvidencePlaybackException(
              'playback.audio_read_incomplete',
            );
          }
          await outputFile.writeFrom(chunk);
          remaining -= chunk.length;
        }
        await outputFile.flush();
      } finally {
        await input.close();
        await outputFile.close();
      }
      _startMs = startMs;
      _endMs = endMs;
      await output.playDeviceFile(_previewPath);
      _states.add(
        EvidencePlaybackState(
          status: EvidencePlaybackStatus.playing,
          startMs: startMs,
          endMs: endMs,
        ),
      );
    } on EvidencePlaybackException {
      rethrow;
    } on Object {
      _states.add(
        const EvidencePlaybackState(
          status: EvidencePlaybackStatus.failed,
          errorCode: 'playback.failed',
        ),
      );
      throw const EvidencePlaybackException('playback.failed');
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await output.stop();
    _states.add(
      const EvidencePlaybackState(status: EvidencePlaybackStatus.idle),
    );
  }

  @override
  Future<void> dispose() async {
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
  }
}

void _writeWavHeader(Uint8List target, int dataLength) {
  final data = ByteData.sublistView(target);
  _writeAscii(target, 0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  _writeAscii(target, 8, 'WAVE');
  _writeAscii(target, 12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, _channels, Endian.little)
    ..setUint32(24, _sampleRate, Endian.little)
    ..setUint32(28, _sampleRate * _channels * _bytesPerSample, Endian.little)
    ..setUint16(32, _channels * _bytesPerSample, Endian.little)
    ..setUint16(34, _bitsPerSample, Endian.little);
  _writeAscii(target, 36, 'data');
  data.setUint32(40, dataLength, Endian.little);
}

void _writeAscii(Uint8List target, int offset, String value) {
  target.setRange(offset, offset + value.length, value.codeUnits);
}
