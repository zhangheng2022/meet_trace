import 'dart:convert';
import 'dart:io';

import 'cli_options.dart';
import 'public_update_validation.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = parseCliOptions(arguments);
    final envelope = await File(requireCliOption(options, 'envelope'))
        .readAsBytes();
    final candidate = _readJsonObject(
      requireCliOption(options, 'android-candidate'),
    );
    final iosCandidate = _readJsonObject(
      requireCliOption(options, 'ios-candidate'),
    );
    final windowsCandidate = _readJsonObject(
      requireCliOption(options, 'windows-candidate'),
    );
    final windowsProductionReceipt = _readJsonObject(
      requireCliOption(options, 'windows-production-receipt'),
    );
    final receipt = await validatePublicUpdateContract(
      envelopeBytes: envelope,
      androidCandidate: candidate,
      iosCandidate: iosCandidate,
      windowsCandidate: windowsCandidate,
      windowsProductionReceipt: windowsProductionReceipt,
      expectedReleaseId: requireCliOption(options, 'release-id'),
      expectedRepository: requireCliOption(options, 'repository'),
      expectedSourceRunId: int.parse(
        requireCliOption(options, 'source-run-id'),
      ),
      expectedPublishRunId: int.parse(
        requireCliOption(options, 'publish-run-id'),
      ),
    );
    final output = File(requireCliOption(options, 'output'));
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(receipt.toJson())}\n',
      flush: true,
    );
  } catch (error) {
    stderr.writeln('公开更新合同验证失败：$error');
    exitCode = 64;
  }
}

Map<String, Object?> _readJsonObject(String path) {
  final bytes = File(path).readAsBytesSync();
  final start =
      bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf
      ? 3
      : 0;
  return Map<String, Object?>.from(
    jsonDecode(utf8.decode(bytes.sublist(start))) as Map,
  );
}
