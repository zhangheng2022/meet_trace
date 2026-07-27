import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../domain/models/meeting.dart';
import '../theme/theme.dart';
import '../ui/features/meetings/view_models/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/meeting_detail_view_model.dart';
import '../ui/features/meetings/view_models/recording_session_view_model.dart';
import '../ui/features/meetings/view_models/start_meeting_view_model.dart';
import '../ui/features/meetings/views/meeting_detail_view.dart';
import '../ui/features/meetings/views/meeting_list_view.dart';
import '../ui/features/meetings/views/recording_session_view.dart';
import '../ui/features/meetings/views/start_meeting_view.dart';
import '../ui/features/settings/view_models/data_controls_view_model.dart';
import '../ui/features/settings/view_models/model_settings_view_model.dart';
import '../ui/features/settings/views/model_settings_view.dart';
import 'application.dart';
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
          return _BootstrapError(
            onRetry: () {
              setState(() {
                _loading = MeetTraceDependencies.create();
              });
            },
          );
        }
        final dependencies = snapshot.data;
        if (dependencies == null) {
          return const _BootstrapLoading();
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

enum _MeetTracePage { meetings, start, recording, detail, settings }

final class MeetTraceFlow extends StatefulWidget {
  const MeetTraceFlow({required this.dependencies, super.key});

  final MeetTraceDependencies dependencies;

  @override
  State<MeetTraceFlow> createState() => _MeetTraceFlowState();
}

final class _MeetTraceFlowState extends State<MeetTraceFlow> {
  late final MeetingListViewModel _meetingList = widget.dependencies
      .createMeetingListViewModel();
  StartMeetingViewModel? _startMeeting;
  RecordingSessionViewModel? _recording;
  MeetingDetailViewModel? _meetingDetail;
  ModelSettingsViewModel? _modelSettings;
  DataControlsViewModel? _dataControls;
  _MeetTracePage _page = _MeetTracePage.meetings;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == _MeetTracePage.meetings,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _back();
        }
      },
      child: switch (_page) {
        _MeetTracePage.meetings => MeetingListView(
          viewModel: _meetingList,
          onStartMeeting: _openStartMeeting,
          onOpenMeeting: _openMeeting,
          onOpenSettings: _openSettings,
        ),
        _MeetTracePage.start => StartMeetingView(
          viewModel: _startMeeting!,
          onBack: _back,
          onStarted: _openRecording,
        ),
        _MeetTracePage.recording => RecordingSessionView(
          viewModel: _recording!,
          onFinished: _openMeeting,
        ),
        _MeetTracePage.detail => MeetingDetailView(
          viewModel: _meetingDetail!,
          onBack: _back,
          onDeleted: _back,
        ),
        _MeetTracePage.settings => ModelSettingsView(
          viewModel: _modelSettings!,
          dataControls: _dataControls,
          onBack: _back,
        ),
      },
    );
  }

  void _openStartMeeting() {
    _startMeeting?.dispose();
    setState(() {
      _startMeeting = widget.dependencies.createStartMeetingViewModel();
      _page = _MeetTracePage.start;
    });
  }

  void _openRecording(StartedMeetingSession session) {
    _recording?.dispose();
    _startMeeting?.dispose();
    setState(() {
      _startMeeting = null;
      _recording = widget.dependencies.createRecordingSessionViewModel(session);
      _page = _MeetTracePage.recording;
    });
  }

  void _openMeeting(Meeting meeting) {
    _meetingDetail?.dispose();
    setState(() {
      _meetingDetail = widget.dependencies.createMeetingDetailViewModel(
        meeting,
      );
      _page = _MeetTracePage.detail;
    });
  }

  void _openSettings() {
    _modelSettings?.dispose();
    _dataControls?.dispose();
    setState(() {
      _modelSettings = widget.dependencies.createModelSettingsViewModel();
      _dataControls = widget.dependencies.createDataControlsViewModel();
      _page = _MeetTracePage.settings;
    });
  }

  void _back() {
    if (_page == _MeetTracePage.recording) {
      return;
    }
    if (_page == _MeetTracePage.detail &&
        _meetingDetail?.isProcessing == true) {
      return;
    }
    _meetingDetail?.dispose();
    _modelSettings?.dispose();
    _dataControls?.dispose();
    setState(() {
      _meetingDetail = null;
      _modelSettings = null;
      _dataControls = null;
      _page = _MeetTracePage.meetings;
    });
  }

  @override
  void dispose() {
    _meetingList.dispose();
    _startMeeting?.dispose();
    _recording?.dispose();
    _meetingDetail?.dispose();
    _modelSettings?.dispose();
    _dataControls?.dispose();
    super.dispose();
  }
}

final class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) => const FScaffold(
    header: FHeader(title: Text(appDisplayName)),
    child: Center(child: FProgress(semanticsLabel: '正在准备本地模型和数据')),
  );
}

final class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final appStyle = context.theme.style.app;
    return FScaffold(
      header: const FHeader(title: Text(appDisplayName)),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(appStyle.spaceMd),
          child: FAlert(
            variant: FAlertVariant.destructive,
            title: const Text('本地能力准备失败'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('请确认设备空间充足后重试。已有会议数据不会被删除。'),
                SizedBox(height: appStyle.spaceMd),
                FButton(onPress: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
