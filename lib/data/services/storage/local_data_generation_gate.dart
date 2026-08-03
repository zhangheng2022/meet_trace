import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_file_layout.dart';

/// 本地数据代门。
///
/// 已安装数据代与 [currentGeneration] 不一致时，清空整个应用数据根目录
/// （数据库、会议音频与快照、已下载模型以及任何残留文件），重建基础目录
/// 并写入新标记。Alpha 采用升级全清策略：不保留旧数据、不做 schema
/// 原地迁移，重走模型下载与初始化流程。该门是执行这一策略的唯一入口，
/// 必须在打开数据库与初始化运行资源之前运行。
final class LocalDataGenerationGate {
  const LocalDataGenerationGate({
    required this.layout,
    this.now = DateTime.now,
    this.readMarker = _readMarkerFile,
  });

  /// 当前数据代。引入数据不兼容变更时必须递增，并在 PRD 记录清数据原因。
  static const currentGeneration = 2;

  static const markerFileName = 'data_generation.json';

  final AppFileLayout layout;
  final DateTime Function() now;
  final Future<String> Function(File marker) readMarker;

  /// 校验数据代；返回本次是否清除了旧数据。
  ///
  /// 标记缺失（含历史 Alpha 安装）或损坏一律视为旧数据代并清场，
  /// 清场失败时直接向上抛出，绝不带着旧数据继续启动。
  /// 首次安装不存在数据根目录时只建立基线，不视为清场。
  Future<bool> ensureCurrent() async {
    final marker = File(p.join(layout.rootPath, markerFileName));
    if (await _markerIsCurrent(marker)) {
      return false;
    }
    final root = Directory(layout.rootPath);
    final removedLegacyData = await root.exists();
    if (removedLegacyData) {
      await root.delete(recursive: true);
    }
    await layout.createBaseDirectories();
    await _writeMarker(marker);
    return removedLegacyData;
  }

  Future<bool> _markerIsCurrent(File marker) async {
    try {
      if (!await marker.exists()) {
        return false;
      }
      final decoded = jsonDecode(await readMarker(marker));
      if (decoded is! Map<String, Object?>) {
        return false;
      }
      return decoded['schemaVersion'] == 1 &&
          decoded['generation'] == currentGeneration;
    } on FormatException {
      return false;
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LocalDataGenerationMarkerReadException(error),
        stackTrace,
      );
    }
  }

  Future<void> _writeMarker(File marker) async {
    await marker.parent.create(recursive: true);
    final next = File('${marker.path}.next');
    if (await next.exists()) {
      await next.delete();
    }
    await next.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'generation': currentGeneration,
        'updatedAt': now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await next.rename(marker.path);
  }
}

Future<String> _readMarkerFile(File marker) => marker.readAsString();

/// 数据代标记因文件系统错误无法读取。
///
/// 该异常必须阻断启动，调用方不得把它当作旧数据代并执行自动清理。
final class LocalDataGenerationMarkerReadException implements Exception {
  const LocalDataGenerationMarkerReadException(this.cause);

  final FileSystemException cause;

  @override
  String toString() => '无法读取本地数据代标记：$cause';
}
