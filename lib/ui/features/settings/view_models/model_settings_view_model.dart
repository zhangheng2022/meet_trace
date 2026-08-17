import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/asr_model_registry.dart';
import '../../../../domain/models/model_installation.dart';
import '../../../../domain/models/recording_input.dart';
import '../../../../domain/ports/recording_input.dart';
import '../../../../domain/ports/repositories.dart';
import '../../../core/asr_model_option.dart';

final class ModelSettingsViewModel extends ChangeNotifier {
  ModelSettingsViewModel({
    required this.preferences,
    required this.installations,
    AsrModelRegistry? registry,
    this.actions = const ModelMaintenanceActions(),
    this.recordingInputPreferences,
    this.recordingInputDevices,
  }) : registry = registry ?? AsrModelRegistry.alpha,
       _defaultModelId = (registry ?? AsrModelRegistry.alpha).defaultModelId;

  final ModelPreferenceRepository preferences;
  final ModelInstallationRepository installations;
  final AsrModelRegistry registry;
  final ModelMaintenanceActions actions;
  final RecordingInputPreferenceRepository? recordingInputPreferences;
  final RecordingInputDeviceCatalog? recordingInputDevices;

  StreamSubscription<List<ModelInstallation>>? _subscription;
  Future<void>? _loadingOperation;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _disposed = false;
  bool _recordingInputsLoading = false;
  bool _recordingInputBusy = false;
  String _defaultModelId;
  String? _errorMessage;
  String? _recordingInputErrorMessage;
  String? _recordingInputStatusMessage;
  List<AsrModelOption> _options = const [];
  RecordingInputPreference? _recordingInputPreference;
  List<RecordingInputDevice> _recordingInputOptions = const [];

  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String get defaultModelId => _defaultModelId;
  String? get errorMessage => _errorMessage;
  List<AsrModelOption> get options => List.unmodifiable(_options);
  bool get supportsRecordingInputSelection =>
      recordingInputPreferences != null && recordingInputDevices != null;
  bool get recordingInputsLoading => _recordingInputsLoading;
  bool get recordingInputBusy => _recordingInputBusy;
  String? get recordingInputErrorMessage => _recordingInputErrorMessage;
  String? get recordingInputStatusMessage => _recordingInputStatusMessage;
  RecordingInputPreference? get recordingInputPreference =>
      _recordingInputPreference;
  List<RecordingInputDevice> get recordingInputOptions =>
      List.unmodifiable(_recordingInputOptions);
  bool get selectedRecordingInputAvailable =>
      _recordingInputPreference?.usesSystemDefault == true ||
      _recordingInputOptions.any(
        (device) => device.id == _recordingInputPreference?.deviceId,
      );

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
      _errorMessage = 'SenseVoice 尚未安装或校验未通过';
      notifyListeners();
      return;
    }
    await _runBusy(() async {
      await preferences.setDefaultModelId(modelId);
      _defaultModelId = modelId;
    });
  }

  Future<void> repairModel() => _runAction(actions.repair);

  Future<void> refreshRecordingInputs() async {
    if (!supportsRecordingInputSelection || _recordingInputsLoading) {
      return;
    }
    _recordingInputsLoading = true;
    _recordingInputErrorMessage = null;
    _recordingInputStatusMessage = '正在扫描麦克风';
    _notify();
    try {
      final preference = await recordingInputPreferences!.getPreference();
      final devices = await recordingInputDevices!.listAvailable();
      _recordingInputPreference = preference;
      _recordingInputOptions = devices;
      _recordingInputStatusMessage = devices.isEmpty
          ? '未发现其他麦克风'
          : '已发现 ${devices.length} 个 Windows 输入设备';
    } on Object {
      _recordingInputErrorMessage = '无法读取 Windows 麦克风列表，请检查系统麦克风权限后重试';
      _recordingInputStatusMessage = '麦克风扫描失败';
    } finally {
      _recordingInputsLoading = false;
      _notify();
    }
  }

  Future<void> selectRecordingInput(RecordingInputPreference preference) async {
    if (!supportsRecordingInputSelection ||
        _recordingInputBusy ||
        _recordingInputsLoading ||
        _disposed ||
        preference == _recordingInputPreference) {
      return;
    }
    _recordingInputBusy = true;
    _recordingInputErrorMessage = null;
    _notify();
    try {
      await recordingInputPreferences!.setPreference(preference);
      _recordingInputPreference = preference;
    } on Object {
      _recordingInputErrorMessage = '麦克风偏好保存失败，请重试';
    } finally {
      _recordingInputBusy = false;
      _notify();
    }
  }

  void pauseRepair() {
    if (_disposed) {
      return;
    }
    actions.pause?.call();
  }

  Future<void> _load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final recordingInputs = refreshRecordingInputs();
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
    await recordingInputs;
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
