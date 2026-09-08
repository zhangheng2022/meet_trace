import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/asr/remote/remote_asr_probe.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';

// 覆盖独立工具，不将网关服务端代码纳入应用运行依赖。
// ignore: avoid_relative_lib_imports
import '../../../../../tool/online_asr_gateway/lib/gateway.dart';
import 'remote_test_support.dart';

void main() {
  test('local compatible gateway forwards generated WAV to owned adapter and returns accepted result', () async {
    Uint8List? received;
    final gateway = OnlineAsrGateway(
      bearerToken: 'local-test-key',
      transcribe: (model, wav, context) async {
        received = wav;
        expect(model, 'custom-transcribe');
        expect(context, contains('Transcribe the supplied audio verbatim'));
        return {'text': '', 'model_version': 'local-test-version'};
      },
    );
    await gateway.start(port: 0);
    addTearDown(gateway.close);
    final result = await probeRemoteAsr(
      profile: remoteProfile(
        protocol: TranscriptionProtocol.chatAudio,
        endpoint: Uri.parse(
          'http://127.0.0.1:${gateway.port}/v1/chat/completions',
        ),
      ),
      credentials: TestCredentials(
        headers: {'Authorization': 'Bearer local-test-key'},
      ),
    );
    expect(result.accepted, isTrue);
    expect(received!.length, 32044);
  });

  test('local gateway rejects missing authentication before invoking native adapter', () async {
    var called = false;
    final gateway = OnlineAsrGateway(
      bearerToken: 'local-test-key',
      transcribe: (_, _, _) async {
        called = true;
        return {'text': ''};
      },
    );
    await gateway.start(port: 0);
    addTearDown(gateway.close);
    final result = await probeRemoteAsr(
      profile: remoteProfile(
        protocol: TranscriptionProtocol.chatAudio,
        endpoint: Uri.parse(
          'http://127.0.0.1:${gateway.port}/v1/chat/completions',
        ),
      ),
      credentials: TestCredentials(),
    );
    expect(result.accepted, isFalse);
    expect(result.errorCode, 'asr.remote.http_401');
    expect(called, isFalse);
  });

  test('adapter response cannot leak its private failure text', () async {
    final gateway = OnlineAsrGateway(
      transcribe: (_, _, _) async {
        throw StateError('private-secret-and-transcript');
      },
    );
    await gateway.start(port: 0);
    addTearDown(gateway.close);
    final result = await probeRemoteAsr(
      profile: remoteProfile(
        protocol: TranscriptionProtocol.chatAudio,
        endpoint: Uri.parse(
          'http://127.0.0.1:${gateway.port}/v1/chat/completions',
        ),
      ),
      credentials: TestCredentials(),
    );
    expect(result.errorCode, 'asr.remote.http_502');
  });
}
