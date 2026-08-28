import 'dart:convert';
import 'dart:io';

import 'package:meettrace/data/services/updates/app_update_signing_identity.dart';

import 'app_update_manifest.dart';
import 'cli_options.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = parseCliOptions(arguments);
    final seedText =
        Platform.environment['APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64'];
    if (seedText == null || seedText.isEmpty) {
      throw StateError('缺少 APP_UPDATE_SIGNING_PRIVATE_KEY_BASE64');
    }
    final previousPath = options['previous'];
    final testFlight =
        options['testflight-url'] ?? 'https://testflight.apple.com/';
    final request = AppUpdateManifestSigningRequest(
      privateSeed: base64Decode(seedText),
      expectedPublicKey: base64Decode(appUpdateSigningPublicKeyBase64),
      keyId: appUpdateSigningKeyId,
      status: requireCliOption(options, 'status'),
      releaseId: requireCliOption(options, 'release-id'),
      versionName: requireCliOption(options, 'version-name'),
      buildNumber: int.parse(requireCliOption(options, 'build-number')),
      dataGeneration: int.parse(requireCliOption(options, 'data-generation')),
      sourceCommitSha: requireCliOption(options, 'source-sha'),
      approvedAt: DateTime.parse(requireCliOption(options, 'approved-at'))
          .toUtc(),
      repository: requireCliOption(options, 'repository'),
      androidCandidate: jsonDecode(
        await File(requireCliOption(options, 'android-candidate'))
            .readAsString(),
      ) as Map<String, Object?>,
      testFlightUri: Uri.parse(testFlight),
      previousEnvelope: previousPath == null
          ? null
          : await File(previousPath).readAsBytes(),
    );
    final output = File(requireCliOption(options, 'output'));
    await output.parent.create(recursive: true);
    await output.writeAsBytes(
      await createSignedAppUpdateManifest(request),
      flush: true,
    );
  } catch (error) {
    stderr.writeln('无法创建签名更新 Manifest：$error');
    exitCode = 64;
  }
}
