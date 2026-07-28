import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../domain/models/asr_preview.dart';
import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/recording.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/asr_preview_session.dart';
import '../../../../../domain/ports/recording_session.dart';
import '../../../../../domain/use_cases/manage_recording_session.dart';
import '../../../../../domain/use_cases/start_meeting.dart';

typedef RecordingTickerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

const recordingWaveformSampleCapacity = 48;

final class RecordingSessionViewModel extends ChangeNotifier {
  RecordingSessionViewModel({
    required StartedMeetingSession session,
    required this.recording,
    required this.preview,
    required this.sessionLifecycle,
    RecordingTickerFactory? tickerFactory,
  }) : _meeting = session.meeting,
       _tickerFactory = tickerFactory ?? Timer.periodic,
       _previewMetrics = preview.metrics;

  final RecordingSessionService recording;
  final AsrPreviewSession preview;
  final ManageRecordingSessionUseCase sessionLifecycle;
  final RecordingTickerFactory _tickerFactory;

  Meeting _meeting;
  AsrPreviewMetrics _previewMetrics;
  final Map<String, TranscriptSegmentEvent> _segments = {};
  final List<double> _audioLevels = [];
  StreamSubscription<TranscriptEvent>? _eventSubscription;
  StreamSubscription<AsrPreviewMetrics>? _metricsSubscription;
  StreamSubscription<RecordingAudioLevel>? _audioLevelSubscription;
  Timer? _ticker;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  bool _isBusy = false;
  bool _isFinalizing = false;
  bool _disposed = false;

  Meeting get meeting => _meeting;
  RecordingState get recordingState => recording.state;
  AsrPreviewMetrics get previewMetrics => _previewMetrics;
  Duration get duration => _duration;
  List<double> get audioLevels => List.unmodifiable(_audioLevels);
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;
  bool get isFinalizing => _isFinalizing;
  bool get canPause => !_isBusy && recordingState == RecordingState.recording;
  bool get canResume => !_isBusy && recordingState == RecordingState.paused;
  bool get canStop => !_isBusy && recording.canFinalize;

  List<TranscriptSegmentEvent> get segments {
    final values = _segments.values.toList();
    values.sort((left, right) {
      final byStart = left.startMs.compareTo(right.startMs);
      return byStart != 0 ? byStart : left.segmentId.compareTo(right.segmentId);
    });
    return List.unmodifiable(values);
  }

  Future<bool> start() async {
    if (_isBusy || recordingState != RecordingState.idle) {
      return recordingState == RecordingState.recording;
    }
    _subscribePreview();
    _setBusy(true);
    try {
      await sessionLifecycle.start(_meeting);
      refreshDuration();
      _ticker = _tickerFactory(
        const Duration(milliseconds: 250),
        (_) => refreshDuration(),
      );
      return true;
    } on ManageRecordingSessionException catch (error) {
      _meeting = error.meeting;
      _errorMessage = '录音无法启动，请检查麦克风权限和可用空间';
      await _disposePreviewBestEffort();
      return false;
    } on Object {
      _errorMessage = '录音无法启动，请检查麦克风权限和可用空间';
      await _disposePreviewBestEffort();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> pause() async {
    if (!canPause) {
      return;
    }
    await _runRecordingAction(
      recording.pause,
      failureMessage: '暂停录音失败，录音状态未改变',
    );
  }

  Future<void> resume() async {
    if (!canResume) {
      return;
    }
    await _runRecordingAction(
      recording.resume,
      failureMessage: '恢复录音失败，请结束会议以保留已有音频',
    );
  }

  Future<Meeting?> stop() async {
    if (!canStop) {
      return null;
    }
    _isFinalizing = true;
    _setBusy(true);
    _ticker?.cancel();
    try {
      _meeting = await sessionLifecycle.finish(_meeting);
      _duration = Duration(milliseconds: _meeting.audioDurationMs);
      await _disposePreviewBestEffort();
      return _meeting;
    } on ManageRecordingSessionException catch (error) {
      _meeting = error.meeting;
      _errorMessage = '音频封存失败，请保留应用数据并重试恢复';
      await _disposePreviewBestEffort();
      return null;
    } on Object {
      _errorMessage = '音频封存失败，请保留应用数据并重试恢复';
      await _disposePreviewBestEffort();
      return null;
    } finally {
      _isFinalizing = false;
      _setBusy(false);
    }
  }

  void refreshDuration() {
    _duration = recording.duration;
    _notify();
  }

  Future<void> _runRecordingAction(
    Future<void> Function() operation, {
    required String failureMessage,
  }) async {
    _setBusy(true);
    try {
      await operation();
      refreshDuration();
    } on Object {
      _errorMessage = failureMessage;
    } finally {
      _setBusy(false);
    }
  }

  void _subscribePreview() {
    _audioLevelSubscription ??= recording.audioLevelChanges.listen((sample) {
      _audioLevels.add(sample.level);
      final overflow = _audioLevels.length - recordingWaveformSampleCapacity;
      if (overflow > 0) {
        _audioLevels.removeRange(0, overflow);
      }
      _notify();
    });
    _eventSubscription ??= preview.events.listen((event) {
      if (event case final TranscriptSegmentEvent segment) {
        _segments[segment.segmentId] = segment;
        _notify();
      }
    });
    _metricsSubscription ??= preview.metricsChanges.listen((metrics) {
      _previewMetrics = metrics;
      _notify();
    });
  }

  void _setBusy(bool value) {
    _isBusy = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _disposePreview() async {
    await _audioLevelSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _metricsSubscription?.cancel();
    _audioLevelSubscription = null;
    _eventSubscription = null;
    _metricsSubscription = null;
    await preview.dispose();
  }

  Future<void> _disposePreviewBestEffort() async {
    try {
      await _disposePreview();
    } on Object {
      // 事实音频和会议状态优先，预览资源释放异常不得回滚主链。
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    if (recordingState != RecordingState.recording &&
        recordingState != RecordingState.paused) {
      unawaited(_disposePreviewBestEffort());
    } else {
      unawaited(_audioLevelSubscription?.cancel());
      unawaited(_eventSubscription?.cancel());
      unawaited(_metricsSubscription?.cancel());
    }
    super.dispose();
  }
}
