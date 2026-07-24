import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/repository_contracts.dart';
import '../../../../data/services/asr/asr_engine.dart';
import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/workflow_states.dart';
import '../../../../domain/use_cases/resolve_meeting_model_selection.dart';
import '../../../core/asr_model_option.dart';

const advancedModelFallbackReason = '用户确认高级模型不可用，改用标准模型';

final class StartedMeetingSession {
  const StartedMeetingSession({required this.meeting, required this.engine});

  final Meeting meeting;
  final AsrEngine engine;
}

final class StartMeetingViewModel extends ChangeNotifier {
  StartMeetingViewModel({
    required this.preferences,
    required this.installations,
    required this.meetings,
    required this.engineFactory,
    required this.meetingIdFactory,
    required this.now,
    AsrModelRegistry? registry,
    ResolveMeetingModelSelection? resolveSelection,
    this.actions = const AdvancedModelActions(),
  }) : registry = registry ?? AsrModelRegistry.alpha,
       resolveSelection =
           resolveSelection ??
           ResolveMeetingModelSelection(
             registry: registry ?? AsrModelRegistry.alpha,
           ),
       _defaultModelId = (registry ?? AsrModelRegistry.alpha).defaultModelId;

  final ModelPreferenceRepository preferences;
  final ActiveModelInstallationRepository installations;
  final MeetingRepository meetings;
  final AsrEngineFactory engineFactory;
  final String Function() meetingIdFactory;
  final DateTime Function() now;
  final AsrModelRegistry registry;
  final ResolveMeetingModelSelection resolveSelection;
  AdvancedModelActions actions;

  StreamSubscription<List<ModelInstallation>>? _subscription;
  Future<void>? _loadingOperation;
  List<AsrModelOption> _options = const [];
  Map<String, String> _availableVersions = const {};
  String _defaultModelId;
  String? _meetingOverrideModelId;
  String _title = '';
  String? _errorMessage;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _requiresAdvancedModelAction = false;
  bool _disposed = false;
  StartedMeetingSession? _startedSession;

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get requiresAdvancedModelAction => _requiresAdvancedModelAction;
  String? get errorMessage => _errorMessage;
  String get defaultModelId => _defaultModelId;
  String? get meetingOverrideModelId => _meetingOverrideModelId;
  String get selectedModelId => _meetingOverrideModelId ?? _defaultModelId;
  StartedMeetingSession? get startedSession => _startedSession;
  bool get isModelLocked => _startedSession != null;
  List<AsrModelOption> get options => List.unmodifiable(_options);

  AsrModelOption get selectedOption => optionFor(selectedModelId);

  Future<void> load() => _loadingOperation ??= _load();

  AsrModelOption optionFor(String modelId) {
    return _options.firstWhere(
      (option) => option.descriptor.modelId == modelId,
    );
  }

  void updateTitle(String value) {
    _title = value;
  }

  void chooseModel(String modelId) {
    if (isModelLocked) {
      throw StateError('录音开始后模型已经锁定');
    }
    registry.requireById(modelId);
    _meetingOverrideModelId = modelId == _defaultModelId ? null : modelId;
    _requiresAdvancedModelAction = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<StartedMeetingSession?> start() async {
    if (_isBusy || isModelLocked) {
      return _startedSession;
    }
    if (_availableVersions[selectedModelId] == null) {
      _requiresAdvancedModelAction = selectedModelId == qwenAdvancedModelId;
      _errorMessage = _requiresAdvancedModelAction
          ? null
          : '标准模型尚未准备完成，只能继续使用录音能力';
      notifyListeners();
      return null;
    }
    return _startConfirmed();
  }

  Future<StartedMeetingSession?> useStandardAndStart() {
    if (selectedModelId != qwenAdvancedModelId ||
        _availableVersions[selectedModelId] != null) {
      throw StateError('只有高级模型不可用时才能确认回退');
    }
    return _startConfirmed(
      confirmedFallbackModelId: paraformerStandardModelId,
      fallbackReason: advancedModelFallbackReason,
    );
  }

  Future<void> downloadAdvanced() async {
    final action = actions.download;
    if (action == null || _isBusy) {
      return;
    }
    await _runBusy(action);
  }

  void cancelAdvancedAction() {
    _requiresAdvancedModelAction = false;
    actions.cancel?.call();
    notifyListeners();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
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
    final options = <AsrModelOption>[];
    final available = <String, String>{};
    for (final descriptor in registry.models) {
      final installation =
          byIdentity['${descriptor.modelId}@${descriptor.version}'];
      final option = AsrModelOption.fromInstallation(
        descriptor: descriptor,
        installation: installation,
      );
      options.add(option);
      final activeVersion = await this.installations.getActiveVersion(
        descriptor.modelId,
      );
      if (option.isInstalled && activeVersion == descriptor.version) {
        available[descriptor.modelId] = descriptor.version;
      }
    }
    _options = List.unmodifiable(options);
    _availableVersions = Map.unmodifiable(available);
    _notify();
  }

  Future<StartedMeetingSession?> _startConfirmed({
    String? confirmedFallbackModelId,
    String? fallbackReason,
  }) async {
    StartedMeetingSession? session;
    await _runBusy(() async {
      final selection = resolveSelection(
        globalDefaultModelId: _defaultModelId,
        meetingOverrideModelId: _meetingOverrideModelId,
        availableVersions: _availableVersions,
        confirmedFallbackModelId: confirmedFallbackModelId,
        fallbackReason: fallbackReason,
      );
      AsrEngine? engine;
      try {
        engine = await engineFactory.create(
          modelId: selection.recordingModelId,
          modelVersion: selection.recordingModelVersion,
        );
        await engine.initialize();
        final timestamp = now();
        final created = Meeting(
          id: meetingIdFactory(),
          title: _title.trim().isEmpty ? '未命名会议' : _title.trim(),
          createdAt: timestamp,
          status: MeetingState.created,
          audioDurationMs: 0,
          requestedModelId: selection.requestedModelId,
          recordingModelId: selection.recordingModelId,
          recordingModelVersion: selection.recordingModelVersion,
          modelFallbackReason: selection.fallbackReason,
        );
        final started = created.startRecording(startedAt: timestamp);
        await meetings.save(started);
        session = StartedMeetingSession(meeting: started, engine: engine);
        _startedSession = session;
        _requiresAdvancedModelAction = false;
      } on Object {
        await engine?.dispose();
        rethrow;
      }
    });
    return session;
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } on Object {
      _errorMessage = '会议启动失败，请重试或选择其他模型';
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
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
