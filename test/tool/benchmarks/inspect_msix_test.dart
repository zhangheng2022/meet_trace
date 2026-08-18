import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

const _publisher = 'CN=MeetTrace Development';
const _publisherDisplayName = 'MeetTrace Development';
const _version = '1.0.0.1';

const _manifest =
    '''<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
 xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
 xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
 xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
 IgnorableNamespaces="uap uap10 rescap">
 <Identity Name="com.meettrace.app" Publisher="$_publisher" Version="$_version" ProcessorArchitecture="x64" />
 <Properties><PublisherDisplayName>$_publisherDisplayName</PublisherDisplayName></Properties>
 <Dependencies><TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19045.0" MaxVersionTested="10.0.26100.0" /></Dependencies>
 <Applications><Application Id="MeetTrace" Executable="meettrace.exe" uap10:RuntimeBehavior="packagedClassicApp" uap10:TrustLevel="mediumIL" /></Applications>
 <Capabilities><Capability Name="internetClient" /><rescap:Capability Name="runFullTrust" /><DeviceCapability Name="microphone" /></Capabilities>
</Package>''';

const _requiredEntries = <String>{
  'meettrace.exe',
  'flutter_windows.dll',
  'data/app.so',
  'data/icudtl.dat',
  'data/flutter_assets/NOTICES.Z',
  'data/flutter_assets/assets/models/manifest.json',
  'data/flutter_assets/assets/models/silero-vad-manifest.json',
  'data/flutter_assets/assets/models/speaker-diarization-manifest.json',
  'data/flutter_assets/assets/licenses/sense-voice-NOTICE.txt',
  'data/flutter_assets/assets/licenses/sense-voice-LICENSE.txt',
  'data/flutter_assets/assets/licenses/silero-vad-NOTICE.txt',
  'data/flutter_assets/assets/licenses/silero-vad-LICENSE.txt',
  'data/flutter_assets/assets/licenses/pyannote-segmentation-NOTICE.txt',
  'data/flutter_assets/assets/licenses/pyannote-segmentation-LICENSE.txt',
  'data/flutter_assets/assets/licenses/3d-speaker-NOTICE.txt',
  'data/flutter_assets/assets/licenses/3d-speaker-LICENSE.txt',
  'Assets/StoreLogo.png',
  'Assets/Square44x44Logo.png',
  'Assets/Square150x150Logo.png',
};

Future<({ProcessResult result, Map<String, Object?>? report})> _inspect(
  Set<String> extraEntries, {
  bool requireSignature = false,
  String expectedPublisherDisplayName = _publisherDisplayName,
}) async {
  final temporaryDirectory = await Directory.systemTemp.createTemp(
    'meettrace-msix-inspection-',
  );
  addTearDown(() => temporaryDirectory.delete(recursive: true));

  final archive = Archive()
    ..addFile(ArchiveFile.string('AppxManifest.xml', _manifest));
  for (final path in {..._requiredEntries, ...extraEntries}) {
    archive.addFile(ArchiveFile.string(path, 'test'));
  }
  final msix = File('${temporaryDirectory.path}/fixture.msix');
  await msix.writeAsBytes(ZipEncoder().encode(archive));
  final reportFile = File('${temporaryDirectory.path}/report.json');
  final result = await Process.run('pwsh', <String>[
    '-NoLogo',
    '-NoProfile',
    '-File',
    'tool/benchmarks/inspect_msix.ps1',
    '-MsixPath',
    msix.path,
    '-ExpectedPublisher',
    _publisher,
    '-ExpectedVersion',
    _version,
    '-ExpectedPublisherDisplayName',
    expectedPublisherDisplayName,
    '-ReportPath',
    reportFile.path,
    if (requireSignature) '-RequireSignature',
  ]);
  final report = reportFile.existsSync()
      ? jsonDecode(await reportFile.readAsString()) as Map<String, Object?>
      : null;
  return (result: result, report: report);
}

void main() {
  test('MSIX 审计接受固定身份、x64 和完整运行资产', () async {
    final inspected = await _inspect(const {});

    expect(
      inspected.result.exitCode,
      0,
      reason:
          'stdout: ${inspected.result.stdout}\nstderr: ${inspected.result.stderr}',
    );
    expect(inspected.report?['missingEntries'], isEmpty);
    expect(inspected.report?['forbiddenWeights'], isEmpty);
    expect(inspected.report?['forbiddenUserData'], isEmpty);
    expect(inspected.report?['forbiddenCredentials'], isEmpty);
    expect(inspected.report?['hasSignature'], isFalse);
    expect(inspected.report?['authenticodeStatus'], 'NotChecked');
    expect(inspected.report?['publisherDisplayName'], _publisherDisplayName);
  });

  test('MSIX 审计拒绝 PublisherDisplayName 不匹配', () async {
    final inspected = await _inspect(
      const {},
      expectedPublisherDisplayName: 'Attacker',
    );

    expect(inspected.result.exitCode, isNot(0));
    final checks = inspected.report!['checks']! as Map<String, Object?>;
    expect(checks['publisherDisplayNameMatches'], isFalse);
  });

  test('MSIX 审计拒绝模型权重、用户录音和签名私钥', () async {
    final inspected = await _inspect(const {
      'data/flutter_assets/model.onnx',
      'data/meeting.wav',
      'secrets/release.pfx',
    });

    expect(inspected.result.exitCode, isNot(0));
    expect(inspected.report?['forbiddenWeights'], isNotEmpty);
    expect(inspected.report?['forbiddenUserData'], isNotEmpty);
    expect(inspected.report?['forbiddenCredentials'], isNotEmpty);
  });

  test('MSIX 正式审计拒绝只有签名条目但没有有效 Authenticode 的包', () async {
    final inspected = await _inspect(const {
      'AppxSignature.p7x',
    }, requireSignature: true);

    expect(inspected.result.exitCode, isNot(0));
    expect(inspected.report?['hasSignature'], isTrue);
    expect(inspected.report?['authenticodeStatus'], isNot('Valid'));
  });
}
