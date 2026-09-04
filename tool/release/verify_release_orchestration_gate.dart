import 'dart:convert';
import 'dart:io';

import 'cli_options.dart';
import 'release_orchestration_gate.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = parseCliOptions(arguments);
    final input = File(requireCliOption(options, 'input'));
    if (!await input.exists()) {
      throw FormatException('发布协调门禁不存在：${input.path}');
    }
    if (await input.length() > releaseOrchestrationGateMaximumBytes) {
      throw const FormatException('发布协调门禁超过 1 MiB 上限');
    }
    final receipt = verifyReleaseOrchestrationGate(
      await input.readAsString(),
      ReleaseOrchestrationGateRequest(
        releaseId: requireCliOption(options, 'release-id'),
        candidateCommitSha: requireCliOption(options, 'candidate-sha'),
        sourceRunId: int.parse(requireCliOption(options, 'source-run-id')),
        orchestrationRunId: int.parse(
          requireCliOption(options, 'orchestration-run-id'),
        ),
        buildNumber: int.parse(requireCliOption(options, 'build-number')),
        marketingVersion: requireCliOption(options, 'marketing-version'),
        testFlightExternalGroup: requireCliOption(
          options,
          'testflight-external-group',
        ),
        androidCandidateManifestSha256: requireCliOption(
          options,
          'android-candidate-manifest-sha256',
        ),
        windowsArtifactName: requireCliOption(options, 'windows-artifact-name'),
        windowsPackageVersion: requireCliOption(
          options,
          'windows-package-version',
        ),
        windowsFlightId: requireCliOption(options, 'windows-flight-id'),
        testFlightPublicLink: Uri.parse(
          requireCliOption(options, 'testflight-public-link'),
        ),
      ),
    );
    final output = File(requireCliOption(options, 'output'));
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
