import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../data/services/storage/app_database.dart';
import '../domain/models/meeting.dart';
import '../domain/use_cases/start_meeting.dart';
import '../theme/theme.dart';
import '../ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import '../ui/features/meetings/views/detail/meeting_detail_view.dart';
import '../ui/features/meetings/views/list/meeting_list_view.dart';
import '../ui/features/meetings/views/recording/recording_bootstrap_view.dart';
import '../ui/features/settings/views/model_settings_view.dart';
import '../ui/features/startup/views/meettrace_startup_view.dart';
import '../ui/features/startup/view_models/runtime_initialization_view_model.dart';
import 'meettrace_dependencies.dart';

final class MeetTraceBootstrap extends StatefulWidget {
  const MeetTraceBootstrap({super.key});

  @override
  State<MeetTraceBootstrap> createState() => _MeetTraceBootstrapState();
}

final class _MeetTraceBootstrapState extends State<MeetTraceBootstrap> {
  late Future<MeetTraceDependencies> _loading = MeetTraceDependencies.create();
  MeetTraceDependencies? _dependencies;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MeetTraceDependencies>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final legacyInstallation =
              snapshot.error is UnsupportedAlphaInstallationException;
          return MeetTraceStartupErrorView(
            title: legacyInstallation ? '需要先导出旧 Alpha 录音' : '本地能力准备未完成',
            message: legacyInstallation
                ? '检测到旧版数据。应用不会自动迁移或删除录音；请先退回原 Alpha 版本导出重要录音，再卸载或清除数据后安装当前版本。'
                : '请确认设备空间充足后重试。已有会议数据不会被删除。',
            onRetry: () {
              setState(() {
                _loading = MeetTraceDependencies.create();
              });
            },
          );
        }
        final dependencies = snapshot.data;
        if (dependencies == null) {
          return const MeetTraceStartupView();
        }
        _dependencies ??= dependencies;
        return _RuntimeInitializationGate(dependencies: dependencies);
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
      await viewModel.load();
      if (!mounted) {
        return;
      }
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
    return showFDialog<void>(
      context: context,
      builder: (context, style, animation) => FDialog(
        animation: animation,
        semanticsLabel: '无法开始会议',
        builder: (context, style) {
          final appStyle = context.theme.style.app;
          return Padding(
            padding: EdgeInsets.all(appStyle.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('无法开始会议', style: style.titleTextStyle),
                SizedBox(height: appStyle.spaceSm),
                Text(message, style: context.theme.typography.body.md),
                SizedBox(height: appStyle.spaceLg),
                FButton(
                  onPress: () => Navigator.of(context).pop(),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        },
      ),
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
