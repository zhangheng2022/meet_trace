import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/updates/android_app_update_handler.dart';
import 'package:meettrace/data/services/updates/bounded_https_client.dart';
import 'package:meettrace/data/services/updates/signed_app_update_manifest_parser.dart';
import 'package:meettrace/domain/models/app_update.dart';

void main() {
  late Directory storage;
  late HttpServer server;
  late BoundedHttpsClient http;
  late _Installer installer;

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('android-update-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http = BoundedHttpsClient(allowInsecureLocalhostForTesting: true);
    installer = _Installer();
  });

  tearDown(() async {
    http.close();
    await server.close(force: true);
    await storage.delete(recursive: true);
  });

  test('下载后复核长度、哈希、包名、版本和签名，安装前再次复核', () async {
    final apk = <int>[1, 3, 3, 7];
    server.listen((request) async {
      request.response
        ..contentLength = apk.length
        ..add(apk);
      await request.response.close();
    });
    final update = _update(
      uri: _uri(server),
      bytes: apk.length,
      digest: sha256.convert(apk).toString(),
    );
    final handler = AndroidAppUpdateHandler(
      http: http,
      installer: installer,
      storageRoot: storage.path,
      getFreeBytes: () async => 1024 * 1024 * 1024,
    );
    final obsolete = File('${storage.path}/app_updates/obsolete.apk');
    await obsolete.parent.create(recursive: true);
    await obsolete.writeAsBytes(<int>[9]);

    await handler.stage(update);
    await handler.requestInstall(update);

    expect(installer.inspectCount, 2);
    expect(installer.installedPath, endsWith('.apk'));
    expect(File(installer.installedPath!).parent.path, contains('app_updates'));
    expect(await obsolete.exists(), isFalse);
  });

  test('使用候选清单记录的 split APK 实际 versionCode 校验安装包', () async {
    final apk = <int>[2, 0, 0, 1];
    server.listen((request) async {
      request.response
        ..contentLength = apk.length
        ..add(apk);
      await request.response.close();
    });
    installer.versionCode = 2001;
    final update = _update(
      uri: _uri(server),
      bytes: apk.length,
      digest: sha256.convert(apk).toString(),
      buildNumber: 2001,
      versionCode: 2001,
    );
    final handler = AndroidAppUpdateHandler(
      http: http,
      installer: installer,
      storageRoot: storage.path,
      getFreeBytes: () async => 1024 * 1024 * 1024,
    );

    await handler.stage(update);
    await handler.requestInstall(update);

    expect(installer.installedPath, endsWith('.apk'));
  });

  test('拒绝与候选清单实际 versionCode 不一致的 split APK', () async {
    final apk = <int>[2, 0, 0, 2];
    server.listen((request) async {
      request.response
        ..contentLength = apk.length
        ..add(apk);
      await request.response.close();
    });
    installer.versionCode = 2002;
    final update = _update(
      uri: _uri(server),
      bytes: apk.length,
      digest: sha256.convert(apk).toString(),
      buildNumber: 2001,
      versionCode: 2001,
    );
    final handler = AndroidAppUpdateHandler(
      http: http,
      installer: installer,
      storageRoot: storage.path,
      getFreeBytes: () async => 1024 * 1024 * 1024,
    );

    await expectLater(handler.stage(update), throwsFormatException);
  });

  test('拒绝哈希或 APK 元数据不匹配并清理 part 文件', () async {
    final apk = <int>[1, 2, 3];
    server.listen((request) async {
      request.response.add(apk);
      await request.response.close();
    });
    installer.packageName = 'attacker.example';
    final update = _update(
      uri: _uri(server),
      bytes: apk.length,
      digest: sha256.convert(apk).toString(),
    );
    final handler = AndroidAppUpdateHandler(
      http: http,
      installer: installer,
      storageRoot: storage.path,
      getFreeBytes: () async => 1024 * 1024 * 1024,
    );

    await expectLater(handler.stage(update), throwsFormatException);
    final updates = Directory('${storage.path}/app_updates');
    expect(
      await updates
          .list()
          .where((entry) => entry.path.endsWith('.part'))
          .toList(),
      isEmpty,
    );
  });

  test('空间不足时不发起下载并保留录音最低空间', () async {
    var requests = 0;
    server.listen((request) async {
      requests += 1;
      await request.response.close();
    });
    final update = _update(
      uri: _uri(server),
      bytes: 4,
      digest: sha256.convert(<int>[1, 3, 3, 7]).toString(),
    );
    final handler = AndroidAppUpdateHandler(
      http: http,
      installer: installer,
      storageRoot: storage.path,
      getFreeBytes: () async => 128 * 1024 * 1024,
    );

    await expectLater(
      handler.stage(update),
      throwsA(isA<FileSystemException>()),
    );
    expect(requests, 0);
  });
}

VerifiedPlatformAppUpdate _update({
  required Uri uri,
  required int bytes,
  required String digest,
  int buildNumber = 11,
  int? versionCode,
}) => VerifiedPlatformAppUpdate(
  candidate: AppUpdateCandidate(
    releaseId: 'v1.1.0-alpha.1',
    versionName: '1.1.0',
    buildNumber: buildNumber,
    dataGeneration: 3,
    status: AppUpdateCandidateStatus.publicApproved,
    sourceCommitSha: '0123456789abcdef0123456789abcdef01234567',
    artifactId: 'android-11',
    approvedAt: DateTime.utc(2026, 8, 20),
  ),
  artifact: VerifiedPlatformUpdateArtifact(
    platform: AppUpdatePlatform.android,
    installUri: uri,
    versionCode: versionCode,
    bytes: bytes,
    sha256: digest,
    packageIdentity: 'com.meettrace.app',
    signingIdentitySha256: 'a' * 64,
  ),
);

Uri _uri(HttpServer server) =>
    Uri.parse('http://${server.address.address}:${server.port}/update.apk');

final class _Installer implements AndroidApkInstaller {
  String packageName = 'com.meettrace.app';
  int versionCode = 11;
  int inspectCount = 0;
  String? installedPath;

  @override
  Future<AndroidApkMetadata> inspect(String apkPath) async {
    inspectCount += 1;
    return AndroidApkMetadata(
      packageName: packageName,
      versionName: '1.1.0',
      versionCode: versionCode,
      signingCertificateSha256: <String>['a' * 64],
    );
  }

  @override
  Future<void> requestInstall(String apkPath) async {
    installedPath = apkPath;
  }
}
