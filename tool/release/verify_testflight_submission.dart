import 'dart:convert';
import 'dart:io';

import 'testflight_submission.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final input = File(_required(options, 'input'));
    final output = File(_required(options, 'output'));
    if (await input.length() > testFlightStatusMaximumResponseBytes) {
      throw const FormatException('TestFlight 状态响应超过 512 KiB 上限');
    }
    final receipt = verifyTestFlightStatus(
      await input.readAsString(),
      TestFlightVerificationRequest(
        bundleId: _required(options, 'bundle-id'),
        marketingVersion: _required(options, 'marketing-version'),
        buildNumber: int.parse(_required(options, 'build-number')),
        externalGroup: _required(options, 'external-group'),
        publicLink: Uri.parse(_required(options, 'public-link')),
        releaseId: _required(options, 'release-id'),
        candidateCommitSha: _required(options, 'candidate-sha'),
        sourceRunId: int.parse(_required(options, 'source-run-id')),
        verifiedAt: DateTime.parse(_required(options, 'verified-at')),
      ),
    );
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(receipt)}\n',
      flush: true,
    );
  } catch (error) {
    stderr.writeln('TestFlight 外测状态验证失败：$error');
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
