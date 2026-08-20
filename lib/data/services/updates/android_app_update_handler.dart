import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../domain/models/meeting_readiness.dart';
import '../storage/device_free_space_service.dart';
import 'bounded_https_client.dart';
import 'signed_app_update_manifest_parser.dart';
import 'signed_manifest_app_update_port.dart';

final class AndroidApkMetadata {
  const AndroidApkMetadata({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.signingCertificateSha256,
  });

  final String packageName;
  final String versionName;
  final int versionCode;
  final List<String> signingCertificateSha256;
}

abstract interface class AndroidApkInstaller {
  Future<AndroidApkMetadata> inspect(String apkPath);

  Future<void> requestInstall(String apkPath);
}

final class MethodChannelAndroidApkInstaller implements AndroidApkInstaller {
  const MethodChannelAndroidApkInstaller({
    this.channel = const MethodChannel('com.meettrace.app/app_update'),
  });

  final MethodChannel channel;

  @override
  Future<AndroidApkMetadata> inspect(String apkPath) async {
    final result = await channel.invokeMapMethod<String, Object?>(
      'inspectApk',
      <String, Object?>{'path': apkPath},
    );
    if (result == null) {
      throw const FormatException('Android 未返回 APK 元数据');
    }
    final packageName = result['packageName'];
    final versionName = result['versionName'];
    final versionCode = result['versionCode'];
    final certificates = result['signingCertificateSha256'];
    if (packageName is! String ||
        packageName.isEmpty ||
        versionName is! String ||
        versionName.isEmpty ||
        versionCode is! int ||
        versionCode <= 0 ||
        certificates is! List<Object?> ||
        certificates.isEmpty ||
        certificates.any((value) => value is! String)) {
      throw const FormatException('Android APK 元数据格式无效');
    }
    return AndroidApkMetadata(
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      signingCertificateSha256: List<String>.unmodifiable(
        certificates.cast<String>().map(_normalizeSha256),
      ),
    );
  }

  @override
  Future<void> requestInstall(String apkPath) => channel.invokeMethod<void>(
    'requestInstall',
    <String, Object?>{'path': apkPath},
  );
}

final class AndroidAppUpdateHandler implements PlatformAppUpdateHandler {
  AndroidAppUpdateHandler({
    required this.http,
    required this.installer,
    required this.storageRoot,
    Future<int> Function()? getFreeBytes,
  }) : getFreeBytes =
           getFreeBytes ?? const DeviceFreeSpaceService().getFreeBytes;

  final BoundedHttpsClient http;
  final AndroidApkInstaller installer;
  final String storageRoot;
  final Future<int> Function() getFreeBytes;
  final Map<String, File> _stagedByArtifactId = {};

  @override
  Future<void> stage(VerifiedPlatformAppUpdate update) async {
    final artifact = update.artifact;
    final expectedBytes = artifact.bytes;
    final expectedSha256 = artifact.sha256;
    final expectedCertificate = artifact.signingIdentitySha256;
    if (artifact.platform != AppUpdatePlatform.android ||
        expectedBytes == null ||
        expectedSha256 == null ||
        artifact.packageIdentity == null ||
        expectedCertificate == null) {
      throw StateError('Android 更新资产缺少强校验信息');
    }
    final updatesDirectory = Directory(p.join(storageRoot, 'app_updates'));
    final finalFile = File(
      p.join(updatesDirectory.path, '$expectedSha256.apk'),
    );
    final temporaryFile = File('${finalFile.path}.part');
    await _removeObsoleteDownloads(
      updatesDirectory,
      retainedPaths: <String>{finalFile.path, temporaryFile.path},
    );
    if (await _isValid(finalFile, update)) {
      _stagedByArtifactId[update.candidate.artifactId] = finalFile;
      return;
    }
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }
    final freeBytes = await getFreeBytes();
    if (freeBytes - expectedBytes < minimumRecordingFreeBytes) {
      throw const FileSystemException('剩余空间不足，更新下载必须保留录音空间');
    }
    try {
      await http.download(
        uri: artifact.installUri,
        destination: temporaryFile,
        expectedBytes: expectedBytes,
      );
      if (!await _isValid(temporaryFile, update)) {
        throw const FormatException('Android APK 身份或签名校验失败');
      }
      await temporaryFile.rename(finalFile.path);
      _stagedByArtifactId[update.candidate.artifactId] = finalFile;
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  @override
  Future<void> requestInstall(VerifiedPlatformAppUpdate update) async {
    final file = _stagedByArtifactId[update.candidate.artifactId];
    if (file == null || !await _isValid(file, update)) {
      throw StateError('Android 更新安装前复核失败');
    }
    await installer.requestInstall(file.path);
  }

  Future<bool> _isValid(File file, VerifiedPlatformAppUpdate update) async {
    if (!await file.exists()) {
      return false;
    }
    final artifact = update.artifact;
    if (await file.length() != artifact.bytes) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != artifact.sha256) {
      return false;
    }
    try {
      final metadata = await installer.inspect(file.path);
      return metadata.packageName == artifact.packageIdentity &&
          metadata.versionName == update.candidate.versionName &&
          metadata.versionCode == update.candidate.buildNumber &&
          metadata.signingCertificateSha256.contains(
            _normalizeSha256(artifact.signingIdentitySha256!),
          );
    } on Object {
      return false;
    }
  }

  Future<void> _removeObsoleteDownloads(
    Directory directory, {
    required Set<String> retainedPaths,
  }) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File &&
          !retainedPaths.contains(entry.path) &&
          (entry.path.endsWith('.apk') || entry.path.endsWith('.part'))) {
        await entry.delete();
      }
    }
  }
}

String _normalizeSha256(String value) {
  final normalized = value.replaceAll(':', '').trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw const FormatException('签名证书摘要必须是 SHA-256');
  }
  return normalized;
}
