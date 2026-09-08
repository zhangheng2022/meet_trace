import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef TranscribeAudio = Future<Map<String, Object?>> Function(
  String model,
  Uint8List wav,
  String context,
);

/// 最小自有网关：只接收 Chat input_audio，厂商调用由用户的 adapter 完成。
final class OnlineAsrGateway {
  OnlineAsrGateway({
    required this.transcribe,
    this.bearerToken,
    this.timeout = const Duration(seconds: 60),
  });
  final TranscribeAudio transcribe;
  final String? bearerToken;
  final Duration timeout;
  HttpServer? _server;
  bool _busy = false;
  int get port => _server!.port;

  Future<void> start({int port = 8765}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen((request) {
      unawaited(_handle(request));
    });
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    var ownsSlot = false;
    try {
      if (bearerToken != null &&
          request.headers.value(HttpHeaders.authorizationHeader) !=
              'Bearer $bearerToken') {
        await _respond(request, 401, {'error': 'gateway.unauthorized'});
        return;
      }
      if (request.method != 'POST' ||
          request.uri.path != '/v1/chat/completions') {
        await _respond(request, 404, {'error': 'gateway.route_not_found'});
        return;
      }
      if (_busy) {
        await _respond(request, 429, {'error': 'gateway.busy'});
        return;
      }
      _busy = true;
      ownsSlot = true;
      final payload = await readBounded(
        request,
        4 * 1024 * 1024,
        timeout: const Duration(seconds: 10),
      );
      final body = jsonDecode(utf8.decode(payload));
      if (body is! Map<String, dynamic> ||
          body['stream'] != false ||
          body['model'] is! String ||
          (body['model'] as String).trim().isEmpty ||
          body['messages'] is! List<dynamic>) {
        throw const FormatException('gateway.invalid_request');
      }
      String? encoded;
      var context = '';
      for (final message in body['messages'] as List<dynamic>) {
        if (message is! Map<String, dynamic>) throw const FormatException();
        if (message['role'] == 'system' && message['content'] is String) {
          context = message['content'] as String;
        }
        if (message['role'] == 'user' && message['content'] is List<dynamic>) {
          for (final part in message['content'] as List<dynamic>) {
            if (part is! Map<String, dynamic> ||
                part['type'] != 'input_audio') {
              throw const FormatException();
            }
            final audio = part['input_audio'];
            if (encoded != null ||
                audio is! Map<String, dynamic> ||
                audio['format'] != 'wav' ||
                audio['data'] is! String) {
              throw const FormatException();
            }
            encoded = audio['data'] as String;
          }
        }
      }
      if (encoded == null) throw const FormatException();
      final wav = base64Decode(encoded);
      if (wav.length < 46 || wav.length > 1920044) {
        throw const FormatException();
      }
      final header = ByteData.sublistView(wav);
      if (ascii.decode(wav.sublist(0, 4)) != 'RIFF' ||
          ascii.decode(wav.sublist(8, 12)) != 'WAVE' ||
          header.getUint16(20, Endian.little) != 1 ||
          header.getUint16(22, Endian.little) != 1 ||
          header.getUint32(24, Endian.little) != 16000 ||
          header.getUint16(34, Endian.little) != 16 ||
          header.getUint32(40, Endian.little) != wav.length - 44) {
        throw const FormatException();
      }
      final result = await transcribe(
        body['model'] as String,
        wav,
        context,
      ).timeout(timeout);
      if (result['text'] is! String ||
          (result['text'] as String).length > 65536 ||
          (result['model_version'] != null &&
              result['model_version'] is! String)) {
        throw const FormatException();
      }
      await _respond(request, 200, {
        'model': body['model'],
        if (result['model_version'] != null)
          'model_version': result['model_version'],
        'choices': [
          {
            'index': 0,
            'finish_reason': 'stop',
            'message': {'role': 'assistant', 'content': result['text']},
          },
        ],
      });
    } on FormatException {
      await _respond(request, 400, {'error': 'gateway.invalid_payload'});
    } on TimeoutException {
      await _respond(request, 504, {'error': 'gateway.timeout'});
    } on Object {
      await _respond(request, 502, {'error': 'gateway.adapter_failed'});
    } finally {
      if (ownsSlot) _busy = false;
    }
  }

  Future<void> _respond(
    HttpRequest request,
    int status,
    Map<String, Object?> value,
  ) async {
    try {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(value));
      await request.response.close();
    } on Object {
      // 客户端已断开时释放请求；禁止输出请求、凭据或服务商响应。
    }
  }
}

Future<Uint8List> readBounded(
  Stream<List<int>> stream,
  int limit, {
  Duration timeout = const Duration(seconds: 55),
}) async {
  final bytes = BytesBuilder(copy: false);
  final iterator = StreamIterator<List<int>>(stream);
  final watch = Stopwatch()..start();
  try {
    while (true) {
      final remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) throw TimeoutException('gateway.timeout');
      if (!await iterator.moveNext().timeout(remaining)) break;
      final chunk = iterator.current;
      if (bytes.length + chunk.length > limit) throw const FormatException();
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  } finally {
    await iterator.cancel();
  }
}

/// executable 和参数只来自操作者的环境配置，从不来自 HTTP 请求。
Future<Map<String, Object?>> runAdapter(
  List<String> command,
  String model,
  Uint8List wav,
  String context,
) async {
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    runInShell: false,
  );
  final stderrDone = process.stderr.drain<void>();
  final output = readBounded(process.stdout, 1024 * 1024);
  output.ignore();
  try {
    final response = await (() async {
      process.stdin.writeln(
        jsonEncode({
          'model': model,
          'audio': {'format': 'wav', 'data': base64Encode(wav)},
          'context': context,
        }),
      );
      await process.stdin.close();
      final bytes = await output;
      if (await process.exitCode != 0) throw const FormatException();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      return decoded;
    })().timeout(const Duration(seconds: 55));
    return response;
  } finally {
    process.kill();
    await stderrDone.timeout(const Duration(seconds: 1), onTimeout: () {});
  }
}
