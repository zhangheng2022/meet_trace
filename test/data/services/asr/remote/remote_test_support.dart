import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/ports/transcription_profiles.dart';

TranscriptionProfile remoteProfile({
  TranscriptionProtocol protocol = TranscriptionProtocol.audioTranscriptions,
  Uri? endpoint,
  int maxUploadBytes = 32044,
  int timeoutSeconds = 1,
  String? modelVersion,
  String? credentialRef = 'test-header-reference',
  String language = 'auto',
  String prompt = '',
}) => TranscriptionProfile(
  id: 'test-profile',
  name: 'Custom ASR',
  revision: 1,
  protocol: protocol,
  modelId: 'custom-transcribe',
  modelVersion: modelVersion,
  endpoint:
      endpoint ??
      Uri.parse('https://example.invalid/custom/transcribe?api-version=test'),
  credentialRef: credentialRef,
  maxUploadBytes: maxUploadBytes,
  requestTimeoutSeconds: timeoutSeconds,
  language: language,
  prompt: prompt,
);

final class TestCredentials implements TranscriptionCredentialStore {
  TestCredentials({this.headers = const {'X-Api-Key': 'test-secret-only'}});
  Map<String, String>? headers;
  final requestedReferences = <String>[];
  @override
  Future<Map<String, String>?> read(String reference) async {
    requestedReferences.add(reference);
    return headers;
  }

  @override
  Future<void> write(String reference, Map<String, String> headers) async {
    this.headers = headers;
  }

  @override
  Future<void> delete(String reference) async {
    headers = null;
  }

  @override
  Future<void> deleteAll() async {
    headers = null;
  }
}

/// A local protocol fixture. It neither connects to a provider nor reads recordings.
final class RealtimeFixture {
  RealtimeFixture._(this.server);
  final HttpServer server;
  final sockets = <WebSocket>[];
  final messages = <List<Map<String, dynamic>>>[];
  final audio = <BytesBuilder>[];
  final commits = <int>[];
  bool respondToCommits = true;
  bool duplicateCompletions = false;
  bool reverseCompletions = false;
  int? heldCompletionSequence;
  void Function()? heldCompletion;
  String? serverError;
  final _deferred = <void Function()>[];
  Uri get endpoint => Uri.parse(
    'ws://127.0.0.1:${server.port}/custom/realtime?intent=transcription',
  );

  static Future<RealtimeFixture> start() async {
    final fixture = RealtimeFixture._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    fixture.server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      final connection = fixture.sockets.length;
      fixture.sockets.add(socket);
      fixture.messages.add([]);
      fixture.audio.add(BytesBuilder(copy: false));
      fixture.commits.add(0);
      socket.listen((Object? data) {
        final message = jsonDecode(data! as String) as Map<String, dynamic>;
        fixture.messages[connection].add(message);
        if (message['type'] == 'session.update') {
          socket.add(jsonEncode({'type': 'session.updated'}));
        } else if (message['type'] == 'input_audio_buffer.append') {
          fixture.audio[connection].add(
            base64Decode(message['audio'] as String),
          );
        } else if (message['type'] == 'input_audio_buffer.commit') {
          final sequence = ++fixture.commits[connection];
          final item = 'item-$connection-$sequence';
          if (fixture.serverError != null) {
            socket.add(
              jsonEncode({
                'type': 'error',
                'error': {'message': fixture.serverError},
              }),
            );
            return;
          }
          socket.add(
            jsonEncode({
              'type': 'input_audio_buffer.committed',
              'item_id': item,
            }),
          );
          void complete() {
            socket.add(
              jsonEncode({
                'type': 'conversation.item.input_audio_transcription.delta',
                'item_id': item,
                'delta': 'partial-$sequence',
              }),
            );
            final done = jsonEncode({
              'type': 'conversation.item.input_audio_transcription.completed',
              'item_id': item,
              'transcript': 'final-$sequence',
            });
            socket.add(done);
            if (fixture.duplicateCompletions) socket.add(done);
          }

          if (!fixture.respondToCommits) return;
          if (sequence == fixture.heldCompletionSequence) {
            fixture.heldCompletion = complete;
          } else if (fixture.reverseCompletions) {
            fixture._deferred.add(complete);
            if (sequence == 3) {
              for (final callback in fixture._deferred.reversed) {
                callback();
              }
              fixture._deferred.clear();
            }
          } else {
            complete();
          }
        }
      }, onError: (Object _) {});
    });
    return fixture;
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }
}
