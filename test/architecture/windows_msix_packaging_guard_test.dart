import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows MSIX 打包守卫', () {
    test('manifest 固定 x64、Windows 10 22H2、麦克风与全信任边界', () async {
      final manifest = await File(
        'windows/packaging/msix/AppxManifest.xml.template',
      ).readAsString();

      expect(manifest, contains('Name="{{IDENTITY_NAME}}"'));
      expect(manifest, contains('Publisher="{{PUBLISHER}}"'));
      expect(manifest, contains('Version="{{VERSION}}"'));
      expect(manifest, contains('ProcessorArchitecture="x64"'));
      expect(manifest, contains('MinVersion="10.0.19045.0"'));
      expect(manifest, contains('Executable="meettrace.exe"'));
      expect(manifest, contains('uap10:RuntimeBehavior="packagedClassicApp"'));
      expect(manifest, contains('uap10:TrustLevel="mediumIL"'));
      expect(manifest, contains('DeviceCapability Name="microphone"'));
      expect(manifest, contains('rescap:Capability Name="runFullTrust"'));
      expect(manifest, isNot(contains('broadFileSystemAccess')));
    });

    test('打包脚本区分开发探针和正式 Publisher 且不创建证书', () async {
      final script = await File('tool/windows/package_msix.ps1').readAsString();

      expect(script, contains(r'[switch]$DevelopmentProbe'));
      expect(script, contains("'CN=MeetTrace Development'"));
      expect(
        script,
        contains(
          "Publisher -match '(?i)(development|example|contoso|localhost|test)'",
        ),
      );
      expect(script, contains(r'& $makeAppx pack /o /v /h SHA256'));
      expect(script, contains(r'signed = $false'));
      expect(script, contains(r'\s*(?:#.*)?$'));
      expect(script, isNot(contains('New-SelfSignedCertificate')));
      expect(script, isNot(contains('signtool sign')));
      expect(script, isNot(contains('.pfx')));
    });

    test('Windows 可执行文件元数据不再使用模板公司身份', () async {
      final resources = await File('windows/runner/Runner.rc').readAsString();

      expect(resources, contains('VALUE "CompanyName", "MeetTrace"'));
      expect(resources, contains('VALUE "ProductName", "MeetTrace"'));
      expect(resources, isNot(contains('com.example')));
    });

    test('正式包审计验证 Authenticode 和签名证书 Subject', () async {
      final script = await File('tool/benchmarks/inspect_msix.ps1')
          .readAsString();

      expect(script, contains('Get-AuthenticodeSignature'));
      expect(script, contains(r"$authenticodeStatus -ceq 'Valid'"));
      expect(script, contains(r'$signerSubject -ceq $ExpectedPublisher'));
    });

    test('CMake 始终把安装阶段固定到 Flutter bundle', () async {
      final cmake = await File('windows/CMakeLists.txt').readAsString();

      expect(
        cmake,
        contains(
          r'set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)',
        ),
      );
      expect(
        cmake,
        isNot(contains('if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)')),
      );
    });
  });
}
