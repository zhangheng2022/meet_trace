import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/audio/pcm_audio_playback_service.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/domain/ports/audio_playback.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-playback-');
    layout = AppFileLayout(rootPath: root.path);
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
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);

    await service.play(audioPath: source.path, startMs: 250, endMs: 750);

    final wav = await File(output.playedPaths.single).readAsBytes();
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 44 + 16000);
    expect(wav.sublist(44), pcm.sublist(8000, 24000));
    expect(await source.readAsBytes(), pcm);
    expect(
      File(output.playedPaths.single).parent.parent.path,
      layout.meetingPlaybackTempDirectory('meeting-1'),
    );
    expect(
      await File('${root.path}/meettrace-audio-preview.wav').exists(),
      isFalse,
    );
  });

  test('越界区间或缺失事实音频不会调用播放器', () async {
    final output = _PlaybackOutput();
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);

    await expectLater(
      service.play(
        audioPath: '${root.path}/missing.pcm',
        startMs: 0,
        endMs: 100,
      ),
      throwsA(isA<AudioPlaybackException>()),
    );
    expect(output.playedPaths, isEmpty);
  });

  test('dispose 等待进行中的播放后再释放播放器和临时文件', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final output = _PlaybackOutput()..playGate = Completer<void>();
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );

    final playing = service.play(
      audioPath: source.path,
      startMs: 0,
      endMs: 1000,
    );
    await output.playStarted.future;
    final disposing = service.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(output.disposeCalls, 0);

    output.playGate!.complete();
    await playing;
    await disposing;

    expect(output.disposeCalls, 1);
    expect(await File(output.playedPaths.single).exists(), isFalse);
    expect(await File(output.playedPaths.single).parent.exists(), isFalse);
  });

  test('停止播放立即删除临时 WAV 且保留事实 PCM', () async {
    final source = File('${root.path}/fact.pcm');
    final pcm = Uint8List(32000);
    await source.writeAsBytes(pcm);
    final output = _PlaybackOutput();
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);
    await service.play(audioPath: source.path, startMs: 0, endMs: 1000);
    final preview = File(output.playedPaths.single);
    expect(await preview.exists(), isTrue);

    await service.stop();

    expect(await preview.parent.exists(), isFalse);
    expect(await source.readAsBytes(), pcm);
  });

  test('自然播放结束后先释放播放器再删除临时 WAV', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final output = _PlaybackOutput();
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);
    await service.play(audioPath: source.path, startMs: 250, endMs: 750);
    final preview = File(output.playedPaths.single);
    final completed = service.states.firstWhere(
      (state) => state.status == AudioPlaybackStatus.completed,
    );

    output.complete();
    final state = await completed;

    expect(output.stopCalls, 2);
    expect(state.startMs, 250);
    expect(state.endMs, 750);
    expect(await preview.parent.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('独立播放器不覆盖或删除同会议其他播放器的缓存', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final firstOutput = _PlaybackOutput();
    final secondOutput = _PlaybackOutput();
    final first = PcmAudioPlaybackService(
      output: firstOutput,
      layout: layout,
      meetingId: 'meeting-1',
    );
    final second = PcmAudioPlaybackService(
      output: secondOutput,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.play(audioPath: source.path, startMs: 0, endMs: 500);
    await second.play(audioPath: source.path, startMs: 500, endMs: 1000);
    final firstPreview = File(firstOutput.playedPaths.single);
    final secondPreview = File(secondOutput.playedPaths.single);
    expect(firstPreview.path, isNot(secondPreview.path));

    await first.stop();

    expect(await firstPreview.exists(), isFalse);
    expect(await secondPreview.exists(), isTrue);
  });

  test('替换播放时删除旧缓存且迟到的完成处理不删除新缓存', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final output = _PlaybackOutput();
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);
    await service.play(audioPath: source.path, startMs: 0, endMs: 500);
    final firstPreview = File(output.playedPaths.single);

    final replacing = service.play(
      audioPath: source.path,
      startMs: 500,
      endMs: 1000,
    );
    output.complete();
    await replacing;
    await Future<void>.delayed(Duration.zero);

    expect(output.playedPaths, hasLength(2));
    expect(await firstPreview.parent.exists(), isFalse);
    expect(await File(output.playedPaths.last).exists(), isTrue);
    expect(output.stopCalls, 2);
  });

  test('播放器启动失败也删除已写出的音频副本', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final output = _PlaybackOutput()..playError = StateError('play failed');
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);

    await expectLater(
      service.play(audioPath: source.path, startMs: 0, endMs: 1000),
      throwsA(isA<AudioPlaybackException>()),
    );

    expect(await File(output.playedPaths.single).parent.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('旧 native 完成事件在新播放开始后到达也不停止新播放', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final output = _PlaybackOutput();
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    addTearDown(service.dispose);
    await service.play(audioPath: source.path, startMs: 0, endMs: 500);
    final oldPath = output.playedPaths.single;
    output
      ..nextPlayStarted = Completer<void>()
      ..playGate = Completer<void>();

    final replacing = service.play(
      audioPath: source.path,
      startMs: 500,
      endMs: 1000,
    );
    await output.nextPlayStarted!.future;
    final newPreview = File(output.playedPaths.last);
    output.complete(oldPath);
    output.playGate!.complete();
    await replacing;
    await Future<void>.delayed(Duration.zero);

    expect(output.stopCalls, 2);
    expect(await newPreview.exists(), isTrue);
    final completed = service.states.firstWhere(
      (state) => state.status == AudioPlaybackStatus.completed,
    );
    output.complete(newPreview.path);
    await completed;
    expect(await newPreview.exists(), isFalse);
  });

  test('播放器释放失败仍尝试清除音频副本并关闭状态流', () async {
    final source = File('${root.path}/fact.pcm');
    await source.writeAsBytes(Uint8List(32000));
    final output = _PlaybackOutput()
      ..disposeError = StateError('dispose failed');
    final service = PcmAudioPlaybackService(
      output: output,
      layout: layout,
      meetingId: 'meeting-1',
    );
    await service.play(audioPath: source.path, startMs: 0, endMs: 1000);
    final closed = service.states.drain<void>();

    await expectLater(service.dispose(), throwsStateError);
    await closed;

    expect(await File(output.playedPaths.single).parent.exists(), isFalse);
  });

  test('原生适配器保留首次 player 注入并在替换前释放旧实例', () async {
    final operations = <String>[];
    final first = _NativePlayer('first', operations);
    final second = _NativePlayer('second', operations);
    addTearDown(first.completed.close);
    addTearDown(second.completed.close);
    final output = AudioplayersDeviceAudioOutput(
      player: first,
      playerFactory: () => second,
    );
    addTearDown(output.dispose);
    final completedPaths = <String>[];
    final subscription = output.onCompleted.listen(completedPaths.add);
    addTearDown(subscription.cancel);
    await output.playDeviceFile('first.wav');
    first.complete();
    await Future<void>.delayed(Duration.zero);

    await output.playDeviceFile('second.wav');
    first.complete();
    second.complete();
    await Future<void>.delayed(Duration.zero);

    expect(completedPaths, ['first.wav', 'second.wav']);
    expect(operations, [
      'first.play:first.wav',
      'first.stop',
      'first.dispose',
      'second.play:second.wav',
    ]);
    await output.dispose();
    expect(operations.last, 'second.dispose');
  });

  test('原生适配器从未播放也会释放注入的 player', () async {
    final operations = <String>[];
    final player = _NativePlayer('unused', operations);
    addTearDown(player.completed.close);
    final output = AudioplayersDeviceAudioOutput(player: player);

    await output.dispose();
    await output.dispose();

    expect(operations, ['unused.dispose']);
  });
}

final class _PlaybackOutput implements DeviceAudioOutput {
  final List<String> playedPaths = [];
  final StreamController<String> completed = StreamController.broadcast(
    sync: true,
  );
  final Completer<void> playStarted = Completer<void>();
  Completer<void>? nextPlayStarted;
  Completer<void>? playGate;
  Object? playError;
  Object? disposeError;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<String> get onCompleted => completed.stream;

  void complete([String? path]) => completed.add(path ?? playedPaths.last);

  @override
  Future<void> playDeviceFile(String path) async {
    playedPaths.add(path);
    if (!playStarted.isCompleted) {
      playStarted.complete();
    }
    nextPlayStarted?.complete();
    await playGate?.future;
    if (playError case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await completed.close();
    if (disposeError case final error?) throw error;
  }
}

final class _NativePlayer implements AudioPlayer {
  _NativePlayer(this.name, this.operations);

  final String name;
  final List<String> operations;
  final completed = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get onPlayerComplete => completed.stream;

  void complete() => completed.add(null);

  @override
  Future<void> stop() async {
    operations.add('$name.stop');
  }

  @override
  Future<void> dispose() async {
    operations.add('$name.dispose');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #play) {
      final source = invocation.positionalArguments.single as DeviceFileSource;
      operations.add('$name.play:${source.path}');
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
