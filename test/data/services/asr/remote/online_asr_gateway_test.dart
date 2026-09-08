import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:meettrace/data/services/asr/remote/remote_asr_probe.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';

// 覆盖独立工具，不将网关服务端代码纳入应用运行依赖。
// ignore: avoid_relative_lib_imports
import '../../../../../tool/online_asr_gateway/lib/gateway.dart';
import 'remote_test_support.dart';

void main() {
  test('local compatible gateway forwards generated WAV to owned adapter and returns accepted result', () async {
    Uint8List? received;
    String? receivedModel;
    String? receivedContext;
    final gateway = OnlineAsrGateway(
      bearerToken: 'local-test-key',
      transcribe: (model, wav, context) async {
        received = wav;
        receivedModel = model;
        receivedContext = context;
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
    expect(received, hasLength(32044));
    expect(receivedModel, 'custom-transcribe');
    expect(receivedContext, contains('Transcribe the supplied audio verbatim'));
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

  test(
    'early 401 and 404 preserve their status with a full 60-second upload',
    () async {
      var calls = 0;
      final gateway = OnlineAsrGateway(
        bearerToken: 'test-token',
        transcribe: (_, _, _) async {
          calls++;
          return {'text': ''};
        },
      );
      await gateway.start(port: 0);
      addTearDown(gateway.close);
      final body = _payload(wav: _wav(seconds: 60));
      final unauthorized = await _post(gateway, body);
      expect(unauthorized.statusCode, 401);
      expect(jsonDecode(unauthorized.body), {'error': 'gateway.unauthorized'});
      final missing = await _post(
        gateway,
        body,
        path: '/missing',
        headers: {'Authorization': 'Bearer test-token'},
      );
      expect(missing.statusCode, 404);
      expect(jsonDecode(missing.body), {'error': 'gateway.route_not_found'});
      expect(calls, 0);
    },
  );

  test(
    'busy gateway returns 429 for a large body and retains its active slot',
    () async {
      final entered = Completer<void>();
      final release = Completer<Map<String, Object?>>();
      var calls = 0;
      final gateway = OnlineAsrGateway(
        transcribe: (_, _, _) async {
          calls++;
          if (calls == 1) {
            entered.complete();
            return release.future;
          }
          return {'text': ''};
        },
      );
      await gateway.start(port: 0);
      addTearDown(gateway.close);
      final first = _post(gateway, _payload());
      try {
        await entered.future.timeout(const Duration(seconds: 5));
        final second = await _post(gateway, _payload(wav: _wav(seconds: 60)));
        expect(second.statusCode, 429);
        expect(jsonDecode(second.body), {'error': 'gateway.busy'});
        expect(calls, 1);
      } finally {
        release.complete({'text': ''});
        await first;
      }
      expect((await _post(gateway, _payload())).statusCode, 200);
    },
  );

  test('invalid WAV and bounded input failures stay client errors without invoking adapter', () async {
    var calls = 0;
    final gateway = OnlineAsrGateway(
      transcribe: (_, _, _) async {
        calls++;
        return {'text': ''};
      },
    );
    await gateway.start(port: 0);
    addTearDown(gateway.close);
    final invalidWav = _wav();
    ByteData.sublistView(invalidWav).setUint32(24, 24000, Endian.little);
    for (final body in [
      _payload(wav: invalidWav),
      _payload(wav: _wav(seconds: 61)),
      'x' * (4 * 1024 * 1024 + 1),
    ]) {
      final response = await _post(gateway, body);
      expect(response.statusCode, 400);
      expect(jsonDecode(response.body), {'error': 'gateway.invalid_payload'});
    }
    expect(calls, 0);
  });

  test('callback timeout reports 504 and releases the gateway slot', () async {
    final pending = Completer<Map<String, Object?>>();
    var calls = 0;
    final gateway = OnlineAsrGateway(
      timeout: const Duration(milliseconds: 50),
      transcribe: (_, _, _) async {
        calls++;
        return calls == 1 ? pending.future : {'text': ''};
      },
    );
    await gateway.start(port: 0);
    addTearDown(gateway.close);
    try {
      final response = await _post(gateway, _payload());
      expect(response.statusCode, 504);
      expect(jsonDecode(response.body), {'error': 'gateway.timeout'});
      expect((await _post(gateway, _payload())).statusCode, 200);
    } finally {
      pending.complete({'text': ''});
    }
  });

  test(
    'discarding an oversized body still cancels at the original deadline',
    () async {
      var cancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final read = readBounded(
        source.stream,
        4,
        timeout: const Duration(milliseconds: 50),
        drainOnLimit: true,
      );
      source.add([1, 2, 3, 4, 5]);
      await expectLater(read, throwsA(isA<TimeoutException>()));
      expect(cancelled, isTrue);
      await source.close();
    },
  );

  group('generated adapter processes', () {
    late Directory temporary;
    late File adapter;
    setUpAll(() async {
      temporary = await Directory.systemTemp.createTemp(
        'meettrace-gateway-test-',
      );
      adapter = File('${temporary.path}/adapter.dart');
      await adapter.writeAsString(_adapterFixture);
    });
    tearDownAll(() => temporary.delete(recursive: true));

    for (final mode in ['nonzero', 'bad-json', 'array', 'bad-shape', 'large']) {
      test('$mode adapter output reports sanitized 502', () async {
        final gateway = OnlineAsrGateway(
          transcribe: (model, wav, context) => runAdapter(
            [_dartExecutable, adapter.path, mode],
            model,
            wav,
            context,
            timeout: const Duration(seconds: 5),
          ),
        );
        await gateway.start(port: 0);
        addTearDown(gateway.close);
        final response = await _post(gateway, _payload());
        expect(response.statusCode, 502);
        expect(jsonDecode(response.body), {'error': 'gateway.adapter_failed'});
      });
    }

    test(
      'successful adapter receives and returns its complete bounded result',
      () async {
        final result = await runAdapter(
          [_dartExecutable, adapter.path, 'success'],
          'fixture-model',
          _wav(),
          'fixture-context',
          timeout: const Duration(seconds: 5),
        );
        expect(result, {'text': 'fixture-model:fixture-context'});
      },
    );

    test(
      'timeout reaps a blocked adapter before returning, escalating on POSIX',
      () async {
        final pidFile = File('${temporary.path}/blocked.pid');
        int? fixturePid;
        try {
          await expectLater(
            runAdapter(
              [_dartExecutable, adapter.path, 'blocked', pidFile.path],
              'fixture-model',
              _wav(seconds: 60),
              '',
              timeout: const Duration(seconds: 3),
            ),
            throwsA(isA<TimeoutException>()),
          );
          expect(await pidFile.exists(), isTrue);
          fixturePid = int.parse(await pidFile.readAsString());
          expect(Process.killPid(fixturePid), isFalse);
        } finally {
          // 仅清理本测试生成的 adapter PID；失败路径也不留下 fixture 进程。
          if (fixturePid == null && await pidFile.exists()) {
            fixturePid = int.parse(await pidFile.readAsString());
          }
          if (fixturePid != null) {
            Process.killPid(fixturePid, ProcessSignal.sigkill);
          }
        }
      },
    );
  });

  test('CLI reports malformed command, invalid port and blank token as configuration errors', () async {
    for (final environment in [
      {'MEETTRACE_GATEWAY_COMMAND': 'invalid-json'},
      {'MEETTRACE_GATEWAY_PORT': 'not-a-number'},
      {'MEETTRACE_GATEWAY_PORT': '65536'},
      {'MEETTRACE_GATEWAY_TOKEN': '   '},
    ]) {
      final result = await _runCli(
        environment.containsKey('MEETTRACE_GATEWAY_COMMAND')
            ? []
            : ['--fixture'],
        environment,
      );
      expect(result.code, 64);
      expect(result.error, contains('gateway.invalid_configuration'));
      expect(result.output, isEmpty);
    }
  });

  test(
    'CLI fixture ignores malformed adapter configuration and never starts it',
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final process = await _startCli(
        ['--fixture'],
        {
          'MEETTRACE_GATEWAY_COMMAND': 'invalid-json',
          'MEETTRACE_GATEWAY_PORT': '$port',
        },
      );
      final lines = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      );
      final errors = process.stderr.transform(utf8.decoder).join();
      errors.ignore();
      try {
        expect(
          await lines.moveNext().timeout(const Duration(seconds: 15)),
          isTrue,
        );
        expect(
          lines.current,
          startsWith('gateway.ready http://127.0.0.1:$port/'),
        );
        final response = await http
            .post(
              Uri.parse('http://127.0.0.1:$port/v1/chat/completions'),
              headers: {'Authorization': 'Bearer fixture-cli-token'},
              body: _payload(),
            )
            .timeout(const Duration(seconds: 5));
        expect(response.statusCode, 200);
        expect(response.body, contains('fixture-only'));
      } finally {
        await _stopFixtureProcess(process);
        await lines.cancel();
      }
      expect(await errors, contains('gateway.fixture_only'));
    },
  );
}

Future<http.Response> _post(
  OnlineAsrGateway gateway,
  String body, {
  String path = '/v1/chat/completions',
  Map<String, String>? headers,
}) => http
    .post(
      Uri.parse('http://127.0.0.1:${gateway.port}$path'),
      body: body,
      headers: headers,
    )
    .timeout(const Duration(seconds: 10));

String _payload({Uint8List? wav}) => jsonEncode({
  'model': 'fixture-model',
  'stream': false,
  'messages': [
    {
      'role': 'user',
      'content': [
        {
          'type': 'input_audio',
          'input_audio': {'format': 'wav', 'data': base64Encode(wav ?? _wav())},
        },
      ],
    },
  ],
});

Uint8List _wav({int seconds = 1}) {
  final bytes = Uint8List(44 + seconds * 32000);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 12, ascii.encode('WAVE'));
  bytes.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, bytes.length - 44, Endian.little);
  return bytes;
}

String get _dartExecutable {
  final runtime = File(Platform.resolvedExecutable);
  if (runtime.uri.pathSegments.last == 'dart' ||
      runtime.uri.pathSegments.last == 'dart.exe') {
    return runtime.path;
  }
  final cache = runtime.parent.parent.parent.parent;
  return '${cache.path}/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
}

Future<Process> _startCli(
  List<String> arguments,
  Map<String, String> environment,
) => Process.start(
  _dartExecutable,
  [
    File('tool/online_asr_gateway/bin/gateway.dart').absolute.path,
    ...arguments,
  ],
  environment: {
    'MEETTRACE_GATEWAY_COMMAND': '["unused-fixture-command"]',
    'MEETTRACE_GATEWAY_PORT': '8765',
    'MEETTRACE_GATEWAY_TOKEN': 'fixture-cli-token',
    ...environment,
  },
  runInShell: false,
);

Future<({int code, String output, String error})> _runCli(
  List<String> arguments,
  Map<String, String> environment,
) async {
  final process = await _startCli(arguments, environment);
  final output = process.stdout.transform(utf8.decoder).join();
  final error = process.stderr.transform(utf8.decoder).join();
  output.ignore();
  error.ignore();
  try {
    final code = await process.exitCode.timeout(const Duration(seconds: 15));
    return (code: code, output: await output, error: await error);
  } finally {
    await _stopFixtureProcess(process);
  }
}

Future<void> _stopFixtureProcess(Process process) async {
  try {
    await process.exitCode.timeout(const Duration(milliseconds: 50));
  } on TimeoutException {
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 2));
    }
  }
}

const _adapterFixture = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final mode = arguments.first;
  if (mode == 'blocked') {
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen((_) {});
    File(arguments[1]).writeAsStringSync('$pid');
    Timer.periodic(const Duration(seconds: 1), (_) {});
    await Completer<void>().future;
    return;
  }
  final request = jsonDecode(await stdin.transform(utf8.decoder).join());
  switch (mode) {
    case 'nonzero':
      stderr.writeln('fixture-private-error');
      exitCode = 7;
    case 'bad-json':
      stdout.write('fixture-private-output');
    case 'array':
      stdout.write('[]');
    case 'bad-shape':
      stdout.write('{"text":42}');
    case 'large':
      stdout.write('x' * (1024 * 1024 + 1));
    default:
      stdout.write(jsonEncode({'text': '${request['model']}:${request['context']}'}));
  }
}
''';
