part of 'meeting_detail_view_model.dart';

final class MeetingActionsViewModel {
  const MeetingActionsViewModel._(this._owner);
  final MeetingDetailViewModel _owner;
  bool get canShare => _owner.canShare;
  bool get isDeleted => _owner.isDeleted;
  String? get message => _owner.resultMessage;
  Future<void> renameMeeting(String title) => _owner._renameMeeting(title);
  Future<void> share(MeetingShareFormat format) => _owner._share(format);
  Future<void> deleteMeeting() => _owner._deleteMeeting();
}

extension _MeetingActionsOperations on MeetingDetailViewModel {
  Future<void> _renameMeeting(String title) => _runResultOperation(() async {
    final renamed = _meeting.rename(title);
    await meetings.save(renamed);
    _meeting = renamed;
    _resultMessage = '会议名称已保存';
  }, failureMessage: '会议名称保存失败，请重试');

  Future<void> _share(MeetingShareFormat format) =>
      _runResultOperation(() async {
        final service = sharing;
        final snapshot = _snapshot;
        if (service == null || snapshot == null) {
          return;
        }
        final document = shareBuilder.execute(
          meeting: _meeting,
          snapshot: snapshot,
          summary: _summary,
          format: format,
        );
        await service.share(document);
        _resultMessage = '已打开系统分享面板，内容不包含原始音频';
      }, failureMessage: '分享失败，请重试');

  Future<void> _deleteMeeting() => _runResultOperation(() async {
    final useCase = deletion;
    if (useCase == null) {
      return;
    }
    await playback?.stop();
    await useCase.execute(meetingId: _meeting.id);
    _deleted = true;
    _resultMessage = '会议及其本地派生数据已删除';
  }, failureMessage: '会议删除未完成，请重试');

  Future<void> _runResultOperation(
    Future<void> Function() body, {
    required String failureMessage,
  }) {
    final current = _resultOperation;
    if (current != null || isProcessing) {
      return current ?? Future.value();
    }
    _resultMessage = null;
    final operation = body().catchError((Object _) {
      _resultMessage = failureMessage;
    });
    _resultOperation = operation;
    _notify();
    return operation.whenComplete(() {
      _resultOperation = null;
      _notify();
    });
  }
}
