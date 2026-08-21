import 'dart:convert';
import 'dart:io';

import 'public_update_validation.dart';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final envelope = await File(_required(options, 'envelope')).readAsBytes();
    final candidate = _readJsonObject(_required(options, 'android-candidate'));
    final iosCandidate = _readJsonObject(_required(options, 'ios-candidate'));
    final windowsCandidate = _readJsonObject(
      _required(options, 'windows-candidate'),
    );
    final windowsProductionReceipt = _readJsonObject(
      _required(options, 'windows-production-receipt'),
    );
    final receipt = await validatePublicUpdateContract(
      envelopeBytes: envelope,
      androidCandidate: candidate,
      iosCandidate: iosCandidate,
      windowsCandidate: windowsCandidate,
      windowsProductionReceipt: windowsProductionReceipt,
      expectedReleaseId: _required(options, 'release-id'),
      expectedRepository: _required(options, 'repository'),
      expectedSourceRunId: int.parse(_required(options, 'source-run-id')),
      expectedPublishRunId: int.parse(_required(options, 'publish-run-id')),
    );
    final output = File(_required(options, 'output'));
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
