import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/repository_contracts.dart';
import '../../../../data/services/asr/asr_preview_session.dart';
import '../../../../data/services/audio/recording_session_service.dart';
import '../../../../domain/models/asr_preview.dart';
import '../../../../domain/models/meeting.dart';
import '../../../../domain/models/transcript.dart';
import '../../../../domain/models/workflow_states.dart';
import 'start_meeting_view_model.dart';

typedef RecordingTickerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

final class RecordingSessionViewModel extends ChangeNotifier {
  RecordingSessionViewModel({
    required StartedMeetingSession session,
    required this.meetings,
    required this.recording,
    required this.preview,
    required this.now,
    RecordingTickerFactory? tickerFactory,
  }) : _meeting = session.meeting,
       _tickerFactory = tickerFactory ?? Timer.periodic,
       _previewMetrics = preview.metrics;

  final MeetingRepository meetings;
  final RecordingSessionService recording;
  final AsrPreviewSession preview;
  final DateTime Function() now;
  final RecordingTickerFactory _tickerFactory;

  Meeting _meeting;
  AsrPreviewMetrics _previewMetrics;
  final Map<String, TranscriptSegmentEvent> _segments = {};
  StreamSubscription<TranscriptEvent>? _eventSubscription;
  StreamSubscription<AsrPreviewMetrics>? _metricsSubscription;
  Timer? _ticker;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  bool _isBusy = false;
  bool _disposed = false;

  Meeting get meeting => _meeting;
  RecordingState get recordingState => recording.state;
  AsrPreviewMetrics get previewMetrics => _previewMetrics;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;
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
      await recording.start(meetingId: _meeting.id);
      refreshDuration();
      _ticker = _tickerFactory(
        const Duration(milliseconds: 250),
        (_) => refreshDuration(),
      );
      return true;
    } on Object catch (error) {
      await _failMeeting(_errorCode(error));
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
    _setBusy(true);
    _ticker?.cancel();
    try {
      final artifact = await recording.stop();
      await _flushPreviewBestEffort();
      _duration = artifact.duration;
      _meeting = _meeting.finishRecording(
        endedAt: now(),
        audioPath: artifact.audioPath,
        audioDurationMs: artifact.duration.inMilliseconds,
      );
      await meetings.save(_meeting);
      await _disposePreviewBestEffort();
      return _meeting;
    } on Object catch (error) {
      await _failMeeting(_errorCode(error));
      _errorMessage = '音频封存失败，请保留应用数据并重试恢复';
      await _disposePreviewBestEffort();
      return null;
    } finally {
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

  Future<void> _failMeeting(String errorCode) async {
    if (_meeting.status != MeetingState.failed) {
      _meeting = _meeting.fail(errorCode: errorCode, endedAt: now());
      await meetings.save(_meeting);
    }
  }

  String _errorCode(Object error) {
    return error is ReliableRecordingException
        ? error.code
        : 'recording.unexpected';
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
    await _eventSubscription?.cancel();
    await _metricsSubscription?.cancel();
    _eventSubscription = null;
    _metricsSubscription = null;
    await preview.dispose();
  }

  Future<void> _flushPreviewBestEffort() async {
    try {
      await preview.flush();
    } on Object {
      // 会中预览是派生数据，失败不得改变事实音频封存结果。
    }
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
      unawaited(_eventSubscription?.cancel());
      unawaited(_metricsSubscription?.cancel());
    }
    super.dispose();
  }
}
