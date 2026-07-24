import 'dart:io';

final class DurableFileCommitException implements Exception {
  const DurableFileCommitException(this.message);

  final String message;

  @override
  String toString() => 'DurableFileCommitException: $message';
}

final class DurableFileCommitter {
  const DurableFileCommitter();

  Future<void> commit({
    required String tempPath,
    required String finalPath,
    required Future<void> Function(String finalPath) persistReference,
  }) async {
    final tempFile = File(tempPath);
    final finalFile = File(finalPath);

    if (await finalFile.exists()) {
      await _validateNonEmpty(finalFile, '最终文件');
      await persistReference(finalPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return;
    }

    if (!await tempFile.exists()) {
      throw DurableFileCommitException('临时文件不存在：$tempPath');
    }
    await _validateNonEmpty(tempFile, '临时文件');
    await finalFile.parent.create(recursive: true);

    final handle = await tempFile.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }

    final expectedBytes = await tempFile.length();
    await tempFile.rename(finalPath);
    if (!await finalFile.exists() ||
        await finalFile.length() != expectedBytes) {
      throw DurableFileCommitException('原子重命名后的最终文件校验失败：$finalPath');
    }

    await persistReference(finalPath);
  }
}

Future<void> _validateNonEmpty(File file, String label) async {
  if (await file.length() <= 0) {
    throw DurableFileCommitException('$label 为空：${file.path}');
  }
}
