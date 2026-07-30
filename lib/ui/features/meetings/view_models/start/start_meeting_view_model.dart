import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../domain/models/app_failure.dart';
import '../../../../../domain/models/asr_model_registry.dart';
import '../../../../../domain/models/meeting_readiness.dart';
import '../../../../../domain/models/model_installation.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/repositories.dart';
import '../../../../../domain/ports/asr_engine.dart';
import '../../../../../domain/use_cases/start_meeting.dart';

/// 使用全局默认模型直接创建会议，不提供本场标题或模型覆盖。
final class StartMeetingViewModel extends ChangeNotifier {
  StartMeetingViewModel({
    required this.preferences,
    required this.installations,
    required this.startMeeting,
    AsrModelRegistry? registry,
  }) : registry = registry ?? AsrModelRegistry.alpha,
       _defaultModelId = (registry ?? AsrModelRegistry.alpha).defaultModelId;

  final ModelPreferenceRepository preferences;
  final ActiveModelInstallationRepository installations;
  final StartMeetingUseCase startMeeting;
  final AsrModelRegistry registry;

  StreamSubscription<List<ModelInstallation>>? _subscription;
  Future<void>? _loadingOperation;
  Map<String, String> _availableVersions = const {};
  String _defaultModelId;
  String? _errorMessage;
  String? _errorCode;
  FailureUserAction? _failureAction;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _disposed = false;
  StartedMeetingSession? _startedSession;

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  FailureUserAction? get failureAction => _failureAction;
  String get defaultModelId => _defaultModelId;
  StartedMeetingSession? get startedSession => _startedSession;
  bool get isModelLocked => _startedSession != null;

  Future<void> load() => _loadingOperation ??= _load();

  Future<StartedMeetingSession?> start() async {
    if (_isBusy || isModelLocked) {
      return _startedSession;
    }
    return _startConfirmed();
  }

  Future<void> _load() async {
    _isLoading = true;
    _notify();
    try {
      _defaultModelId = await preferences.getDefaultModelId();
      registry.requireById(_defaultModelId);
      final initialState = Completer<void>();
      _subscription = installations.watchAll().listen(
        (records) => unawaited(
          _applyInstallations(records).then(
            (_) {
              if (!initialState.isCompleted) {
                initialState.complete();
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!initialState.isCompleted) {
                initialState.completeError(error, stackTrace);
                return;
              }
              _errorMessage = '模型状态读取失败';
              _notify();
            },
          ),
        ),
        onError: (Object error, StackTrace stackTrace) {
          if (!initialState.isCompleted) {
            initialState.completeError(error, stackTrace);
            return;
          }
          _errorMessage = '模型状态读取失败';
          _notify();
        },
        onDone: () {
          if (!initialState.isCompleted) {
            initialState.completeError(StateError('模型安装状态流未返回初始值'));
          }
        },
      );
      await initialState.future;
    } on Object {
      _errorMessage = '开始会议信息加载失败';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _applyInstallations(
    List<ModelInstallation> installations,
  ) async {
    final byIdentity = {
      for (final installation in installations)
        '${installation.modelId}@${installation.version}': installation,
    };
    final available = <String, String>{};
    for (final descriptor in registry.models) {
      final installation =
          byIdentity['${descriptor.modelId}@${descriptor.version}'];
      final activeVersion = await this.installations.getActiveVersion(
        descriptor.modelId,
      );
      if (installation?.state == ModelInstallationState.installed &&
          installation?.verifiedAt != null &&
          activeVersion == descriptor.version) {
        available[descriptor.modelId] = descriptor.version;
      }
    }
    _availableVersions = Map.unmodifiable(available);
    _notify();
  }

  Future<StartedMeetingSession?> _startConfirmed() async {
    StartedMeetingSession? session;
    await _runBusy(() async {
      session = await startMeeting.execute(
        defaultModelId: _defaultModelId,
        availableVersions: _availableVersions,
      );
      _startedSession = session;
    });
    return session;
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    _errorCode = null;
    _failureAction = null;
    _notify();
    try {
      await operation();
    } on StartMeetingBlocked catch (error) {
      _applyFailure(_blockedFailure(error));
    } on StartMeetingException catch (error) {
      _applyFailure(_appFailurePresentation(error.failure));
    } on AsrEngineException catch (error) {
      _applyFailure(_appFailurePresentation(error.failure));
    } on Object {
      _applyFailure(
        const _StartFailurePresentation(
          code: 'meeting.start.unexpected',
          message: '会议启动失败，请稍后重试',
          action: FailureUserAction.retry,
        ),
      );
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _applyFailure(_StartFailurePresentation failure) {
    _errorCode = failure.code;
    _failureAction = failure.action;
    _errorMessage = '${failure.message}（错误码：${failure.code}）';
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

_StartFailurePresentation _blockedFailure(StartMeetingBlocked error) {
  return switch (error.reason) {
    StartMeetingBlockReason.readiness => _readinessFailure(error.readiness!),
    StartMeetingBlockReason.advancedModelUnavailable =>
      const _StartFailurePresentation(
        code: 'meeting.start.advanced_model_unavailable',
        message: '默认高级模型尚未安装，请先在设置中下载或切换默认模型',
        action: FailureUserAction.downloadModel,
      ),
    StartMeetingBlockReason.standardModelUnavailable =>
      const _StartFailurePresentation(
        code: 'meeting.start.standard_model_unavailable',
        message: '默认标准模型尚未准备完成，请重新安装应用后重试',
        action: FailureUserAction.reinstallApp,
      ),
  };
}

_StartFailurePresentation _readinessFailure(MeetingReadiness readiness) {
  final firstIssue = readiness.issues.first;
  return switch (firstIssue) {
    MeetingReadinessIssue.microphonePermission =>
      const _StartFailurePresentation(
        code: 'meeting.start.microphone_permission',
        message: '需要麦克风权限。授权后才能开始会议，未授权时不会创建会议。',
        action: FailureUserAction.grantPermission,
      ),
    MeetingReadinessIssue.insufficientStorage =>
      const _StartFailurePresentation(
        code: 'meeting.start.storage_insufficient',
        message: '存储空间不足。请至少保留 128 MB 可用空间后重试。',
        action: FailureUserAction.freeStorage,
      ),
    MeetingReadinessIssue.defaultModelUnavailable =>
      readiness.defaultModelId == whisperSmallAdvancedModelId
          ? const _StartFailurePresentation(
              code: 'meeting.start.advanced_model_unavailable',
              message: '默认高级模型不可用，请先在设置中下载或切换默认模型',
              action: FailureUserAction.downloadModel,
            )
          : const _StartFailurePresentation(
              code: 'meeting.start.standard_model_unavailable',
              message: '默认标准模型尚未准备完成，请重新安装应用后重试',
              action: FailureUserAction.reinstallApp,
            ),
  };
}

_StartFailurePresentation _appFailurePresentation(AppFailure failure) {
  final message = switch (failure.code) {
    'asr.whisper.native_library_unavailable' => '本地转录组件不可用，请重新安装应用',
    'asr.whisper.context_create_failed' => '内置 Base 模型上下文创建失败，请重试',
    'meeting.start.persistence_failed' => '会议无法写入本地数据库，请重试',
    'meeting.start.asr_factory_failed' => '本地转录引擎无法创建，请重试',
    'meeting.start.asr_initialization_failed' => '本地转录引擎初始化失败，请重试',
    _ => '本地转录模型无法初始化，请按提示处理后重试',
  };
  return _StartFailurePresentation(
    code: failure.code,
    message: message,
    action: failure.userAction,
  );
}

final class _StartFailurePresentation {
  const _StartFailurePresentation({
    required this.code,
    required this.message,
    required this.action,
  });

  final String code;
  final String message;
  final FailureUserAction action;
}
