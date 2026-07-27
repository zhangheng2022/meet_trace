import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/pcm_evidence_playback_service.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-playback-');
  });

  tearDown(() => root.delete(recursive: true));

  test('只把证据区间封装为 16kHz 单声道 PCM16 WAV', () async {
    final source = File('${root.path}/fact.pcm');
    final pcm = Uint8List(32000);
    for (var index = 0; index < pcm.length; index++) {
      pcm[index] = index % 251;
    }
    await source.writeAsBytes(pcm);
    final output = _PlaybackOutput();
    final service = PcmEvidencePlaybackService(
      output: output,
      temporaryDirectory: root.path,
    );

    await service.play(audioPath: source.path, startMs: 250, endMs: 750);

    final wav = await File(output.playedPaths.single).readAsBytes();
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 16000);
    expect(wav.sublist(44), pcm.sublist(8000, 24000));
  });

  test('越界区间或缺失事实音频不会调用播放器', () async {
    final output = _PlaybackOutput();
    final service = PcmEvidencePlaybackService(
      output: output,
      temporaryDirectory: root.path,
    );

    await expectLater(
      service.play(
        audioPath: '${root.path}/missing.pcm',
        startMs: 0,
        endMs: 100,
      ),
      throwsA(isA<EvidencePlaybackException>()),
    );
    expect(output.playedPaths, isEmpty);
  });
}

final class _PlaybackOutput implements DeviceAudioOutput {
  final List<String> playedPaths = [];
  final Stream<void> completed = const Stream.empty();

  @override
  Stream<void> get onCompleted => completed;

  @override
  Future<void> playDeviceFile(String path) async {
    playedPaths.add(path);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
