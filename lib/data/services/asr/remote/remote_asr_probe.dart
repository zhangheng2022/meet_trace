import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../domain/models/audio_source.dart';
import '../../../../domain/models/transcription_profile.dart';
import '../../../../domain/ports/asr_engine.dart';
import '../../../../domain/ports/transcription_profiles.dart';
import 'remote_asr_engine.dart';
import 'remote_realtime_session.dart';

final class RemoteAsrProbeResult {
  const RemoteAsrProbeResult({required this.accepted, this.errorCode});

  /// 只表示协议请求被接受；不是准确率或真实会议可用性保证。
  final bool accepted;
  final String? errorCode;
}

/// 只在用户显式点击测试时调用；生成短合成音及静音，不读取会议或麦克风。
Future<RemoteAsrProbeResult> probeRemoteAsr({
  required TranscriptionProfile profile,
  required TranscriptionCredentialStore credentials,
  http.Client? client,
  RemoteWebSocketConnector socketConnector = connectRemoteWebSocket,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'meettrace-asr-probe-',
  );
  final engine = RemoteAsrEngine(
    profile: profile,
    credentials: credentials,
    client: client,
    socketConnector: socketConnector,
  );
  try {
    final bytes = Uint8List(32000);
    final data = ByteData.sublistView(bytes);
    for (var index = 0; index < 3200; index++) {
      final amplitude = sin(2 * pi * 440 * index / 16000) * 1024;
      data.setInt16(index * 2, amplitude.round(), Endian.little);
    }
    final file = File('${directory.path}${Platform.pathSeparator}probe.pcm');
    await file.writeAsBytes(bytes, flush: true);
    await engine.finalizeMeeting(
      AudioSource(path: file.path, durationMs: 1000),
      meetingId: 'protocol-probe',
      snapshotId: 'protocol-probe',
    );
    return const RemoteAsrProbeResult(accepted: true);
  } on AsrEngineException catch (error) {
    return RemoteAsrProbeResult(accepted: false, errorCode: error.failure.code);
  } on Object {
    return const RemoteAsrProbeResult(
      accepted: false,
      errorCode: 'asr.remote.probe_failed',
    );
  } finally {
    await engine.dispose();
    await directory.delete(recursive: true);
  }
}
