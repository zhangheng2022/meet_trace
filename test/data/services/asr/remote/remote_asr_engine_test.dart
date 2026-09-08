import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_engine.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_probe.dart';
import 'package:meettrace/domain/models/app_failure.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';

import 'remote_test_support.dart';

void main() {
  late Directory temporary;
  late File pcm;
  final raw = Uint8List.fromList([for (var i = 0; i < 96000; i++) i % 251]);
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('remote-asr-test-');
    pcm = File('${temporary.path}/private-meeting-name.pcm');
    await pcm.writeAsBytes(raw);
  });
  tearDown(() => temporary.delete(recursive: true));
  AudioSource source() => AudioSource(path: pcm.path, durationMs: 3000);

  test('HTTP preview never uploads; complete PCM becomes ordered non-overlapping WAV chunks', () async {
    final uploaded = BytesBuilder();
    var calls = 0;
    final profile = remoteProfile(credentialRef: 'locked-credential-v7');
    final credentials = TestCredentials(
      headers: {'X-Api-Key': 'test-secret-only', 'X-Tenant': 'alpha\tbeta'},
    );
    final engine = RemoteAsrEngine(
      profile: profile,
      credentials: credentials,
      client: MockClient((request) async {
        calls++;
        expect(request.url, profile.endpoint);
        expect(request.followRedirects, isFalse);
        expect(request.headers['X-Api-Key'], 'test-secret-only');
        expect(request.headers['X-Tenant'], 'alpha\tbeta');
        final content = latin1.decode(request.bodyBytes);
        expect(content, contains('filename="audio.wav"'));
        expect(content, isNot(contains('private-meeting-name')));
        final offset = content.indexOf('RIFF');
        expect(offset, greaterThan(0));
        final wav = Uint8List.sublistView(request.bodyBytes, offset);
        final header = ByteData.sublistView(wav);
        expect(header.getUint32(24, Endian.little), 16000);
        final size = header.getUint32(40, Endian.little);
        expect(size + 44, lessThanOrEqualTo(profile.maxUploadBytes));
        uploaded.add(wav.sublist(44, 44 + size));
        return http.Response(
          jsonEncode({'text': 'chunk-$calls', 'model': 'alias-not-version'}),
          200,
        );
      }),
    );
    addTearDown(engine.dispose);
    await engine.initialize();
    await engine.acceptAudio(Float32List(320), sampleRate: 16000, startMs: 0);
    expect(calls, 0);
    final snapshot = await engine.finalizeMeeting(
      source(),
      meetingId: 'meeting',
      snapshotId: 'snapshot',
    );
    expect(calls, 3);
    expect(credentials.requestedReferences, [profile.credentialRef]);
    expect(uploaded.takeBytes(), raw);
    expect(await pcm.readAsBytes(), raw);
    expect(snapshot.segments.map((s) => (s.startMs, s.endMs, s.text)), [
      (0, 1000, 'chunk-1'),
      (1000, 2000, 'chunk-2'),
      (2000, 3000, 'chunk-3'),
    ]);
    expect(snapshot.transcriptionProfile, same(profile));
    expect(snapshot.actualModelVersion, 'unreported');
    expect(snapshot.reportedModelVersion, isNull);
    expect(snapshot.timingPrecision, TranscriptTimingPrecision.audioWindow);
  });

  test('server segment timestamps are retained only when valid for the submitted chunk', () async {
    final engine = RemoteAsrEngine(
      profile: remoteProfile(),
      credentials: TestCredentials(),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'text': 'speech',
            'model_version': 'weights-1',
            'segments': [
              {'start': 0.1, 'end': 0.8, 'text': 'speech'},
            ],
          }),
          200,
        ),
      ),
    );
    addTearDown(engine.dispose);
    final snapshot = await engine.finalizeMeeting(
      source(),
      meetingId: 'meeting',
    );
    expect(snapshot.timingPrecision, TranscriptTimingPrecision.segment);
    expect(snapshot.reportedModelVersion, 'weights-1');
    expect(snapshot.segments.map((s) => (s.startMs, s.endMs)), [
      (100, 800),
      (1100, 1800),
      (2100, 2800),
    ]);
  });

  test(
    'sub-millisecond server segments retain text within each chunk',
    () async {
      final engine = RemoteAsrEngine(
        profile: remoteProfile(),
        credentials: TestCredentials(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'text': 'short edge tolerance',
              'segments': [
                {'start': 0.52, 'end': 0.5205, 'text': 'short'},
                {'start': 0.9999, 'end': 1.0, 'text': 'edge'},
                {'start': 1.0, 'end': 1.0005, 'text': 'tolerance'},
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(engine.dispose);
      final snapshot = await engine.finalizeMeeting(
        source(),
        meetingId: 'meeting',
      );
      expect(snapshot.timingPrecision, TranscriptTimingPrecision.segment);
      expect(snapshot.segments.map((s) => (s.startMs, s.endMs, s.text)), [
        for (final offset in [0, 1000, 2000]) ...[
          (offset + 520, offset + 521, 'short'),
          (offset + 999, offset + 1000, 'edge'),
          (offset + 999, offset + 1000, 'tolerance'),
        ],
      ]);
      expect(await pcm.readAsBytes(), raw);
    },
  );

  test('invalid timestamps and mixed reported model versions cannot form a complete snapshot', () async {
    var calls = 0;
    for (final invalidTimes in [true, false]) {
      calls = 0;
      final engine = RemoteAsrEngine(
        profile: remoteProfile(),
        credentials: TestCredentials(),
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'text': 'speech',
              'model_version': 'weights-$calls',
              if (invalidTimes)
                'segments': [
                  {'start': 0, 'end': 20, 'text': 'speech'},
                ],
            }),
            200,
          );
        }),
      );
      addTearDown(engine.dispose);
      await expectLater(
        engine.finalizeMeeting(source(), meetingId: 'meeting'),
        throwsA(
          isA<AsrEngineException>()
              .having(
                (e) => e.failure.code,
                'safe code',
                invalidTimes
                    ? 'asr.remote.invalid_timestamps'
                    : 'asr.remote.model_version_changed',
              )
              .having(
                (e) => e.failure.stage,
                'stage',
                FailureStage.finalTranscription,
              ),
        ),
      );
    }
  });

  test('Chat input_audio is WAV base64 with mandatory transcription-only instruction', () async {
    final uploaded = BytesBuilder();
    final engine = RemoteAsrEngine(
      profile: remoteProfile(
        protocol: TranscriptionProtocol.chatAudio,
        language: 'zh',
        prompt: 'MeetTrace',
      ),
      credentials: TestCredentials(),
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'custom-transcribe');
        expect(body['stream'], isFalse);
        final messages = body['messages'] as List<dynamic>;
        final instruction =
            (messages.first as Map<String, dynamic>)['content'] as String;
        expect(instruction, contains('Transcribe the supplied audio verbatim'));
        expect(instruction, contains('expected language is zh'));
        expect(instruction, contains('MeetTrace'));
        final user = messages.last as Map<String, dynamic>;
        final input =
            ((user['content'] as List<dynamic>).single
                    as Map<String, dynamic>)['input_audio']
                as Map<String, dynamic>;
        expect(input['format'], 'wav');
        final wav = base64Decode(input['data'] as String);
        expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
        uploaded.add(wav.sublist(44));
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': '文本'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(engine.dispose);
    final snapshot = await engine.finalizeMeeting(
      source(),
      meetingId: 'meeting',
    );
    expect(uploaded.takeBytes(), raw);
    expect(snapshot.timingPrecision, TranscriptTimingPrecision.audioWindow);
  });

  test('pieces alone cannot replace the HTTP text response contract', () async {
    for (final pieces in <Object?>[
      null,
      {},
      [null],
      [7],
      [
        {'endMs': 1000, 'text': 'speech'},
      ],
      [
        {'startMs': 0.0, 'endMs': 1000, 'text': 'speech'},
      ],
      [
        {'startMs': 0, 'endMs': '1000', 'text': 'speech'},
      ],
      [
        {'startMs': 0, 'endMs': 1000, 'text': 7},
      ],
    ]) {
      final engine = RemoteAsrEngine(
        profile: remoteProfile(),
        credentials: TestCredentials(),
        client: MockClient(
          (_) async => http.Response(jsonEncode({'pieces': pieces}), 200),
        ),
      );
      addTearDown(engine.dispose);
      await expectLater(
        engine.finalizeMeeting(source(), meetingId: 'meeting'),
        throwsA(
          isA<AsrEngineException>().having(
            (e) => e.failure.code,
            'code',
            'asr.remote.invalid_response',
          ),
        ),
        reason: 'pieces: $pieces',
      );
    }
  });

  test(
    'extra HTTP pieces metadata does not override the transcript text',
    () async {
      final engine = RemoteAsrEngine(
        profile: remoteProfile(maxUploadBytes: 2000000),
        credentials: TestCredentials(),
        client: MockClient(
          (_) async => http.Response('{"text":"speech","pieces":[null]}', 200),
        ),
      );
      addTearDown(engine.dispose);
      final snapshot = await engine.finalizeMeeting(
        source(),
        meetingId: 'meeting',
      );
      expect(snapshot.segments.single.text, 'speech');
    },
  );

  for (final firstStatus in [200, 401]) {
    test(
      'temporary cleanup failure preserves HTTP $firstStatus and releases finalization',
      () async {
        var calls = 0;
        final engine = RemoteAsrEngine(
          profile: remoteProfile(maxUploadBytes: 2000000),
          credentials: TestCredentials(),
          client: MockClient((_) async {
            calls++;
            // The upload has been consumed. Remove only its generated directory
            // inside this test fixture so the engine's later cleanup fails.
            final requestDirectory = await temporary
                .list()
                .where((entry) => entry is Directory)
                .cast<Directory>()
                .single;
            await requestDirectory.delete(recursive: true);
            return http.Response(
              '{"text":"speech"}',
              calls == 1 ? firstStatus : 200,
            );
          }),
        );
        addTearDown(engine.dispose);
        await IOOverrides.runZoned(() async {
          final first = engine.finalizeMeeting(source(), meetingId: 'meeting');
          if (firstStatus == 200) {
            expect((await first).segments.single.text, 'speech');
          } else {
            await expectLater(
              first,
              throwsA(
                isA<AsrEngineException>().having(
                  (e) => e.failure.code,
                  'original code',
                  'asr.remote.http_401',
                ),
              ),
            );
          }
          final next = await engine.finalizeMeeting(
            source(),
            meetingId: 'meeting',
          );
          expect(next.segments.single.text, 'speech');
        }, getSystemTempDirectory: () => temporary);
        expect(calls, 2);
        expect(await pcm.readAsBytes(), raw);
      },
    );
  }

  test(
    'non-millisecond tail remains covered within recorded floor duration',
    () async {
      final fractional = Uint8List.fromList([...raw, 123, 45]);
      await pcm.writeAsBytes(fractional);
      final uploaded = BytesBuilder();
      final engine = RemoteAsrEngine(
        profile: remoteProfile(),
        credentials: TestCredentials(),
        client: MockClient((request) async {
          final offset = latin1.decode(request.bodyBytes).indexOf('RIFF');
          final wav = Uint8List.sublistView(request.bodyBytes, offset);
          final count = ByteData.sublistView(wav).getUint32(40, Endian.little);
          uploaded.add(wav.sublist(44, 44 + count));
          return http.Response('{"text":"speech"}', 200);
        }),
      );
      addTearDown(engine.dispose);
      final snapshot = await engine.finalizeMeeting(
        source(),
        meetingId: 'meeting',
      );
      expect(uploaded.takeBytes(), fractional);
      expect(snapshot.segments.last.endMs, 3000);
      for (var i = 1; i < snapshot.segments.length; i++) {
        expect(snapshot.segments[i].startMs, snapshot.segments[i - 1].endMs);
      }
    },
  );

  test('Chat truncated responses are rejected', () async {
    final engine = RemoteAsrEngine(
      profile: remoteProfile(protocol: TranscriptionProtocol.chatAudio),
      credentials: TestCredentials(),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'length',
                'message': {'content': 'partial'},
              },
            ],
          }),
          200,
        ),
      ),
    );
    addTearDown(engine.dispose);
    await expectLater(
      engine.finalizeMeeting(source(), meetingId: 'meeting'),
      throwsA(
        isA<AsrEngineException>().having(
          (e) => e.failure.code,
          'code',
          'asr.remote.incomplete_response',
        ),
      ),
    );
  });

  test(
    'HTTP errors expose only bounded safe codes and never retry paid requests',
    () async {
      var calls = 0;
      final engine = RemoteAsrEngine(
        profile: remoteProfile(),
        credentials: TestCredentials(),
        client: MockClient((_) async {
          calls++;
          return http.Response(
            'test-secret-only private transcript https://private-host/path',
            401,
          );
        }),
      );
      addTearDown(engine.dispose);
      await expectLater(
        engine.finalizeMeeting(source(), meetingId: 'meeting'),
        throwsA(
          isA<AsrEngineException>()
              .having((e) => e.failure.code, 'code', 'asr.remote.http_401')
              .having(
                (e) => e.toString(),
                'safe toString',
                isNot(contains('test-secret-only')),
              ),
        ),
      );
      expect(calls, 1);
      expect(engine.metrics.lastErrorCode, 'asr.remote.http_401');
    },
  );

  test(
    'missing referenced credentials never silently sends unauthenticated audio',
    () async {
      var calls = 0;
      final engine = RemoteAsrEngine(
        profile: remoteProfile(),
        credentials: TestCredentials(headers: null),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(engine.dispose);
      await expectLater(
        engine.finalizeMeeting(source(), meetingId: 'meeting'),
        throwsA(
          isA<AsrEngineException>().having(
            (e) => e.failure.code,
            'code',
            'asr.remote.credentials_missing',
          ),
        ),
      );
      expect(calls, 0);
    },
  );

  test(
    'an anonymous source skips credential lookup and sends no authentication',
    () async {
      final credentials = TestCredentials(headers: null);
      final sentHeaders = <Map<String, String>>[];
      final engine = RemoteAsrEngine(
        profile: remoteProfile(credentialRef: null, maxUploadBytes: 2000000),
        credentials: credentials,
        client: MockClient((request) async {
          sentHeaders.add(Map.of(request.headers));
          return http.Response('{"text":"speech"}', 200);
        }),
      );
      addTearDown(engine.dispose);
      final snapshot = await engine.finalizeMeeting(
        source(),
        meetingId: 'meeting',
      );
      expect(snapshot.segments.single.text, 'speech');
      expect(credentials.requestedReferences, isEmpty);
      expect(sentHeaders, hasLength(1));
      expect(
        sentHeaders.single.keys.map((name) => name.toLowerCase()),
        isNot(anyOf(contains('authorization'), contains('x-api-key'))),
      );
    },
  );

  test(
    'runtime rejects invalid stored headers before HTTP or WebSocket traffic',
    () async {
      for (final headers in [
        {'Host': 'example.invalid'},
        {'Content-Length': '1'},
        {'Content-Type': 'application/json'},
        {'Transfer-Encoding': 'chunked'},
        {'Connection': 'upgrade'},
        {'Upgrade': 'websocket'},
        {'sEc-WeBsOcKeT-Key': 'value'},
        {'Bad Name': 'value'},
        {'X-Api-Key\n': 'value'},
        {'X-Api-Key': 'value\rvalue'},
        {'X-Api-Key': 'value\nvalue'},
        {'X-Api-Key': 'value\x00value'},
        {'X-Api-Key': 'value\x08value'},
        {'X-Api-Key': 'value\x0bvalue'},
        {'X-Api-Key': 'value\x1fvalue'},
        {'X-Api-Key': 'value\x7fvalue'},
        {'X-Api-Key': 'value\x80value'},
        {'X-Api-Key': 'value\xffvalue'},
        {'X-Api-Key': 'value\u0100value'},
        {'X-Api-Key': 'value中文value'},
      ]) {
        for (final protocol in [
          TranscriptionProtocol.audioTranscriptions,
          TranscriptionProtocol.realtimeTranscription,
        ]) {
          var requests = 0;
          final engine = RemoteAsrEngine(
            profile: remoteProfile(
              protocol: protocol,
              endpoint: protocol == TranscriptionProtocol.realtimeTranscription
                  ? Uri.parse('wss://example.invalid/realtime')
                  : null,
            ),
            credentials: TestCredentials(headers: headers),
            client: MockClient((_) async {
              requests++;
              return http.Response('{}', 200);
            }),
            socketConnector: (_, _, _) async {
              requests++;
              throw StateError('Invalid headers reached the connector');
            },
          );
          addTearDown(engine.dispose);
          await expectLater(
            protocol == TranscriptionProtocol.realtimeTranscription
                ? engine.initialize()
                : engine.finalizeMeeting(source(), meetingId: 'meeting'),
            throwsA(
              isA<AsrEngineException>().having(
                (e) => e.failure.code,
                'code',
                'asr.remote.invalid_credentials',
              ),
            ),
            reason: '$protocol: $headers',
          );
          expect(requests, 0);
        }
      }
    },
  );

  test('request timeout aborts without automatic retry', () async {
    final client = _AbortClient();
    final engine = RemoteAsrEngine(
      profile: remoteProfile(),
      credentials: TestCredentials(),
      client: client,
    );
    addTearDown(engine.dispose);
    await expectLater(
      engine.finalizeMeeting(source(), meetingId: 'meeting'),
      throwsA(
        isA<AsrEngineException>().having(
          (e) => e.failure.code,
          'code',
          'asr.remote.timeout',
        ),
      ),
    );
    expect(client.calls, 1);
    expect(client.aborted, isTrue);
  });

  test('explicit connection probe uses only one second of generated tone and silence', () async {
    var calls = 0;
    final result = await probeRemoteAsr(
      profile: remoteProfile(),
      credentials: TestCredentials(),
      client: MockClient((request) async {
        calls++;
        final offset = latin1.decode(request.bodyBytes).indexOf('RIFF');
        final wav = request.bodyBytes.sublist(offset, offset + 32044);
        expect(wav.sublist(44, 6444).any((b) => b != 0), isTrue);
        expect(wav.sublist(6444).every((b) => b == 0), isTrue);
        return http.Response('{"text":""}', 200);
      }),
    );
    expect(calls, 1);
    expect(result.accepted, isTrue);
  });
}

final class _AbortClient extends http.BaseClient {
  int calls = 0;
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    final abortable = request as http.Abortable;
    await abortable.abortTrigger;
    aborted = true;
    throw http.RequestAbortedException(request.url);
  }
}
