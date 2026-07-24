import 'package:disk_space_2/disk_space_2.dart';
import 'package:path_provider/path_provider.dart';

const _bytesPerMebibyte = 1024 * 1024;

typedef FreeDiskSpaceInMebibytesReader = Future<double?> Function();

/// 将平台磁盘空间 API 收口为应用内部统一使用的字节数。
final class DeviceFreeSpaceService {
  const DeviceFreeSpaceService({this.reader});

  final FreeDiskSpaceInMebibytesReader? reader;

  Future<int> getFreeBytes() async {
    final freeMebibytes = await (reader ?? _readApplicationSupportVolume)();
    if (freeMebibytes == null || !freeMebibytes.isFinite || freeMebibytes < 0) {
      throw StateError('平台未返回有效的可用磁盘空间');
    }
    return (freeMebibytes * _bytesPerMebibyte).floor();
  }
}

Future<double?> _readApplicationSupportVolume() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return DiskSpace.getFreeDiskSpaceForPath(supportDirectory.path);
}
