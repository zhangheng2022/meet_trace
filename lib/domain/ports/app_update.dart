import '../models/app_update.dart';

/// 单一 Alpha 频道的已验证平台更新入口。
///
/// 实现必须先验证公开 Manifest 签名，并在 stage 内完成平台资产长度、哈希、
/// 包身份和签名身份校验；Domain 不接受未验证的 URL 或安装包路径。
abstract interface class AppUpdatePort {
  Future<AppUpdateCandidate?> fetchLatestCandidate();

  Future<void> stage(AppUpdateCandidate candidate);

  Future<void> requestInstall(AppUpdateCandidate candidate);
}

/// 读取当前安装包的营销版本、共享构建号和本地数据代。
abstract interface class InstalledAppVersionPort {
  Future<InstalledAppVersion> read();
}
