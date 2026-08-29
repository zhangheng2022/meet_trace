import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../data/services/storage/local_data_generation_gate.dart';
import '../data/services/sharing/share_plus_cache_cleaner.dart';
import '../domain/models/meeting.dart';
import '../domain/models/app_theme.dart';
import '../domain/models/app_language.dart';
import '../domain/use_cases/start_meeting.dart';
import '../domain/use_cases/build_meeting_share.dart';
import '../l10n/l10n.dart';
import '../l10n/ui_message_localizations.dart';
import '../ui/core/app_dialog.dart';
import '../ui/features/meetings/view_models/list/meeting_list_view_model.dart';
import '../ui/features/meetings/views/detail/meeting_detail_view.dart';
import '../ui/features/meetings/views/list/meeting_list_view.dart';
import '../ui/features/meetings/views/recording/recording_bootstrap_view.dart';
import '../ui/features/settings/views/model_settings_view.dart';
import '../ui/features/startup/views/meettrace_startup_view.dart';
import '../ui/features/startup/view_models/runtime_initialization_view_model.dart';
import '../ui/features/updates/view_models/app_update_view_model.dart';
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
    this.themeMode,
    this.languageMode,
  });

  final MeetTraceDependenciesLoader loadDependencies;
  final MeetTraceBootstrapPreflight preflight;
  final ValueNotifier<AppThemeMode>? themeMode;
  final ValueNotifier<AppLanguageMode>? languageMode;

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
    final themeMode = widget.themeMode;
    final languageMode = widget.languageMode;
    await widget.preflight();
    final dependencies = await widget.loadDependencies();
    if (!mounted) {
      return dependencies;
    }
    if (themeMode != null) {
      try {
        final savedMode = await dependencies.storage.themePreferences
            .getThemeMode();
        if (mounted) {
          themeMode.value = savedMode;
        }
      } on Object {
        if (mounted) {
          themeMode.value = AppThemeMode.system;
        }
      }
    }
    if (languageMode != null) {
      try {
        final savedMode = await dependencies.storage.languagePreferences
            .getLanguageMode();
        if (mounted) {
          languageMode.value = savedMode;
        }
      } on Object {
        if (mounted) {
          languageMode.value = AppLanguageMode.system;
        }
      }
    }
    return dependencies;
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
        return _RuntimeInitializationGate(
          dependencies: dependencies!,
          themeMode: widget.themeMode,
          languageMode: widget.languageMode,
        );
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
  const _RuntimeInitializationGate({
    required this.dependencies,
    required this.themeMode,
    required this.languageMode,
  });

  final MeetTraceDependencies dependencies;
  final ValueNotifier<AppThemeMode>? themeMode;
  final ValueNotifier<AppLanguageMode>? languageMode;

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
          themeMode: widget.themeMode,
          languageMode: widget.languageMode,
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
    required this.themeMode,
    required this.languageMode,
    required this.onRuntimeRepairRequired,
    super.key,
  });

  final MeetTraceDependencies dependencies;
  final ValueNotifier<AppThemeMode>? themeMode;
  final ValueNotifier<AppLanguageMode>? languageMode;
  final VoidCallback onRuntimeRepairRequired;

  @override
  State<MeetTraceFlow> createState() => _MeetTraceFlowState();
}

final class _MeetTraceFlowState extends State<MeetTraceFlow>
    with WidgetsBindingObserver {
  late final MeetingListViewModel _meetingList = widget.dependencies
      .createMeetingListViewModel();
  late final AppUpdateViewModel? _updates = widget.dependencies
      .createAppUpdateViewModel();
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
      unawaited(_updates?.check());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeetingListView(
      viewModel: _meetingList,
      updateViewModel: _updates,
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
    final l10n = context.l10n;
    final viewModel = widget.dependencies.createStartMeetingViewModel(
      meetingTitleFactory: (startedAt) => l10n.defaultMeetingTitle(
        _localizedMeetingDateTime(startedAt, l10n.localeName),
      ),
    );
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
        final message = viewModel.errorMessage;
        await _showStartFailure(
          message == null
              ? l10n.defaultModelTemporarilyUnavailable
              : l10n.localizeUiMessage(message),
        );
        return;
      }
      _openRecording(session);
    } finally {
      viewModel.dispose();
    }
  }

  Future<void> _showStartFailure(String message) {
    final l10n = context.l10n;
    return showAppAlertDialog(
      context: context,
      semanticsLabel: l10n.cannotStartMeeting,
      title: l10n.cannotStartMeeting,
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
    final languageMode = widget.languageMode;
    AppLocalizations currentL10n() => _currentLocalizations(languageMode);
    final viewModel = widget.dependencies.createMeetingDetailViewModel(
      meeting,
      shareBuilderProvider: () {
        final l10n = currentL10n();
        return BuildMeetingShareUseCase(
          copy: MeetingShareCopy(
            untitledMeeting: l10n.untitledMeeting,
            meetingTimeLabel: l10n.meetingTimeLabel,
            finalTranscriptTitle: l10n.finalTranscriptTitle,
            speakerFallback: l10n.speakerOne,
            exportFooter: l10n.shareExportFooter,
            labelSeparator: l10n.shareLabelSeparator,
          ),
          dateTimeFormatter: (startedAt) =>
              _localizedMeetingDateTime(startedAt, l10n.localeName),
          speakerLabelBuilder: l10n.speakerNumber,
        );
      },
      audioShareTitleBuilder: (title) =>
          currentL10n().audioShareSystemTitle(title),
      audioFileNameFallbackBuilder: () => currentL10n().audioFileNameFallback,
      speakerLabelBuilder: (number) => currentL10n().speakerNumber(number),
    );
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
    final languageMode = widget.languageMode;
    final modelSettings = widget.dependencies.createModelSettingsViewModel();
    final dataControls = widget.dependencies.createDataControlsViewModel(
      diagnosticsSubjectBuilder: () =>
          _currentLocalizations(languageMode).diagnosticsShareSubject,
    );
    final themeSettings = widget.themeMode == null
        ? null
        : widget.dependencies.createThemeSettingsViewModel(widget.themeMode!);
    final languageSettings = widget.languageMode == null
        ? null
        : widget.dependencies.createLanguageSettingsViewModel(
            widget.languageMode!,
          );
    unawaited(
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute(
              builder: (_) => ModelSettingsView(
                viewModel: modelSettings,
                dataControls: dataControls,
                themeSettings: themeSettings,
                languageSettings: languageSettings,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          )
          .whenComplete(() {
            modelSettings.dispose();
            dataControls.dispose();
            themeSettings?.dispose();
            languageSettings?.dispose();
            unawaited(_meetingList.refreshReadiness());
          }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _meetingList.dispose();
    _updates?.dispose();
    super.dispose();
  }
}

AppLocalizations _currentLocalizations(
  ValueNotifier<AppLanguageMode>? languageMode,
) {
  final locale = languageMode == null
      ? const Locale('zh')
      : languageMode.value.locale ??
            resolveAppLocale(WidgetsBinding.instance.platformDispatcher.locale);
  return lookupAppLocalizations(locale);
}

String _localizedMeetingDateTime(DateTime value, String locale) {
  final local = value.toLocal();
  return '${DateFormat.yMd(locale).format(local)} '
      '${DateFormat.jm(locale).format(local)}';
}
