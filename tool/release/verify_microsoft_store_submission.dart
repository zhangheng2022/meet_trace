import 'dart:convert';
import 'dart:io';

import 'microsoft_store_submission.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final input = File(_required(options, 'input'));
    final output = File(_required(options, 'output'));
    if (await input.length() > microsoftStoreSubmissionMaximumResponseBytes) {
      throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
    }
    final source = await input.readAsString();
    final flightId = options['flight-id'];
    final receipt = flightId == null
        ? verifyMicrosoftStoreSubmission(
            source,
            MicrosoftStoreSubmissionVerificationRequest(
              productId: _required(options, 'product-id'),
              expectedPackageVersion: _required(options, 'expected-version'),
              expectedArtifactName: _required(
                options,
                'expected-artifact-name',
              ),
              releaseId: _required(options, 'release-id'),
              candidateCommitSha: _required(options, 'candidate-sha'),
              sourceRunId: int.parse(_required(options, 'source-run-id')),
              verifiedAt: DateTime.parse(_required(options, 'verified-at')),
            ),
          )
        : verifyMicrosoftStoreFlightSubmission(
            source,
            MicrosoftStoreFlightVerificationRequest(
              productId: _required(options, 'product-id'),
              flightId: flightId,
              expectedPackageVersion: _required(options, 'expected-version'),
              expectedArtifactName: _required(
                options,
                'expected-artifact-name',
              ),
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
    stderr.writeln('Microsoft Store 正式 submission 验证失败：$error');
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
