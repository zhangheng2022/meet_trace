import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../domain/models/meeting.dart';
import '../domain/use_cases/start_meeting.dart';
import '../theme/theme.dart';
import '../ui/core/app_state_panel.dart';
import '../ui/features/meetings/view_models/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/recording_session_view_model.dart';
import '../ui/features/meetings/views/meeting_detail_view.dart';
import '../ui/features/meetings/views/meeting_list_view.dart';
import '../ui/features/meetings/views/recording_session_view.dart';
import '../ui/features/settings/views/model_settings_view.dart';
import '../ui/features/startup/views/meettrace_startup_view.dart';
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
          return MeetTraceStartupErrorView(
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
        return MeetTraceFlow(dependencies: dependencies);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_dependencies?.dispose());
    super.dispose();
  }
}

final class MeetTraceFlow extends StatefulWidget {
  const MeetTraceFlow({required this.dependencies, super.key});

  final MeetTraceDependencies dependencies;

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
          builder: (_) => _DeferredRecordingSessionView(
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

/// 先完成页面转场，再在静态准备页上创建原生 VAD，避免阻塞路由动画。
final class _DeferredRecordingSessionView extends StatefulWidget {
  const _DeferredRecordingSessionView({
    required this.createViewModel,
    required this.onFinished,
  });

  final RecordingSessionViewModel Function() createViewModel;
  final ValueChanged<Meeting> onFinished;

  @override
  State<_DeferredRecordingSessionView> createState() =>
      _DeferredRecordingSessionViewState();
}

final class _DeferredRecordingSessionViewState
    extends State<_DeferredRecordingSessionView> {
  Animation<double>? _routeAnimation;
  RecordingSessionViewModel? _viewModel;
  bool _initializationScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) {
      return;
    }
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _routeAnimation = animation;
    animation?.addStatusListener(_handleRouteAnimation);
    if (animation == null || animation.status == AnimationStatus.completed) {
      _scheduleInitialization();
    }
  }

  void _handleRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleInitialization();
    }
  }

  void _scheduleInitialization() {
    if (_initializationScheduled || _viewModel != null) {
      return;
    }
    _initializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final viewModel = widget.createViewModel();
      if (!mounted) {
        viewModel.dispose();
        return;
      }
      setState(() => _viewModel = viewModel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel != null) {
      return RecordingSessionView(
        viewModel: viewModel,
        onFinished: widget.onFinished,
      );
    }
    return const PopScope(
      canPop: false,
      child: FScaffold(
        childPad: false,
        header: FHeader.nested(title: Text('会迹')),
        child: AppStatePanel.loading(label: '正在启动录音'),
      ),
    );
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _viewModel?.dispose();
    super.dispose();
  }
}
