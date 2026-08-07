import '../../../../../domain/ports/audio_share.dart';
import '../../../../../domain/use_cases/build_meeting_share.dart';
import '../../../../../domain/use_cases/share_meeting_audio.dart';
import 'meeting_detail_view_model.dart';

final class MeetingActionsViewModel {
  const MeetingActionsViewModel.internal(this._owner);
  final MeetingDetailViewModel _owner;
  bool get canShare => _owner.canShare;
  bool get canShareAudio =>
      _owner.audioSharing != null &&
      _owner.meeting.audioPath != null &&
      _owner.meeting.audioDurationMs > 0;
  bool get isDeleted => _owner.isDeleted;
  String? get message => _owner.resultMessage;
  Future<void> share(MeetingShareFormat format) => _owner.internalShare(format);
  Future<AudioSharePreparation?> prepareAudioShare() =>
      _owner.internalPrepareAudioShare();
  Future<void> shareAudio(AudioSharePreparation preparation) =>
      _owner.internalShareAudio(preparation);
  Future<void> deleteMeeting() => _owner.internalDeleteMeeting();
}

extension _MeetingActionsOperations on MeetingDetailViewModel {
  Future<void> internalShare(MeetingShareFormat format) =>
      internalRunResultOperation(() async {
        final service = sharing;
        final snapshot = internalSnapshot;
        if (service == null || snapshot == null) {
          return;
        }
        final document = shareBuilder.execute(
          meeting: internalMeeting,
          snapshot: snapshot,
          format: format,
        );
        await service.share(document);
        internalResultMessage = '已打开系统分享面板，内容不包含原始音频';
      }, failureMessage: '分享失败，请重试');

  Future<AudioSharePreparation?> internalPrepareAudioShare() async {
    final useCase = audioSharing;
    if (useCase == null || internalResultOperation != null || isProcessing) {
      return null;
    }
    internalResultMessage = null;
    final preparation = useCase.prepare(internalMeeting);
    internalResultOperation = preparation.then<void>((_) {});
    internalNotify();
    try {
      return await preparation;
    } on Object {
      internalResultMessage = '无法读取事实音频或可用空间，请重试';
      return null;
    } finally {
      internalResultOperation = null;
      internalNotify();
    }
  }

  Future<void> internalShareAudio(AudioSharePreparation preparation) =>
      internalRunResultOperation(
        () async {
          final useCase = audioSharing;
          if (useCase == null) {
            return;
          }
          final outcome = await useCase.execute(preparation);
          internalResultMessage = switch (outcome) {
            AudioShareOutcome.completed => '音频分享操作已完成，临时文件已清理',
            AudioShareOutcome.dismissed => '已取消音频分享，临时文件已清理',
            AudioShareOutcome.unavailable => '已打开系统分享面板，平台未返回操作结果；临时文件已清理',
          };
        },
        failureMessage: '音频分享失败，临时文件已清理，请重试',
        mapFailure: (error) {
          if (error case AudioShareException(shortageBytes: final shortage?)) {
            return '可用空间不足，还缺少 ${_audioShareByteLabel(shortage)}；未保留临时文件';
          }
          if (error case AudioShareException(
            code: 'audio_share.cleanup_failed',
          )) {
            return '音频分享临时文件清理失败，请重启应用后重试';
          }
          return '音频分享失败，临时文件已清理，请重试';
        },
      );

  Future<void> internalDeleteMeeting() => internalRunResultOperation(() async {
    final useCase = deletion;
    if (useCase == null) {
      return;
    }
    await playback?.stop();
    await useCase.execute(meetingId: internalMeeting.id);
    internalDeleted = true;
    internalResultMessage = '会议及其本地派生数据已删除';
  }, failureMessage: '会议删除未完成，请重试');
}

String _audioShareByteLabel(int bytes) {
  const kib = 1024;
  const mib = kib * 1024;
  if (bytes >= mib) {
    return '${(bytes / mib).toStringAsFixed(1)} MiB';
  }
  if (bytes >= kib) {
    return '${(bytes / kib).toStringAsFixed(1)} KiB';
  }
  return '$bytes B';
}
