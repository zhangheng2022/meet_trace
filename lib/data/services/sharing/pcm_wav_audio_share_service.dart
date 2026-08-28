import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../domain/ports/audio_share.dart';
import '../audio/pcm_wav_file_writer.dart';
import '../storage/app_file_layout.dart';
import '../storage/device_free_space_service.dart';
import 'share_plus_cache_cleaner.dart';
import 'share_return_gate.dart';

abstract interface class SystemAudioFileSharer {
  Future<AudioShareOutcome> share({
    required String path,
    required String fileName,
    required String title,
  });
}

abstract interface class SharePlusClient {
  Future<ShareResult> share(ShareParams params);
}

typedef ShareTempDirectoryRemover = Future<void> Function(Directory directory);

final class OfficialSharePlusClient implements SharePlusClient {
  const OfficialSharePlusClient();

  @override
  Future<ShareResult> share(ShareParams params) {
    return SharePlus.instance.share(params);
  }
}

final class SharePlusSystemAudioFileSharer implements SystemAudioFileSharer {
  const SharePlusSystemAudioFileSharer({
    this.client = const OfficialSharePlusClient(),
    this.cacheCleaner = const SharePlusCacheCleaner(),
    this.returnGateFactory = createPlatformShareReturnGate,
  });

  final SharePlusClient client;
  final ShareCacheCleaner cacheCleaner;
  final ShareReturnGateFactory returnGateFactory;

  @override
  Future<AudioShareOutcome> share({
    required String path,
    required String fileName,
    required String title,
  }) async {
    final returnGate = returnGateFactory()..start();
    var cleanupAttempted = false;
    try {
      final result = await client.share(
        ShareParams(
          files: [XFile(path, mimeType: 'audio/wav')],
          fileNameOverrides: [fileName],
          title: title,
          subject: title,
        ),
      );
      final outcome = switch (result.status) {
        ShareResultStatus.success => AudioShareOutcome.completed,
        ShareResultStatus.dismissed => AudioShareOutcome.dismissed,
        ShareResultStatus.unavailable => AudioShareOutcome.unavailable,
      };
      if (outcome == AudioShareOutcome.completed) {
        await returnGate.waitUntilReturned();
      }
      cleanupAttempted = true;
      await cacheCleaner.clear();
      return outcome;
    } on Object catch (error, stackTrace) {
      if (!cleanupAttempted) {
        try {
          await cacheCleaner.clear();
        } on Object {
          // 分享错误优先；缓存清理由下次启动继续收敛。
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      returnGate.dispose();
    }
  }
}

final class PcmWavAudioShareService implements AudioShareService {
  const PcmWavAudioShareService({
    required this.layout,
    this.freeSpace = const DeviceFreeSpaceService(),
    this.wavWriter = const PcmWavFileWriter(),
    this.systemShare = const SharePlusSystemAudioFileSharer(),
    this.removeSession = _removeSession,
    this.removeEmptyShareRoot = _removeEmptyShareRoot,
  });

  final AppFileLayout layout;
  final DeviceFreeSpaceService freeSpace;
  final PcmWavFileWriter wavWriter;
  final SystemAudioFileSharer systemShare;
  final ShareTempDirectoryRemover removeSession;
  final ShareTempDirectoryRemover removeEmptyShareRoot;

  @override
  Future<AudioShareStorageSnapshot> inspect({required String audioPath}) async {
    final source = File(audioPath);
    if (!await source.exists()) {
      throw const AudioShareException('audio_share.source_missing');
    }
    final pcmBytes = await source.length();
    int wavBytes;
    try {
      wavBytes = wavWriter.wavLengthForPcm(pcmBytes);
    } on PcmWavWriteException catch (error) {
      throw AudioShareException('audio_share.${error.code}');
    }
    return AudioShareStorageSnapshot(
      pcmBytes: pcmBytes,
      wavBytes: wavBytes,
      freeBytes: await freeSpace.getFreeBytes(),
    );
  }

  @override
  Future<AudioShareOutcome> share({
    required String meetingId,
    required String meetingTitle,
    required String audioPath,
    required int expectedPcmBytes,
  }) async {
    final latest = await inspect(audioPath: audioPath);
    if (latest.pcmBytes != expectedPcmBytes) {
      throw const AudioShareException('audio_share.source_changed');
    }
    if (!latest.hasEnoughSpace) {
      throw AudioShareException(
        'audio_share.insufficient_space',
        shortageBytes: latest.shortageBytes,
      );
    }

    final shareRoot = Directory(layout.meetingShareTempDirectory(meetingId));
    final normalizedRoot = p.normalize(p.absolute(shareRoot.path));
    await shareRoot.create(recursive: true);
    final session = await shareRoot.createTemp('session-');
    final targetPath = p.join(session.path, 'meeting-audio.wav');
    final normalizedTarget = p.normalize(p.absolute(targetPath));
    if (!p.isWithin(normalizedRoot, normalizedTarget)) {
      await session.delete(recursive: true);
      throw const AudioShareException('audio_share.invalid_temp_path');
    }

    final target = File(normalizedTarget);
    AudioShareOutcome? outcome;
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      await wavWriter.write(sourcePath: audioPath, targetPath: target.path);
      outcome = await systemShare.share(
        path: target.path,
        fileName: _safeFileName(meetingTitle),
        title: '分享会议录音：$meetingTitle',
      );
    } on AudioShareException catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    } on ShareCacheCleanupException catch (_, stackTrace) {
      failure = const AudioShareException('audio_share.cleanup_failed');
      failureStackTrace = stackTrace;
    } on PcmWavWriteException catch (error, stackTrace) {
      failure = AudioShareException('audio_share.${error.code}');
      failureStackTrace = stackTrace;
    } on Object catch (_, stackTrace) {
      failure = const AudioShareException('audio_share.failed');
      failureStackTrace = stackTrace;
    } finally {
      try {
        await removeSession(session);
      } on Object catch (error, stackTrace) {
        failure ??= error;
        failureStackTrace ??= stackTrace;
      }
      try {
        await removeEmptyShareRoot(shareRoot);
      } on Object catch (error, stackTrace) {
        failure ??= error;
        failureStackTrace ??= stackTrace;
      }
    }
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStackTrace!);
    }
    return outcome!;
  }
}

Future<void> _removeSession(Directory session) async {
  try {
    if (await session.exists()) {
      await session.delete(recursive: true);
    }
  } on FileSystemException {
    throw const AudioShareException('audio_share.cleanup_failed');
  }
}

Future<void> _removeEmptyShareRoot(Directory shareRoot) async {
  try {
    if (await shareRoot.exists() &&
        await shareRoot.list(followLinks: false).isEmpty) {
      await shareRoot.delete();
    }
  } on FileSystemException {
    // 其他并发分享可能刚好删除或写入根目录；各自的会话目录已经单独清理。
  }
}

String _safeFileName(String meetingTitle) {
  final sanitized = meetingTitle
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  final base = sanitized.isEmpty ? '会议录音' : sanitized;
  final shortened = base.length > 80 ? base.substring(0, 80) : base;
  return '$shortened.wav';
}
