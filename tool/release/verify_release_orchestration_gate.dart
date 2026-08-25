import 'dart:convert';
import 'dart:io';

import 'release_orchestration_gate.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parse(arguments);
    final input = File(_required(options, 'input'));
    if (!await input.exists()) {
      throw FormatException('发布协调门禁不存在：${input.path}');
    }
    if (await input.length() > releaseOrchestrationGateMaximumBytes) {
      throw const FormatException('发布协调门禁超过 1 MiB 上限');
    }
    final receipt = verifyReleaseOrchestrationGate(
      await input.readAsString(),
      ReleaseOrchestrationGateRequest(
        releaseId: _required(options, 'release-id'),
        candidateCommitSha: _required(options, 'candidate-sha'),
        sourceRunId: int.parse(_required(options, 'source-run-id')),
        orchestrationRunId: int.parse(
          _required(options, 'orchestration-run-id'),
        ),
        buildNumber: int.parse(_required(options, 'build-number')),
        marketingVersion: _required(options, 'marketing-version'),
        testFlightExternalGroup: _required(
          options,
          'testflight-external-group',
        ),
        windowsArtifactName: _required(options, 'windows-artifact-name'),
        windowsPackageVersion: _required(options, 'windows-package-version'),
        windowsFlightId: _required(options, 'windows-flight-id'),
        testFlightPublicLink: Uri.parse(
          _required(options, 'testflight-public-link'),
        ),
      ),
    );
    final output = File(_required(options, 'output'));
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(receipt)}\n',
      flush: true,
    );
  } on Object catch (error) {
    stderr.writeln('Release orchestration gate verification failed: $error');
    exitCode = 1;
  }
}

Map<String, String> _parse(List<String> arguments) {
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length ||
        !arguments[index].startsWith('--') ||
        arguments[index + 1].startsWith('--')) {
      throw const FormatException('参数必须使用 --name value 格式');
    }
    final key = arguments[index].substring(2);
    if (result.containsKey(key)) {
      throw FormatException('参数重复：--$key');
    }
    result[key] = arguments[index + 1];
  }
  return result;
}

String _required(Map<String, String> options, String key) {
  final value = options[key];
  if (value == null || value.trim().isEmpty) {
    throw FormatException('缺少参数：--$key');
  }
  return value;
}
