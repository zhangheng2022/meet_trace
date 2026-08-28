import 'dart:convert';
import 'dart:io';

import 'cli_options.dart';
import 'microsoft_store_submission.dart';
import 'microsoft_store_status.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = parseCliOptions(arguments);
    final input = File(requireCliOption(options, 'input'));
    final output = File(requireCliOption(options, 'output'));
    if (!await input.exists()) {
      throw FormatException('Microsoft Store submission 响应不存在：${input.path}');
    }
    if (await input.length() > microsoftStoreSubmissionMaximumResponseBytes) {
      throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
    }
    final production = switch (requireCliOption(options, 'production')) {
      'true' => true,
      'false' => false,
      _ => throw const FormatException('--production 必须是 true 或 false'),
    };
    final status = classifyMicrosoftStoreSubmission(
      await input.readAsString(),
      expectedArtifactName: requireCliOption(options, 'expected-artifact-name'),
      expectedPackageVersion: requireCliOption(options, 'expected-version'),
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
