import 'dart:convert';
import 'dart:io';

import 'cli_options.dart';
import 'testflight_submission.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = parseCliOptions(arguments);
    final input = File(requireCliOption(options, 'input'));
    final output = File(requireCliOption(options, 'output'));
    if (await input.length() > testFlightStatusMaximumResponseBytes) {
      throw const FormatException('TestFlight 状态响应超过 512 KiB 上限');
    }
    final receipt = verifyTestFlightStatus(
      await input.readAsString(),
      TestFlightVerificationRequest(
        bundleId: requireCliOption(options, 'bundle-id'),
        marketingVersion: requireCliOption(options, 'marketing-version'),
        buildNumber: int.parse(requireCliOption(options, 'build-number')),
        externalGroup: requireCliOption(options, 'external-group'),
        publicLink: Uri.parse(requireCliOption(options, 'public-link')),
        releaseId: requireCliOption(options, 'release-id'),
        candidateCommitSha: requireCliOption(options, 'candidate-sha'),
        sourceRunId: int.parse(requireCliOption(options, 'source-run-id')),
        verifiedAt: DateTime.parse(requireCliOption(options, 'verified-at')),
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
