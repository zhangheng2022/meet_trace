import '../../../domain/models/app_update.dart';
import '../../../domain/ports/app_update.dart';
import 'bounded_https_client.dart';
import 'signed_app_update_manifest_parser.dart';

abstract interface class PlatformAppUpdateHandler {
  Future<void> stage(VerifiedPlatformAppUpdate update);

  Future<void> requestInstall(VerifiedPlatformAppUpdate update);
}

abstract interface class AppUpdateManifestSource {
  Future<List<int>> fetch();
}

final class HttpAppUpdateManifestSource implements AppUpdateManifestSource {
  HttpAppUpdateManifestSource({
    required this.manifestUri,
    required this.http,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const maxManifestBytes = 256 * 1024;

  final Uri manifestUri;
  final BoundedHttpsClient http;
  final DateTime Function() now;

  @override
  Future<List<int>> fetch() {
    final query = <String, String>{
      ...manifestUri.queryParameters,
      'checkedAt': now().toUtc().millisecondsSinceEpoch.toString(),
    };
    return http.getBytes(
      manifestUri.replace(queryParameters: query),
      maxBytes: maxManifestBytes,
    );
  }
}

final class SignedManifestAppUpdatePort implements AppUpdatePort {
  SignedManifestAppUpdatePort({
    required this.source,
    required this.parser,
    required this.platform,
    required this.handler,
  });

  final AppUpdateManifestSource source;
  final SignedAppUpdateManifestParser parser;
  final AppUpdatePlatform platform;
  final PlatformAppUpdateHandler handler;
  final Map<String, VerifiedPlatformAppUpdate> _verifiedByArtifactId = {};

  @override
  Future<AppUpdateCandidate?> fetchLatestCandidate() async {
    final update = await parser.parse(await source.fetch(), platform: platform);
    _verifiedByArtifactId
      ..clear()
      ..[update.candidate.artifactId] = update;
    return update.candidate;
  }

  @override
  Future<void> stage(AppUpdateCandidate candidate) =>
      handler.stage(_verified(candidate));

  @override
  Future<void> requestInstall(AppUpdateCandidate candidate) =>
      handler.requestInstall(_verified(candidate));

  VerifiedPlatformAppUpdate _verified(AppUpdateCandidate candidate) {
    final update = _verifiedByArtifactId[candidate.artifactId];
    if (update == null ||
        update.candidate.releaseId != candidate.releaseId ||
        update.candidate.versionName != candidate.versionName ||
        update.candidate.buildNumber != candidate.buildNumber ||
        update.candidate.dataGeneration != candidate.dataGeneration ||
        update.candidate.status != candidate.status ||
        update.candidate.sourceCommitSha != candidate.sourceCommitSha ||
        update.candidate.approvedAt != candidate.approvedAt) {
      throw StateError('更新候选未经过当前进程的 Manifest 验证');
    }
    return update;
  }
}
