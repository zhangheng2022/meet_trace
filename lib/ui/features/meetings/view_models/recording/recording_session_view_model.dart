import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../../../domain/models/asr_preview.dart';
import '../../../../../domain/models/meeting.dart';
import '../../../../../domain/models/recording.dart';
import '../../../../../domain/models/transcript.dart';
import '../../../../../domain/models/workflow_states.dart';
import '../../../../../domain/ports/asr_preview_session.dart';
import '../../../../../domain/ports/recording_session.dart';
import '../../../../../domain/ports/recording_telemetry.dart';
import '../../../../../domain/use_cases/manage_recording_session.dart';
import '../../../../../domain/use_cases/start_meeting.dart';

typedef RecordingTickerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

const recordingWaveformSampleCapacity = 48;
const recordingWaveformSampleInterval = Duration(milliseconds: 100);
const recordingWaveformPendingSampleCapacity = 5;

final class RecordingSessionViewModel extends ChangeNotifier {
  RecordingSessionViewModel({
    required StartedMeetingSession session,
    required this.recording,
    required this.preview,
    required this.sessionLifecycle,
    this.telemetry = const NoopRecordingTelemetryGate(),
    RecordingTickerFactory? tickerFactory,
    RecordingTickerFactory? audioLevelTickerFactory,
  }) : _meeting = session.meeting,
       _tickerFactory = tickerFactory ?? Timer.periodic,
       _audioLevelTickerFactory = audioLevelTickerFactory ?? Timer.periodic,
       _previewMetrics = preview.metrics {
    _segmentsView = UnmodifiableListView(_orderedSegments);
  }

  final RecordingSessionService recording;
  final AsrPreviewSession preview;
  final ManageRecordingSessionUseCase sessionLifecycle;
  final RecordingTelemetryGate telemetry;
  final RecordingTickerFactory _tickerFactory;
  final RecordingTickerFactory _audioLevelTickerFactory;

  Meeting _meeting;
  AsrPreviewMetrics _previewMetrics;
  final Map<String, TranscriptSegmentEvent> _segmentsById = {};
  final List<TranscriptSegmentEvent> _orderedSegments = [];
  late final UnmodifiableListView<TranscriptSegmentEvent> _segmentsView;
  final List<double> _audioLevels = [];
  final Queue<RecordingAudioLevel> _pendingAudioLevels = Queue();
  final ValueNotifier<Duration> durationListenable = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<List<double>> audioLevelsListenable = ValueNotifier(
    const [],
  );
  final ChangeNotifier transcriptListenable = ChangeNotifier();
  StreamSubscription<TranscriptEvent>? _eventSubscription;
  StreamSubscription<AsrPreviewMetrics>? _metricsSubscription;
  StreamSubscription<RecordingAudioLevel>? _audioLevelSubscription;
  Timer? _ticker;
  Timer? _audioLevelTicker;
  Duration? _latestAudioLevelCapturedThrough;
  String? _errorMessage;
  bool _isBusy = false;
  bool _isFinalizing = false;
  bool _disposed = false;

  Meeting get meeting => _meeting;
  RecordingState get recordingState => recording.state;
  AsrPreviewMetrics get previewMetrics => _previewMetrics;
  Duration get duration => durationListenable.value;
  List<double> get audioLevels => audioLevelsListenable.value;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;
  bool get isFinalizing => _isFinalizing;
  bool get canPause => !_isBusy && recordingState == RecordingState.recording;
  bool get canResume => !_isBusy && recordingState == RecordingState.paused;
  bool get canStop => !_isBusy && recording.canFinalize;

  List<TranscriptSegmentEvent> get segments => _segmentsView;

  Future<bool> start() async {
    if (_isBusy || recordingState != RecordingState.idle) {
      return recordingState == RecordingState.recording;
    }
    _subscribePreview();
    _setBusy(true);
    telemetry.setRecordingActive(true);
    try {
      await sessionLifecycle.start(_meeting);
      refreshDuration();
      _ticker = _tickerFactory(
        const Duration(milliseconds: 250),
        (_) => refreshDuration(),
      );
      unawaited(_initializePreview());
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
      if (recordingState != RecordingState.recording &&
          recordingState != RecordingState.paused) {
        telemetry.setRecordingActive(false);
      }
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
    if (recordingState == RecordingState.paused) {
      _pendingAudioLevels.clear();
    }
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
    _pendingAudioLevels.clear();
    try {
      _meeting = await sessionLifecycle.finish(_meeting);
      durationListenable.value = Duration(
        milliseconds: _meeting.audioDurationMs,
      );
      await _detachPreviewSubscriptions();
      unawaited(_disposePreviewBestEffort());
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
      if (recordingState != RecordingState.recording &&
          recordingState != RecordingState.paused) {
        telemetry.setRecordingActive(false);
      }
      _isFinalizing = false;
      _setBusy(false);
    }
  }

  void refreshDuration() {
    if (_disposed) {
      return;
    }
    durationListenable.value = recording.duration;
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
      if (_disposed) {
        return;
      }
      final latest = _latestAudioLevelCapturedThrough;
      if (latest != null && sample.capturedThrough <= latest) {
        return;
      }
      _latestAudioLevelCapturedThrough = sample.capturedThrough;
      _pendingAudioLevels.addLast(sample);
      while (_pendingAudioLevels.length >
          recordingWaveformPendingSampleCapacity) {
        _pendingAudioLevels.removeFirst();
      }
    });
    _audioLevelTicker ??= _audioLevelTickerFactory(
      recordingWaveformSampleInterval,
      (_) => _publishNextAudioLevel(),
    );
    _eventSubscription ??= preview.events.listen((event) {
      if (event case final TranscriptSegmentEvent segment) {
        _upsertSegment(segment);
      }
    });
    _metricsSubscription ??= preview.metricsChanges.listen((metrics) {
      if (_disposed) {
        return;
      }
      final previous = _previewMetrics;
      _previewMetrics = metrics;
      if (previous.state != metrics.state ||
          previous.lastErrorCode != metrics.lastErrorCode) {
        transcriptListenable.notifyListeners();
      }
    });
  }

  void _publishNextAudioLevel() {
    if (_disposed ||
        recordingState != RecordingState.recording ||
        _pendingAudioLevels.isEmpty) {
      return;
    }
    final sample = _pendingAudioLevels.removeFirst();
    _audioLevels.add(sample.level);
    final overflow = _audioLevels.length - recordingWaveformSampleCapacity;
    if (overflow > 0) {
      _audioLevels.removeRange(0, overflow);
    }
    audioLevelsListenable.value = List.unmodifiable(_audioLevels);
  }

  void _upsertSegment(TranscriptSegmentEvent segment) {
    if (_disposed) {
      return;
    }
    if (_segmentsById.containsKey(segment.segmentId)) {
      _orderedSegments.removeWhere(
        (candidate) => candidate.segmentId == segment.segmentId,
      );
    }
    _segmentsById[segment.segmentId] = segment;
    var low = 0;
    var high = _orderedSegments.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (_compareSegments(_orderedSegments[middle], segment) <= 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    _orderedSegments.insert(low, segment);
    transcriptListenable.notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    _notify();
  }

  Future<void> _initializePreview() async {
    try {
      await preview.initialize();
    } on Object {
      // 预览初始化失败只降级实时转录，事实录音继续运行。
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _detachPreviewSubscriptions() async {
    _audioLevelTicker?.cancel();
    _audioLevelTicker = null;
    _pendingAudioLevels.clear();
    await _audioLevelSubscription?.cancel();
    await _eventSubscription?.cancel();
    await _metricsSubscription?.cancel();
    _audioLevelSubscription = null;
    _eventSubscription = null;
    _metricsSubscription = null;
  }

  Future<void> _disposePreview() async {
    await _detachPreviewSubscriptions();
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
    _audioLevelTicker?.cancel();
    _pendingAudioLevels.clear();
    if (recordingState != RecordingState.recording &&
        recordingState != RecordingState.paused) {
      unawaited(_disposePreviewBestEffort());
    } else {
      unawaited(_audioLevelSubscription?.cancel());
      unawaited(_eventSubscription?.cancel());
      unawaited(_metricsSubscription?.cancel());
    }
    durationListenable.dispose();
    audioLevelsListenable.dispose();
    transcriptListenable.dispose();
    super.dispose();
  }
}

int _compareSegments(
  TranscriptSegmentEvent left,
  TranscriptSegmentEvent right,
) {
  final byStart = left.startMs.compareTo(right.startMs);
  return byStart != 0 ? byStart : left.segmentId.compareTo(right.segmentId);
}
