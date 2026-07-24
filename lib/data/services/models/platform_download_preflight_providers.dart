import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:storage_space/storage_space.dart';

import 'downloadable_model_service.dart';

final class DeviceStorageCapacityProvider
    implements ModelStorageCapacityProvider {
  const DeviceStorageCapacityProvider();

  @override
  Future<int> getFreeBytes() async {
    final storage = await getStorageSpace(
      lowOnSpaceThreshold: minimumAdvancedModelFreeBytes,
      fractionDigits: 1,
    );
    return storage.free;
  }
}

final class ConnectivityDownloadNetworkStatusProvider
    implements DownloadNetworkStatusProvider {
  ConnectivityDownloadNetworkStatusProvider({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<DownloadNetworkKind> getCurrentKind() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty ||
        (results.length == 1 && results.single == ConnectivityResult.none)) {
      return DownloadNetworkKind.offline;
    }
    if (results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    )) {
      return DownloadNetworkKind.unmetered;
    }
    if (results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.satellite,
    )) {
      return DownloadNetworkKind.metered;
    }
    return DownloadNetworkKind.unknown;
  }
}
