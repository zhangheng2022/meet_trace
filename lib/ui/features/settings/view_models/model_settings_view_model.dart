import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/ports/repositories.dart';
import '../../../core/asr_model_option.dart';

final class ModelSettingsViewModel extends ChangeNotifier {
  ModelSettingsViewModel({
    required this.preferences,
    required this.installations,
    AsrModelRegistry? registry,
    this.actions = const AdvancedModelActions(),
  }) : registry = registry ?? AsrModelRegistry.alpha,
       _defaultModelId = (registry ?? AsrModelRegistry.alpha).defaultModelId;

  final ModelPreferenceRepository preferences;
  final ModelInstallationRepository installations;
  final AsrModelRegistry registry;
  final AdvancedModelActions actions;

  StreamSubscription<List<ModelInstallation>>? _subscription;
  Future<void>? _loadingOperation;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _disposed = false;
  String _defaultModelId;
  String? _errorMessage;
  List<AsrModelOption> _options = const [];

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String get defaultModelId => _defaultModelId;
  String? get errorMessage => _errorMessage;
  List<AsrModelOption> get options => List.unmodifiable(_options);

  Future<void> load() => _loadingOperation ??= _load();

  AsrModelOption optionFor(String modelId) {
    return _options.firstWhere(
      (option) => option.descriptor.modelId == modelId,
    );
  }

  Future<void> selectDefault(String modelId) async {
    if (_isBusy || _disposed) {
      return;
    }
    registry.requireById(modelId);
    final option = optionFor(modelId);
    if (!option.isInstalled) {
      _errorMessage = option.descriptor.modelId == whisperSmallAdvancedModelId
          ? '请先下载并校验高级模型'
          : '标准模型尚未准备完成';
      notifyListeners();
      return;
    }
    await _runBusy(() async {
      await preferences.setDefaultModelId(modelId);
      _defaultModelId = modelId;
    });
  }

  Future<void> downloadAdvanced() => _runAction(actions.download);

  void cancelAdvanced() {
    if (_disposed) {
      return;
    }
    actions.cancel?.call();
  }

  Future<void> retryAdvanced() => _runAction(actions.retry);

  Future<void> deleteAdvanced() => _runAction(actions.delete);

  Future<void> _load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final defaultModelId = await preferences.getDefaultModelId();
      registry.requireById(defaultModelId);
      _defaultModelId = defaultModelId;
      final initialState = Completer<void>();
      _subscription = installations.watchAll().listen(
        (installations) {
          _applyInstallations(installations);
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
        onDone: () {
          if (!initialState.isCompleted) {
            initialState.completeError(StateError('模型安装状态流未返回初始值'));
          }
        },
      );
      await initialState.future;
    } on Object {
      _errorMessage = '模型设置加载失败';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _applyInstallations(List<ModelInstallation> installations) {
    final byIdentity = {
      for (final installation in installations)
        '${installation.modelId}@${installation.version}': installation,
    };
    _options = [
      for (final descriptor in registry.models)
        AsrModelOption.fromInstallation(
          descriptor: descriptor,
          installation:
              byIdentity['${descriptor.modelId}@${descriptor.version}'],
        ),
    ];
    _notify();
  }

  Future<void> _runAction(Future<void> Function()? action) async {
    if (action == null || _isBusy || _disposed) {
      return;
    }
    await _runBusy(action);
  }

  Future<void> _runBusy(Future<void> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } on Object {
      _errorMessage = '操作失败，请重试';
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
