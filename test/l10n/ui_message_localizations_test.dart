import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/l10n/l10n.dart';
import 'package:meettrace/l10n/ui_message_localizations.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final chinese = lookupAppLocalizations(const Locale('zh'));

  test('英文保留最终转录加载失败和音频空间差额', () {
    expect(
      english.localizeUiMessage('最终转录状态加载失败，请重试'),
      'Could not load final transcript status. Try again.',
    );
    expect(
      english.localizeUiMessage('可用空间不足，还缺少 42 MB；未保留临时文件'),
      contains('42 MB'),
    );
  });

  test('动态消息完整匹配并支持重试前缀', () {
    expect(
      english.localizeUiMessage('将使用移动网络下载约 12.5 MB，可能产生流量费用；下载可暂停并续传。'),
      contains('12.5 MB'),
    );
    expect(
      english.localizeUiMessage('重试未成功：最终转录状态加载失败，请重试'),
      contains('Could not load final transcript status'),
    );
    expect(chinese.localizeUiMessage('最终转录状态加载失败，请重试'), '最终转录状态加载失败，请重试');
  });

  test('启动下载与完整性错误保留可操作上下文', () {
    final messages = <String>[
      '模型文件下载超时，请重试',
      '模型文件下载失败：HTTP 503',
      '服务器返回了不兼容的续传范围',
      '服务器返回的模型文件超过 Manifest 大小',
      '缺少模型文件',
      '文件大小应为 42，实际为 21',
      'SHA-256 不匹配',
      'model.onnx 下载不完整',
      '运行资源准备失败：archive invalid',
    ];

    for (final message in messages) {
      expect(
        english.localizeUiMessage(message),
        isNot(english.unexpectedError),
        reason: message,
      );
    }
    expect(english.localizeUiMessage(messages[1]), contains('503'));
    expect(
      english.localizeUiMessage(messages[5]),
      allOf(contains('42'), contains('21')),
    );
    expect(english.localizeUiMessage(messages[7]), contains('model.onnx'));
    expect(
      english.localizeRuntimeMessage('model.integrity', 'weights.onnx:sha256'),
      contains('verification failed'),
    );
    expect(
      chinese.localizeRuntimeMessage('model.integrity', 'weights.onnx:sha256'),
      chinese.modelIntegrityFailed,
    );
    expect(
      english.localizeRuntimeMessage('vad.integrity', 'silero_vad.onnx:sha256'),
      english.modelIntegrityFailed,
    );
    expect(
      english.localizeRuntimeMessage(
        'speaker.archive.invalid',
        '归档包含重复路径：model.onnx',
      ),
      english.modelPreparationFailed,
    );
    expect(
      english.localizeRuntimeMessage('model.download.http.503', messages[1]),
      contains('503'),
    );
    expect(
      english.localizeRuntimeMessage(
        'model.download.timeout',
        '重试未成功：模型文件下载超时，请重试',
      ),
      startsWith('Retry did not succeed'),
    );
    expect(
      english.localizeRuntimeMessage(
        'model.download.network',
        '模型文件下载失败，请检查网络后重试',
      ),
      english.modelDownloadFailedRetry,
    );
  });

  test('启动资源名使用稳定码本地化', () {
    expect(
      english.localizeRuntimeResourceName('speaker.diarization'),
      'Speaker separation',
    );
    expect(chinese.localizeRuntimeResourceName('speaker.diarization'), '说话人分离');
    expect(english.localizeRuntimeResourceName('SenseVoice'), 'SenseVoice');
  });

  test('麦克风数量、初始化空间与未知消息边界', () {
    expect(english.localizeUiMessage('已发现 3 个 Windows 输入设备'), contains('3'));
    expect(
      english.localizeUiMessage('初始化至少需要 1 GiB 可用空间，还缺少 99 字节'),
      contains('99'),
    );
    expect(english.localizeUiMessage('未登记错误'), english.unexpectedError);
    expect(chinese.localizeUiMessage('未登记错误'), '未登记错误');
  });

  test('录音主链的全部错误文案都有英文映射', () {
    const messages = <String>[
      '录音无法启动，请检查麦克风权限和可用空间',
      '暂停录音失败，录音状态未改变',
      '恢复录音失败，请结束会议以保留已有音频',
      '音频封存失败，请保留应用数据并重试恢复',
      '录音无法启动，请确认麦克风可用后重试',
      '无法使用麦克风，请在系统设置中授予麦克风权限后重试',
      '存储空间不足，请至少保留 128 MB 可用空间后重试',
      '未检测到可用麦克风，请连接或启用输入设备后重试',
      '该会议已有事实音频，为避免覆盖已停止录音',
    ];

    for (final message in messages) {
      expect(
        english.localizeUiMessage(message),
        isNot(english.unexpectedError),
        reason: message,
      );
    }
  });
}
