import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_engine.dart';
import 'package:meettrace/data/services/audio/pcm_wav_file_writer.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/meeting_directory_deletion_service.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';

import 'remote_test_support.dart';

void main() {
  late Directory root;
  late AppFileLayout layout;
  late File pcm;
  final raw = Uint8List.fromList([for (var i = 0; i < 32000; i++) i % 251]);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('remote-privacy-test-');
    layout = AppFileLayout(rootPath: root.path);
    pcm = File(layout.meetingAudioPath('meeting'));
    await pcm.parent.create(recursive: true);
    await pcm.writeAsBytes(raw);
  });
  tearDown(() => root.delete(recursive: true));
  AudioSource source() => AudioSource(path: pcm.path, durationMs: 1000);

  for (final protocol in [
    TranscriptionProtocol.audioTranscriptions,
    TranscriptionProtocol.chatAudio,
  ]) {
    test('$protocol 有界 WAV 不依赖系统临时目录或磁盘副本', () async {
      final longPcm = Uint8List(maxInMemoryWavPcmBytes + 32000);
      for (var i = 0; i < longPcm.length; i++) {
        longPcm[i] = i % 251;
      }
      await pcm.writeAsBytes(longPcm);
      final uploaded = BytesBuilder();
      final lengths = <int>[];
      final engine = RemoteAsrEngine(
        profile: remoteProfile(protocol: protocol, maxUploadBytes: 24000000),
        credentials: TestCredentials(),
        client: MockClient((request) async {
          final Uint8List wav;
          if (protocol == TranscriptionProtocol.audioTranscriptions) {
            final offset = latin1.decode(request.bodyBytes).indexOf('RIFF');
            expect(offset, greaterThan(0));
            final body = Uint8List.sublistView(request.bodyBytes, offset);
            final length = ByteData.sublistView(body)
                .getUint32(40, Endian.little);
            wav = Uint8List.sublistView(body, 0, wavHeaderBytes + length);
          } else {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final message = (body['messages'] as List).last as Map;
            final content = (message['content'] as List).single as Map;
            wav = base64Decode(
              (content['input_audio'] as Map)['data'] as String,
            );
          }
          lengths.add(wav.length);
          expect(wav.length, lessThanOrEqualTo(maxInMemoryWavPcmBytes + 44));
          expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
          expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
          uploaded.add(wav.sublist(wavHeaderBytes));
          expect(await _files(root), [pcm.path]);
          return http.Response(
            protocol == TranscriptionProtocol.chatAudio
                ? '{"choices":[{"finish_reason":"stop","message":{"content":"speech"}}]}'
                : '{"text":"speech"}',
            200,
          );
        }),
      );
      addTearDown(engine.dispose);
      await IOOverrides.runZoned(
        () => engine.finalizeMeeting(
          AudioSource(path: pcm.path, durationMs: 61000),
          meetingId: 'meeting',
        ),
        getSystemTempDirectory: () => throw StateError('禁止访问系统临时目录'),
      );
      expect(lengths, [maxInMemoryWavPcmBytes + 44, 32044]);
      expect(uploaded.takeBytes(), longPcm);
      expect(await pcm.readAsBytes(), longPcm);
      expect(await _files(root), [pcm.path]);
    });
  }

  test('请求尚未 finally 时没有落盘副本，并发请求及取消删除不会互相清理', () async {
    final pendingClient = _PendingUploadClient();
    final pendingEngine = RemoteAsrEngine(
      profile: remoteProfile(timeoutSeconds: 30),
      credentials: TestCredentials(),
      client: pendingClient,
    );
    final nextEngine = RemoteAsrEngine(
      profile: remoteProfile(),
      credentials: TestCredentials(),
      client: MockClient((_) async => http.Response('{"text":"next"}', 200)),
    );
    addTearDown(pendingEngine.dispose);
    addTearDown(nextEngine.dispose);
    await IOOverrides.runZoned(() async {
      final pending = pendingEngine.finalizeMeeting(
        source(),
        meetingId: 'meeting',
      );
      final canceled = expectLater(pending, throwsA(isA<AsrEngineException>()));
      await pendingClient.entered.future;
      // 网络请求仍挂起，模拟强杀前尚未执行 finally 的时点。
      // 即使从此不再执行 Dart 清理，也只有事实 PCM，没有需要启动回收的副本。
      expect(await _files(root), [pcm.path]);
      expect(latin1.decode(pendingClient.body), contains('RIFF'));
      final next = await nextEngine.finalizeMeeting(
        source(),
        meetingId: 'meeting',
      );
      expect(next.segments.single.text, 'next');
      expect(await pcm.readAsBytes(), raw);
      expect(await _files(root), [pcm.path]);

      pendingEngine.cancel();
      final staged = await MeetingDirectoryDeletionService(layout: layout)
          .stage('meeting');
      await staged.commit();
      await canceled;
      expect(pendingClient.aborted, isTrue);
      expect(await _files(root), isEmpty);
      expect(
        await Directory(layout.meetingDirectory('meeting')).exists(),
        isFalse,
      );
    }, getSystemTempDirectory: () => throw StateError('禁止访问系统临时目录'));
  });

  test('真实 HTTP 接收合法 WAV 时不创建磁盘发送副本', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<Uint8List>();
    server.listen((request) async {
      final bytes = await request.fold(
        BytesBuilder(),
        (builder, chunk) => builder..add(chunk),
      );
      received.complete(bytes.takeBytes());
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"text":"local fixture"}');
      await request.response.close();
    });
    final engine = RemoteAsrEngine(
      profile: remoteProfile(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/transcriptions'),
      ),
      credentials: TestCredentials(),
    );
    addTearDown(engine.dispose);
    await IOOverrides.runZoned(
      () => engine.finalizeMeeting(source(), meetingId: 'meeting'),
      getSystemTempDirectory: () => throw StateError('禁止访问系统临时目录'),
    );
    final body = await received.future;
    final offset = latin1.decode(body).indexOf('RIFF');
    expect(offset, greaterThan(0));
    final wav = Uint8List.sublistView(body, offset, offset + raw.length + 44);
    expect(ByteData.sublistView(wav).getUint32(40, Endian.little), raw.length);
    expect(wav.sublist(44), raw);
    expect(await _files(root), [pcm.path]);
    expect(await pcm.readAsBytes(), raw);
  });
}

Future<List<String>> _files(Directory root) async =>
    (await root
          .list(recursive: true, followLinks: false)
          .where((entry) => entry is File)
          .map((entry) => entry.path)
          .toList())
      ..sort();

final class _PendingUploadClient extends http.BaseClient {
  final entered = Completer<void>();
  late Uint8List body;
  bool aborted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    body = await request.finalize().toBytes();
    entered.complete();
    await (request as http.Abortable).abortTrigger;
    aborted = true;
    throw http.RequestAbortedException(request.url);
  }
}
