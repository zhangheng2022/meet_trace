import 'dart:async';

import 'package:flutter/material.dart';

import '../data/services/storage/local_data_generation_gate.dart';
import '../data/services/sharing/share_plus_cache_cleaner.dart';
import '../domain/models/meeting.dart';
import '../domain/use_cases/start_meeting.dart';
import '../ui/core/app_dialog.dart';
import '../ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import '../ui/features/meetings/views/detail/meeting_detail_view.dart';
import '../ui/features/meetings/views/list/meeting_list_view.dart';
import '../ui/features/meetings/views/recording/recording_bootstrap_view.dart';
import '../ui/features/settings/views/model_settings_view.dart';
import '../ui/features/startup/views/meettrace_startup_view.dart';
import '../ui/features/startup/view_models/runtime_initialization_view_model.dart';
import 'meettrace_dependencies.dart';
import 'meettrace_dependency_factories.dart';

typedef MeetTraceDependenciesLoader = Future<MeetTraceDependencies> Function();
typedef MeetTraceBootstrapPreflight = Future<void> Function();

Future<void> clearMeetTraceBootstrapCache() =>
    const SharePlusCacheCleaner().clear();

final class MeetTraceBootstrap extends StatefulWidget {
  const MeetTraceBootstrap({
    super.key,
    this.loadDependencies = MeetTraceDependencies.create,
    this.preflight = clearMeetTraceBootstrapCache,
  });

  final MeetTraceDependenciesLoader loadDependencies;
  final MeetTraceBootstrapPreflight preflight;

  @override
  State<MeetTraceBootstrap> createState() => _MeetTraceBootstrapState();
}

final class _MeetTraceBootstrapState extends State<MeetTraceBootstrap> {
  late Future<MeetTraceDependencies> _loading;
  Future<MeetTraceDependencies>? _activeLoading;
  MeetTraceDependencies? _dependencies;

  @override
  void initState() {
    super.initState();
    _loading = _beginLoading();
  }

  Future<MeetTraceDependencies> _createDependencies() async {
    await widget.preflight();
    return widget.loadDependencies();
  }

  Future<MeetTraceDependencies> _beginLoading() {
    final operation = _createDependencies();
    _activeLoading = operation;
    unawaited(
      operation.then<void>(
        (_) => _finishLoading(operation),
        onError: (Object _, StackTrace _) => _finishLoading(operation),
      ),
    );
    return operation;
  }

  void _finishLoading(Future<MeetTraceDependencies> operation) {
    if (identical(_activeLoading, operation)) {
      _activeLoading = null;
    }
  }

  void _retry() {
    if (_activeLoading != null) {
      return;
    }
    setState(() {
      _loading = _beginLoading();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MeetTraceDependencies>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MeetTraceStartupView();
        }
        if (snapshot.hasError) {
          if (snapshot.error is LocalDataGenerationMarkerReadException) {
            return MeetTraceDataReadBlockedView(onRetry: _retry);
          }
          return MeetTraceInitializationBlockedView(onRetry: _retry);
        }
        final dependencies = snapshot.data;
        assert(dependencies != null, '依赖初始化完成时必须返回依赖实例');
        _dependencies ??= dependencies;
        return _RuntimeInitializationGate(dependencies: dependencies!);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_dependencies?.dispose());
    super.dispose();
  }
}

final class _RuntimeInitializationGate extends StatefulWidget {
  const _RuntimeInitializationGate({required this.dependencies});

  final MeetTraceDependencies dependencies;

  @override
  State<_RuntimeInitializationGate> createState() =>
      _RuntimeInitializationGateState();
}

final class _RuntimeInitializationGateState
    extends State<_RuntimeInitializationGate> {
  late RuntimeInitializationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.dependencies.createRuntimeInitializationViewModel();
    unawaited(_viewModel.start());
  }

  @override
  Widget build(BuildContext context) =>
      MeetTraceRuntimeInitializationTransition(
        viewModel: _viewModel,
        ready: MeetTraceFlow(
          dependencies: widget.dependencies,
          onRuntimeRepairRequired: _restartForRepair,
        ),
      );

  void _restartForRepair() {
    _viewModel.dispose();
    _viewModel = widget.dependencies.createRuntimeInitializationViewModel(
      forceRepair: true,
    );
    setState(() {});
    unawaited(_viewModel.start());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}

final class MeetTraceFlow extends StatefulWidget {
  const MeetTraceFlow({
    required this.dependencies,
    required this.onRuntimeRepairRequired,
    super.key,
  });

  final MeetTraceDependencies dependencies;
  final VoidCallback onRuntimeRepairRequired;

  @override
  State<MeetTraceFlow> createState() => _MeetTraceFlowState();
}

final class _MeetTraceFlowState extends State<MeetTraceFlow>
    with WidgetsBindingObserver {
  late final MeetingListViewModel _meetingList = widget.dependencies
      .createMeetingListViewModel();
  Future<void>? _startOperation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_meetingList.refreshReadiness());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeetingListView(
      viewModel: _meetingList,
      startingMeeting: _startOperation != null,
      onStartMeeting: () => unawaited(_startMeeting()),
      onOpenMeeting: _openMeeting,
      onOpenSettings: _openSettings,
      onRepairRuntime: widget.onRuntimeRepairRequired,
    );
  }

  Future<void> _startMeeting() {
    final current = _startOperation;
    if (current != null) {
      return current;
    }
    final operation = _performStartMeeting();
    setState(() {
      _startOperation = operation;
    });
    return operation.whenComplete(() {
      if (mounted) {
        setState(() => _startOperation = null);
      } else {
        _startOperation = null;
      }
    });
  }

  Future<void> _performStartMeeting() async {
    final viewModel = widget.dependencies.createStartMeetingViewModel();
    try {
      final session = await viewModel.start();
      if (!mounted) {
        return;
      }
      if (session == null) {
        if (viewModel.requiresRuntimeRepair) {
          widget.onRuntimeRepairRequired();
          return;
        }
        await _showStartFailure(viewModel.errorMessage ?? '默认模型暂时不可用，请前往设置检查');
        return;
      }
      _openRecording(session);
    } finally {
      viewModel.dispose();
    }
  }

  Future<void> _showStartFailure(String message) {
    return showAppAlertDialog(
      context: context,
      semanticsLabel: '无法开始会议',
      title: '无法开始会议',
      message: message,
    );
  }

  void _openRecording(StartedMeetingSession session) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecordingBootstrapView(
            createViewModel: () =>
                widget.dependencies.createRecordingSessionViewModel(session),
            onFinished: (meeting) =>
                _openMeeting(meeting, replaceCurrent: true),
          ),
        ),
      ),
    );
  }

  void _openMeeting(Meeting meeting, {bool replaceCurrent = false}) {
    final viewModel = widget.dependencies.createMeetingDetailViewModel(meeting);
    final route = MaterialPageRoute<void>(
      builder: (_) => MeetingDetailView(
        viewModel: viewModel,
        onBack: () => Navigator.of(context).maybePop(),
        onDeleted: () => Navigator.of(context).maybePop(),
      ),
    );
    final navigation = replaceCurrent
        ? Navigator.of(context).pushReplacement<void, void>(route)
        : Navigator.of(context).push<void>(route);
    unawaited(navigation.whenComplete(viewModel.dispose));
  }

  void _openSettings() {
    final modelSettings = widget.dependencies.createModelSettingsViewModel();
    final dataControls = widget.dependencies.createDataControlsViewModel();
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => ModelSettingsView(
                viewModel: modelSettings,
                dataControls: dataControls,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          )
          .whenComplete(() {
            modelSettings.dispose();
            dataControls.dispose();
            unawaited(_meetingList.refreshReadiness());
          }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _meetingList.dispose();
    super.dispose();
  }
}
