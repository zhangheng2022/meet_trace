import 'dart:convert';
import 'dart:io';

import 'package:meettrace/data/services/updates/app_update_signing_identity.dart';

import 'app_update_manifest.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
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
      status: _required(options, 'status'),
      releaseId: _required(options, 'release-id'),
      versionName: _required(options, 'version-name'),
      buildNumber: int.parse(_required(options, 'build-number')),
      dataGeneration: int.parse(_required(options, 'data-generation')),
      sourceCommitSha: _required(options, 'source-sha'),
      approvedAt: DateTime.parse(_required(options, 'approved-at')).toUtc(),
      repository: _required(options, 'repository'),
      androidCandidate: jsonDecode(
        await File(_required(options, 'android-candidate')).readAsString(),
      ) as Map<String, Object?>,
      testFlightUri: Uri.parse(testFlight),
      previousEnvelope: previousPath == null
          ? null
          : await File(previousPath).readAsBytes(),
    );
    final output = File(_required(options, 'output'));
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
    if (result.containsKey(name.substring(2))) {
      throw FormatException('重复参数：$name');
    }
    result[name.substring(2)] = arguments[index + 1];
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
