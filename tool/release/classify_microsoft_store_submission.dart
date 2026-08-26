import 'dart:convert';
import 'dart:io';

import 'microsoft_store_submission.dart';
import 'microsoft_store_status.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final input = File(_required(options, 'input'));
    final output = File(_required(options, 'output'));
    if (!await input.exists()) {
      throw FormatException('Microsoft Store submission 响应不存在：${input.path}');
    }
    if (await input.length() > microsoftStoreSubmissionMaximumResponseBytes) {
      throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
    }
    final production = switch (_required(options, 'production')) {
      'true' => true,
      'false' => false,
      _ => throw const FormatException('--production 必须是 true 或 false'),
    };
    final status = classifyMicrosoftStoreSubmission(
      await input.readAsString(),
      expectedArtifactName: _required(options, 'expected-artifact-name'),
      expectedPackageVersion: _required(options, 'expected-version'),
      production: production,
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(status)}\n',
      flush: true,
    );
  } on Object catch (error) {
    stderr.writeln('Microsoft Store submission 状态分类失败：$error');
    exitCode = 64;
  }
}

Map<String, String> _parseOptions(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('参数必须使用 --name value');
  }
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final name = arguments[index];
    if (!name.startsWith('--') || name.length == 2) {
      throw FormatException('无效参数：$name');
    }
    final key = name.substring(2);
    if (result.containsKey(key)) {
      throw FormatException('重复参数：$name');
    }
    result[key] = arguments[index + 1];
  }
  return result;
}

String _required(Map<String, String> options, String name) {
  final value = options[name];
  if (value == null || value.isEmpty) {
    throw FormatException('缺少 --$name');
  }
  return value;
}
