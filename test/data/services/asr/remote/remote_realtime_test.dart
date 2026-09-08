import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/remote/pcm16_resampler.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_engine.dart';
import 'package:meettrace/data/services/asr/remote/remote_realtime_session.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';

import 'remote_test_support.dart';

void main() {
  late RealtimeFixture fixture;
  setUp(() async {
    fixture = await RealtimeFixture.start();
  });
  tearDown(() => fixture.close());

  test('final replay sends all PCM at 24 kHz and restores out-of-order completions', () async {
    fixture.reverseCompletions = true;
    fixture.duplicateCompletions = true;
    final profile = remoteProfile(
      protocol: TranscriptionProtocol.realtimeTranscription,
      endpoint: fixture.endpoint,
      maxUploadBytes: 2000000,
      timeoutSeconds: 3,
    );
    final temp = await Directory.systemTemp.createTemp('remote-replay-test-');
    addTearDown(() => temp.delete(recursive: true));
    final raw = Uint8List(17 * 32000);
    final data = ByteData.sublistView(raw);
    for (var i = 0; i < raw.length ~/ 2; i++) {
      data.setInt16(i * 2, (sin(i * 0.113) * 12000).round(), Endian.little);
    }
    final file = await File('${temp.path}/source.pcm').writeAsBytes(raw);
    final engine = RemoteAsrEngine(
      profile: profile,
      credentials: TestCredentials(),
    );
    addTearDown(engine.dispose);
    final snapshot = await engine.finalizeMeeting(
      AudioSource(path: file.path, durationMs: 17000),
      meetingId: 'meeting',
      snapshotId: 'final',
    );
    final expected = Pcm16To24Resampler();
    final expectedBytes = BytesBuilder()
      ..add(expected.add(decodeRemotePcm16(raw)))
      ..add(expected.finish());
    expect(fixture.audio.single.toBytes(), expectedBytes.takeBytes());
    expect(fixture.commits, [3]);
    expect(snapshot.segments.map((s) => (s.startMs, s.endMs, s.text)), [
      (0, 8000, 'final-1'),
      (8000, 16000, 'final-2'),
      (16000, 17000, 'final-3'),
    ]);
    expect(snapshot.timingPrecision, TranscriptTimingPrecision.audioWindow);
    expect(await file.readAsBytes(), raw);
    final update = fixture.messages.single.first;
    final session = update['session'] as Map<String, dynamic>;
    expect(session['type'], 'transcription');
    final input =
        ((session['audio'] as Map<String, dynamic>)['input']
            as Map<String, dynamic>);
    expect(input['format'], {'type': 'audio/pcm', 'rate': 24000});
    expect(input['turn_detection'], isNull);
  });

  test('live updates share item identity, flush keeps connection, final uses a fresh full replay', () async {
    fixture.duplicateCompletions = true;
    final engine = RemoteAsrEngine(
      profile: remoteProfile(
        protocol: TranscriptionProtocol.realtimeTranscription,
        endpoint: fixture.endpoint,
        maxUploadBytes: 2000000,
      ),
      credentials: TestCredentials(),
    );
    addTearDown(engine.dispose);
    final events = <TranscriptSegmentEvent>[];
    final completed = Completer<void>();
    final subscription = engine.events.listen((event) {
      if (event is TranscriptSegmentEvent) {
        events.add(event);
        if (events.where((e) => e.isFinalForWindow).length == 2 &&
            !completed.isCompleted) {
          completed.complete();
        }
      }
    });
    addTearDown(subscription.cancel);
    await engine.acceptAudio(Float32List(16000), sampleRate: 16000, startMs: 0);
    await engine.flushPreview();
    await engine.acceptAudio(
      Float32List(16000),
      sampleRate: 16000,
      startMs: 1000,
    );
    await engine.flushPreview();
    await completed.future.timeout(const Duration(seconds: 3));
    expect(fixture.sockets.length, 1);
    expect(events.length, 4);
    expect(events[0].segmentId, events[1].segmentId);
    expect(events[0].isFinalForWindow, isFalse);
    expect(events[1].isFinalForWindow, isTrue);
    expect(events[1].text, 'final-1');
    final temp = await Directory.systemTemp.createTemp('remote-fresh-test-');
    addTearDown(() => temp.delete(recursive: true));
    final raw = Uint8List(32000)..fillRange(0, 32000, 17);
    final file = await File('${temp.path}/source.pcm').writeAsBytes(raw);
    final snapshot = await engine.finalizeMeeting(
      AudioSource(path: file.path, durationMs: 1000),
      meetingId: 'meeting',
    );
    expect(fixture.sockets.length, 2);
    expect(snapshot.segments.single.endMs, 1000);
    expect(events.length, 4);
    final converter = Pcm16To24Resampler();
    final replay = BytesBuilder()
      ..add(converter.add(decodeRemotePcm16(raw)))
      ..add(converter.finish());
    expect(fixture.audio[1].toBytes(), replay.takeBytes());
  });

  test(
    'live commits within two seconds of audio without local VAD gating',
    () async {
      final done = Completer<void>();
      final session = RemoteRealtimeSession(
        profile: remoteProfile(
          protocol: TranscriptionProtocol.realtimeTranscription,
          endpoint: fixture.endpoint,
        ),
        headers: {},
        prefix: 'live',
        onPiece: (piece) {
          if (piece.isFinal && !done.isCompleted) done.complete();
        },
        onFailure: (code) {
          if (!done.isCompleted) done.completeError(code);
        },
      );
      addTearDown(session.close);
      await session.initialize();
      await session.add(Float32List(32000), startMs: 0);
      await session.add(Float32List(320), startMs: 2000);
      await done.future.timeout(const Duration(seconds: 3));
      expect(fixture.commits.single, 1);
    },
  );

  test(
    'sub-millisecond replay tail fits the recorded duration without losing PCM',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'remote-fraction-test-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final raw = Uint8List(8 * 32000 + 2);
      final file = await File('${temp.path}/source.pcm').writeAsBytes(raw);
      final engine = RemoteAsrEngine(
        profile: remoteProfile(
          protocol: TranscriptionProtocol.realtimeTranscription,
          endpoint: fixture.endpoint,
          maxUploadBytes: 2000000,
        ),
        credentials: TestCredentials(),
      );
      addTearDown(engine.dispose);
      final snapshot = await engine.finalizeMeeting(
        AudioSource(path: file.path, durationMs: 8000),
        meetingId: 'meeting',
      );
      expect(snapshot.segments.single.startMs, 0);
      expect(snapshot.segments.single.endMs, 8000);
      expect(snapshot.segments.single.text, 'final-1 final-2');
      // Complete source conversion plus the protocol's derived minimum-commit padding.
      expect(
        fixture.audio.single.length,
        greaterThanOrEqualTo((raw.length ~/ 2 * 3 + 1) ~/ 2 * 2),
      );
      expect(await file.readAsBytes(), raw);
    },
  );

  test('unresponsive final completion times out with a safe code', () async {
    fixture.respondToCommits = false;
    final session = RemoteRealtimeSession(
      profile: remoteProfile(
        protocol: TranscriptionProtocol.realtimeTranscription,
        endpoint: fixture.endpoint,
      ),
      headers: {},
      prefix: 'timeout',
      onPiece: (_) {},
      onFailure: (_) {},
    );
    addTearDown(session.close);
    await session.initialize();
    await session.add(Float32List(16000), startMs: 0);
    await expectLater(
      session.finish(),
      throwsA(
        isA<RemoteAsrProtocolException>().having(
          (e) => e.code,
          'safe code',
          'asr.remote.timeout',
        ),
      ),
    );
  });

  test(
    'server text and credentials never appear in exposed websocket failures',
    () async {
      fixture.serverError = 'test-secret-only private transcript';
      final failure = Completer<String>();
      final session = RemoteRealtimeSession(
        profile: remoteProfile(
          protocol: TranscriptionProtocol.realtimeTranscription,
          endpoint: fixture.endpoint,
        ),
        headers: {},
        prefix: 'error',
        onPiece: (_) {},
        onFailure: (code) {
          if (!failure.isCompleted) failure.complete(code);
        },
      );
      addTearDown(session.close);
      await session.initialize();
      await session.add(Float32List(16000), startMs: 0);
      await expectLater(
        session.finish(),
        throwsA(
          isA<RemoteAsrProtocolException>().having(
            (e) => e.toString(),
            'safe error',
            'asr.remote.server_rejected',
          ),
        ),
      );
      expect(await failure.future, 'asr.remote.server_rejected');
    },
  );

  test(
    'websocket authentication is not forwarded to a redirect destination',
    () async {
      var leaked = false;
      final redirect = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final destination = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => redirect.close(force: true));
      addTearDown(() => destination.close(force: true));
      destination.listen((request) {
        leaked = true;
        request.response.close();
      });
      redirect.listen((request) async {
        request.response.statusCode = HttpStatus.temporaryRedirect;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${destination.port}/stolen',
        );
        await request.response.close();
      });
      await expectLater(
        connectRemoteWebSocket(
          Uri.parse('ws://127.0.0.1:${redirect.port}/start'),
          {'Authorization': 'Bearer test-secret-only'},
          const Duration(seconds: 1),
        ),
        throwsA(isA<Object>()),
      );
      expect(leaked, isFalse);
    },
  );
}
