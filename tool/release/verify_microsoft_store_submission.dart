import 'dart:convert';
import 'dart:io';

import 'cli_options.dart';
import 'microsoft_store_submission.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = parseCliOptions(arguments);
    final input = File(requireCliOption(options, 'input'));
    final output = File(requireCliOption(options, 'output'));
    if (await input.length() > microsoftStoreSubmissionMaximumResponseBytes) {
      throw const FormatException('Microsoft Store submission 响应超过 2 MiB 上限');
    }
    final source = await input.readAsString();
    final flightId = options['flight-id'];
    final receipt = flightId == null
        ? verifyMicrosoftStoreSubmission(
            source,
            MicrosoftStoreSubmissionVerificationRequest(
              productId: requireCliOption(options, 'product-id'),
              expectedPackageVersion: requireCliOption(
                options,
                'expected-version',
              ),
              expectedArtifactName: requireCliOption(
                options,
                'expected-artifact-name',
              ),
              releaseId: requireCliOption(options, 'release-id'),
              candidateCommitSha: requireCliOption(options, 'candidate-sha'),
              sourceRunId: int.parse(
                requireCliOption(options, 'source-run-id'),
              ),
              verifiedAt: DateTime.parse(
                requireCliOption(options, 'verified-at'),
              ),
            ),
          )
        : verifyMicrosoftStoreFlightSubmission(
            source,
            MicrosoftStoreFlightVerificationRequest(
              productId: requireCliOption(options, 'product-id'),
              flightId: flightId,
              expectedPackageVersion: requireCliOption(
                options,
                'expected-version',
              ),
              expectedArtifactName: requireCliOption(
                options,
                'expected-artifact-name',
              ),
              releaseId: requireCliOption(options, 'release-id'),
              candidateCommitSha: requireCliOption(options, 'candidate-sha'),
              sourceRunId: int.parse(
                requireCliOption(options, 'source-run-id'),
              ),
              verifiedAt: DateTime.parse(
                requireCliOption(options, 'verified-at'),
              ),
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
