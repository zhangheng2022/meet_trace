import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/sharing/pcm_wav_audio_share_service.dart';
import 'package:meettrace/data/services/sharing/share_plus_cache_cleaner.dart';
import 'package:meettrace/data/services/sharing/share_return_gate.dart';
import 'package:meettrace/domain/ports/audio_share.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory root;
  late File audio;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meettrace-system-share-');
    audio = File('${root.path}${Platform.pathSeparator}meeting-audio.wav');
    await audio.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  for (final entry in <ShareResultStatus, AudioShareOutcome>{
    ShareResultStatus.dismissed: AudioShareOutcome.dismissed,
    ShareResultStatus.unavailable: AudioShareOutcome.unavailable,
  }.entries) {
    test('${entry.key} 返回前清理插件缓存', () async {
      final cleaner = _CountingCleaner();
      final sharer = SharePlusSystemAudioFileSharer(
        client: _ShareClient(result: ShareResult('', entry.key)),
        cacheCleaner: cleaner,
        returnGateFactory: () => _ReturnGate(),
      );

      expect(
        await sharer.share(
          path: audio.path,
          fileName: '会议.wav',
          title: '分享会议录音',
        ),
        entry.value,
      );
      expect(cleaner.calls, 1);
    });
  }

  test('成功选择接收端后等待应用恢复前台再清理', () async {
    final cleaner = _CountingCleaner();
    final returnGate = _ReturnGate();
    final sharer = SharePlusSystemAudioFileSharer(
      client: const _ShareClient(
        result: ShareResult('receiver', ShareResultStatus.success),
      ),
      cacheCleaner: cleaner,
      returnGateFactory: () => returnGate,
    );

    expect(
      await sharer.share(path: audio.path, fileName: '会议.wav', title: '分享会议录音'),
      AudioShareOutcome.completed,
    );
    expect(returnGate.waitCalls, 1);
    expect(cleaner.calls, 1);
  });

  test('系统分享异常时清理插件缓存并保留原异常', () async {
    final cleaner = _CountingCleaner();
    final error = StateError('share failed');
    final sharer = SharePlusSystemAudioFileSharer(
      client: _ShareClient(error: error),
      cacheCleaner: cleaner,
      returnGateFactory: () => _ReturnGate(),
    );

    await expectLater(
      sharer.share(path: audio.path, fileName: '会议.wav', title: '分享会议录音'),
      throwsA(same(error)),
    );
    expect(cleaner.calls, 1);
  });
}

final class _ShareClient implements SharePlusClient {
  const _ShareClient({this.result, this.error});

  final ShareResult? result;
  final Object? error;

  @override
  Future<ShareResult> share(ShareParams params) async {
    if (error case final error?) {
      throw error;
    }
    return result!;
  }
}

final class _CountingCleaner implements ShareCacheCleaner {
  int calls = 0;

  @override
  Future<bool> clear() async {
    calls++;
    return true;
  }
}

final class _ReturnGate implements ShareReturnGate {
  int waitCalls = 0;

  @override
  void start() {}

  @override
  Future<void> waitUntilReturned() async {
    waitCalls++;
  }

  @override
  void dispose() {}
}
