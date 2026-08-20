import '../data/services/updates/android_app_update_handler.dart';
import '../data/services/updates/app_update_configuration.dart';
import '../data/services/updates/bounded_https_client.dart';
import '../data/services/updates/ed25519_app_update_signature_verifier.dart';
import '../data/services/updates/external_store_app_update_handler.dart';
import '../data/services/updates/signed_app_update_manifest_parser.dart';
import '../data/services/updates/signed_manifest_app_update_port.dart';
import '../domain/ports/repositories.dart';
import '../domain/use_cases/manage_app_update.dart';
import '../ui/features/updates/view_models/app_update_view_model.dart';
import 'meettrace_storage_dependencies.dart';

final class UpdateDependencies {
  UpdateDependencies._({
    required this.port,
    required this.installedVersions,
    required this._http,
  });

  final SignedManifestAppUpdatePort port;
  final ConfiguredInstalledAppVersionPort installedVersions;
  final BoundedHttpsClient _http;

  static UpdateDependencies? create({
    required StorageDependencies storage,
    AppUpdateRuntimeConfiguration? configuration,
  }) {
    final config =
        configuration ?? AppUpdateRuntimeConfiguration.fromEnvironment();
    final platform = config.platform;
    if (!config.enabled || platform == null) {
      return null;
    }
    final http = BoundedHttpsClient();
    final handler = switch (platform) {
      AppUpdatePlatform.android => AndroidAppUpdateHandler(
        http: http,
        installer: const MethodChannelAndroidApkInstaller(),
        storageRoot: storage.fileLayout.rootPath,
      ),
      AppUpdatePlatform.ios ||
      AppUpdatePlatform.windows => ExternalStoreAppUpdateHandler(),
    };
    final parser = SignedAppUpdateManifestParser(
      signatureVerifier: Ed25519AppUpdateSignatureVerifier(
        expectedKeyId: config.signingKeyId,
        publicKeyBytes: config.signingPublicKey,
      ),
    );
    return UpdateDependencies._(
      port: SignedManifestAppUpdatePort(
        source: HttpAppUpdateManifestSource(
          manifestUri: config.manifestUri,
          http: http,
        ),
        parser: parser,
        platform: platform,
        handler: handler,
      ),
      installedVersions: ConfiguredInstalledAppVersionPort(
        config.installedVersion,
      ),
      http: http,
    );
  }

  AppUpdateViewModel createViewModel(MeetingRepository meetings) =>
      AppUpdateViewModel(
        meetings: meetings,
        installedVersions: installedVersions,
        checkForUpdate: CheckForAppUpdateUseCase(updates: port),
        installUpdate: InstallAppUpdateUseCase(updates: port),
      );

  Future<void> dispose() async => _http.close();
}
