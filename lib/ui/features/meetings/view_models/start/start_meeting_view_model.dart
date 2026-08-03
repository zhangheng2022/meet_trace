import 'package:flutter/foundation.dart';

import '../../../../../domain/models/meeting_readiness.dart';
import '../../../../../domain/ports/asr_engine.dart';
import '../../../../../domain/use_cases/start_meeting.dart';

/// 使用全局默认模型直接创建会议，不提供本场标题或模型覆盖。
final class StartMeetingViewModel extends ChangeNotifier {
  StartMeetingViewModel({required this.startMeeting});

  final StartMeetingUseCase startMeeting;

  String? _errorMessage;
  bool _isBusy = false;
  bool _disposed = false;
  bool _requiresRuntimeRepair = false;
  StartedMeetingSession? _startedSession;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  StartedMeetingSession? get startedSession => _startedSession;
  bool get isModelLocked => _startedSession != null;
  bool get requiresRuntimeRepair => _requiresRuntimeRepair;

  Future<StartedMeetingSession?> start() async {
    if (_isBusy || isModelLocked) {
      return _startedSession;
    }
    return _startConfirmed();
  }

  Future<StartedMeetingSession?> _startConfirmed() async {
    StartedMeetingSession? session;
    await _runBusy(() async {
      session = await startMeeting.execute();
      _startedSession = session;
    });
    return session;
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    _requiresRuntimeRepair = false;
    _notify();
    try {
      await operation();
    } on StartMeetingBlocked catch (error) {
      _errorMessage = _startBlockedMessage(error);
      _requiresRuntimeRepair =
          error.readiness?.issues.contains(
            MeetingReadinessIssue.defaultModelUnavailable,
          ) ==
          true;
    } on AsrEngineException {
      _requiresRuntimeRepair = true;
      _errorMessage = 'SenseVoice 初始化失败，正在返回资源修复流程';
    } on Object {
      _errorMessage = '会议启动失败，请检查录音权限、存储空间和默认模型后重试';
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String _startBlockedMessage(StartMeetingBlocked error) {
  return switch (error.reason) {
    StartMeetingBlockReason.readiness => _readinessMessage(error.readiness!),
  };
}

String _readinessMessage(MeetingReadiness readiness) {
  final firstIssue = readiness.issues.first;
  return switch (firstIssue) {
    MeetingReadinessIssue.microphonePermission =>
      '需要麦克风权限。授权后才能开始会议，未授权时不会创建会议。',
    MeetingReadinessIssue.insufficientStorage => '存储空间不足。请至少保留 128 MB 可用空间后重试。',
    MeetingReadinessIssue.defaultModelUnavailable =>
      'SenseVoice 尚未准备完成，请返回初始化流程校验并修复',
  };
}
