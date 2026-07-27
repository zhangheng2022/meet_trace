import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../domain/models/meeting.dart';
import '../theme/theme.dart';
import '../ui/features/meetings/view_models/meeting_list_view_model.dart';
import '../ui/features/meetings/view_models/start_meeting_view_model.dart';
import '../ui/features/meetings/views/meeting_detail_view.dart';
import '../ui/features/meetings/views/meeting_list_view.dart';
import '../ui/features/meetings/views/recording_session_view.dart';
import '../ui/features/meetings/views/start_meeting_view.dart';
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

final class MeetTraceFlow extends StatefulWidget {
  const MeetTraceFlow({required this.dependencies, super.key});

  final MeetTraceDependencies dependencies;

  @override
  State<MeetTraceFlow> createState() => _MeetTraceFlowState();
}

final class _MeetTraceFlowState extends State<MeetTraceFlow> {
  late final MeetingListViewModel _meetingList = widget.dependencies
      .createMeetingListViewModel();

  @override
  Widget build(BuildContext context) {
    return MeetingListView(
      viewModel: _meetingList,
      onStartMeeting: _openStartMeeting,
      onOpenMeeting: _openMeeting,
      onOpenSettings: _openSettings,
    );
  }

  void _openStartMeeting() {
    final viewModel = widget.dependencies.createStartMeetingViewModel();
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => StartMeetingView(
                viewModel: viewModel,
                onBack: () => Navigator.of(context).maybePop(),
                onStarted: _openRecording,
              ),
            ),
          )
          .whenComplete(viewModel.dispose),
    );
  }

  void _openRecording(StartedMeetingSession session) {
    final viewModel = widget.dependencies.createRecordingSessionViewModel(
      session,
    );
    unawaited(
      Navigator.of(context)
          .pushReplacement<void, void>(
            MaterialPageRoute(
              builder: (_) => RecordingSessionView(
                viewModel: viewModel,
                onFinished: (meeting) =>
                    _openMeeting(meeting, replaceCurrent: true),
              ),
            ),
          )
          .whenComplete(viewModel.dispose),
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
          }),
    );
  }

  @override
  void dispose() {
    _meetingList.dispose();
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
