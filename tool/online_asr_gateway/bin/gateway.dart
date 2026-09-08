import 'dart:convert';
import 'dart:io';

// 独立工具不属于应用 lib，保留可直接运行的相对导入。
// ignore: avoid_relative_lib_imports
import '../lib/gateway.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help')) {
    stdout.writeln(
      '''dart run tool/online_asr_gateway/bin/gateway.dart [--fixture]
默认只监听 127.0.0.1:8765，POST /v1/chat/completions。
MEETTRACE_GATEWAY_COMMAND: JSON argv 数组，例如 ["python","my_adapter.py"]。
MEETTRACE_GATEWAY_TOKEN: 可选的本机网关 Bearer 令牌。
MEETTRACE_GATEWAY_PORT: 可选端口，默认 8765。
--fixture: 仅协议演示，返回明显标记的假文本，不调用在线模型。
Ctrl+C 停止。私有协议适配及 TLS 部署责任见 docs/development/online_asr_protocols.md。''',
    );
    return;
  }
  if (arguments.any((argument) => argument != '--fixture')) {
    stderr.writeln('gateway.invalid_arguments；使用 --help 查看用法');
    exitCode = 64;
    return;
  }
  OnlineAsrGateway? gateway;
  try {
    final fixture = arguments.contains('--fixture');
    final commandValue = Platform.environment['MEETTRACE_GATEWAY_COMMAND'];
    final decoded = commandValue == null ? null : jsonDecode(commandValue);
    if (!fixture &&
        (decoded is! List<dynamic> ||
            decoded.isEmpty ||
            decoded.any((value) => value is! String || value.trim().isEmpty))) {
      stderr.writeln(
        'gateway.adapter_required；配置 MEETTRACE_GATEWAY_COMMAND，或显式使用 --fixture',
      );
      exitCode = 64;
      return;
    }
    final command = decoded is List<dynamic>
        ? decoded.cast<String>()
        : <String>[];
    final port = int.parse(
      Platform.environment['MEETTRACE_GATEWAY_PORT'] ?? '8765',
    );
    if (port < 1 || port > 65535) throw const FormatException();
    gateway = OnlineAsrGateway(
      bearerToken: Platform.environment['MEETTRACE_GATEWAY_TOKEN'],
      transcribe: fixture
          ? (model, wav, context) async => {
              'text': '[协议演示，无实际转录]',
              'model_version': 'fixture-only',
            }
          : (model, wav, context) => runAdapter(command, model, wav, context),
    );
    await gateway.start(port: port);
    stdout.writeln(
      'gateway.ready http://127.0.0.1:${gateway.port}/v1/chat/completions',
    );
    if (fixture) stderr.writeln('gateway.fixture_only：不能用于准确率评价或真实会议');
    await ProcessSignal.sigint.watch().first;
  } on Object {
    stderr.writeln('gateway.failed；检查非秘密配置和适配器，响应内容不会写入日志');
    exitCode = 1;
  } finally {
    await gateway?.close();
  }
}
