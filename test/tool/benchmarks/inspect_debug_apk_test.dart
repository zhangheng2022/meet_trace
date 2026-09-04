import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('APK 检查脚本可跨平台读取 ZIP 条目', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'meettrace-apk-inspection-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final archive = Archive();
    for (final path in <String>{
      'assets/flutter_assets/assets/models/manifest.json',
      'assets/flutter_assets/assets/models/silero-vad-manifest.json',
      'assets/flutter_assets/assets/models/speaker-diarization-manifest.json',
      'assets/flutter_assets/assets/licenses/sense-voice-NOTICE.txt',
      'assets/flutter_assets/assets/licenses/sense-voice-LICENSE.txt',
      'assets/flutter_assets/assets/licenses/silero-vad-NOTICE.txt',
      'assets/flutter_assets/assets/licenses/silero-vad-LICENSE.txt',
      'assets/flutter_assets/assets/licenses/pyannote-segmentation-NOTICE.txt',
      'assets/flutter_assets/assets/licenses/pyannote-segmentation-LICENSE.txt',
      'assets/flutter_assets/assets/licenses/3d-speaker-NOTICE.txt',
      'assets/flutter_assets/assets/licenses/3d-speaker-LICENSE.txt',
      'assets/flutter_assets/NOTICES.Z',
      'lib/x86_64/libapp.so',
    }) {
      archive.addFile(ArchiveFile.string(path, 'test'));
    }

    final apk = File('${temporaryDirectory.path}/fixture.apk');
    await apk.writeAsBytes(ZipEncoder().encode(archive));
    final report = File('${temporaryDirectory.path}/report.json');
    final result = await Process.run('pwsh', <String>[
      '-NoLogo',
      '-NoProfile',
      '-File',
      'tool/benchmarks/inspect_debug_apk.ps1',
      '-ApkPath',
      apk.path,
      '-ReportPath',
      report.path,
      '-RequiredAbi',
      'x86_64',
    ]);

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    final decoded =
        jsonDecode(await report.readAsString()) as Map<String, Object?>;
    expect(decoded['abis'], <Object?>['x86_64']);
    expect(decoded['hasArm64'], isFalse);
    expect(decoded['hasRequiredAbi'], isTrue);
    expect(decoded['hasFlutterNotices'], isTrue);
    expect(decoded['missingAssets'], isEmpty);
    expect(decoded['forbiddenWeights'], isEmpty);
    expect(decoded['forbiddenUserData'], isEmpty);

    final missingDefaultAbi = await Process.run('pwsh', <String>[
      '-NoLogo',
      '-NoProfile',
      '-File',
      'tool/benchmarks/inspect_debug_apk.ps1',
      '-ApkPath',
      apk.path,
      '-ReportPath',
      report.path,
    ]);
    expect(missingDefaultAbi.exitCode, isNot(0));

    final emptyRequiredAbi = await Process.run('pwsh', <String>[
      '-NoLogo',
      '-NoProfile',
      '-File',
      'tool/benchmarks/inspect_debug_apk.ps1',
      '-ApkPath',
      apk.path,
      '-RequiredAbi',
      ' ',
    ]);
    expect(emptyRequiredAbi.exitCode, isNot(0));
  });
}
