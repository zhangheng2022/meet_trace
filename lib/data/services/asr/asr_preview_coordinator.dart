import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../../domain/models/asr_preview.dart';
import '../../../domain/models/recording.dart';
import '../../../domain/models/transcript.dart';
import '../../../domain/ports/asr_engine.dart';
import '../../../domain/ports/asr_preview_session.dart';
import '../../../domain/use_cases/plan_asr_preview_windows.dart';
import '../audio/recording_ports.dart';
import '../vad/silero_vad_segmenter.dart';

const defaultMaximumQueuedPreviewAudioMs = 30000;
const defaultPreviewHighWaterMs = 15000;
const defaultPreviewLowWaterMs = 5000;
const defaultPreviewStopTimeout = Duration(milliseconds: 500);
const defaultPreviewPartialInterval = Duration(seconds: 2);
const _timelineRetentionMs = 20000;
const _speechStartPrerollMs = 500;

/// 本地基准可订阅这些匿名阶段时长；不自动上传，也不含识别文本。
final class AsrPreviewObservation {
  const AsrPreviewObservation({
    required this.audioStartMs,
    required this.audioEndMs,
    required this.isStable,
    required this.queueWait,
    required this.inference,
    required this.wasPublished,
  });

  final int audioStartMs;
  final int audioEndMs;
  final bool isStable;
  final Duration queueWait;
  final Duration inference;
  final bool wasPublished;
}

final class AsrPreviewCoordinator
    implements RecordingPreviewSink, AsrPreviewSession {
  AsrPreviewCoordinator({
    required this.vad,
    required this.engine,
    this.planner = const AsrPreviewWindowPlanner(),
    this.maximumQueuedAudioMs = defaultMaximumQueuedPreviewAudioMs,
    this.highWaterMs = defaultPreviewHighWaterMs,
    this.lowWaterMs = defaultPreviewLowWaterMs,
    this.stopTimeout = defaultPreviewStopTimeout,
    this.partialInterval = defaultPreviewPartialInterval,
    this.onObservation,
  }) {
    if (vad.sampleRate != recordingSampleRate ||
        planner.sampleRate != recordingSampleRate) {
      throw ArgumentError('录音、VAD 与 ASR 预览必须统一使用 16 kHz');
    }
    if (maximumQueuedAudioMs <= 0 ||
        highWaterMs <= 0 ||
        highWaterMs > maximumQueuedAudioMs ||
        lowWaterMs < 0 ||
        lowWaterMs >= highWaterMs ||
        stopTimeout <= Duration.zero ||
        partialInterval <= Duration.zero ||
        planner.maximumWindowMs > asrPreviewMaximumWindowMs ||
        planner.maximumWindowMs <=
            planner.contextBeforeMs +
                planner.contextAfterMs +
                _speechStartPrerollMs) {
      throw ArgumentError('预览队列或窗口参数无效');
    }
    _engineEvents = engine.events.listen(_handleEngineEvent);
  }

  final VoiceActivitySegmenter vad;
  final AsrEngine engine;
  final AsrPreviewWindowPlanner planner;
  final int maximumQueuedAudioMs;
  final int highWaterMs;
  final int lowWaterMs;
  final Duration stopTimeout;
  final Duration partialInterval;
  final void Function(AsrPreviewObservation)? onObservation;

  final Queue<_PreviewJob> _pending = Queue<_PreviewJob>();
  final _TimelineSampleBuffer _timeline = _TimelineSampleBuffer();
  final Map<String, _TranscriptGroup> _groups = {};
  final Stopwatch _clock = Stopwatch()..start();
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final StreamController<AsrPreviewMetrics> _metricsChanges =
      StreamController<AsrPreviewMetrics>.broadcast(sync: true);
  late final StreamSubscription<TranscriptEvent> _engineEvents;

  Future<void>? _draining;
  Future<void>? _initializeOperation;
  Future<void>? _stopOperation;
  Future<void>? _disposeOperation;
  Future<void>? _engineDisposal;
  _PreviewJob? _active;
  _LiveSpeech? _speech;
  AsrPreviewState _state = AsrPreviewState.ready;
  int? _expectedNextSample;
  int _nextSegmentSequence = 0;
  int _vadSegmentCount = 0;
  int _queuedAudioMs = 0;
  int _processedPreviewWindows = 0;
  int _droppedPreviewWindows = 0;
  int _receivedThroughMs = 0;
  int _recognizedThroughMs = 0;
  int _lastInferenceMs = 0;
  int _coalescedPartialWindows = 0;
  int _missingInputSamples = 0;
  String? _lastErrorCode;
  bool _initialized = false;

  @override
  Stream<TranscriptEvent> get events => _events.stream;
  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _metricsChanges.stream;

  int get coalescedPartialWindows => _coalescedPartialWindows;
  int get missingInputSamples => _missingInputSamples;
  bool get isRecognizing => _active != null;

  @override
  AsrPreviewMetrics get metrics => AsrPreviewMetrics(
    state: _state,
    vadSegmentCount: _vadSegmentCount,
    // 只报告等待中的音频；当前正在解码的一窗不是排队积压。
    queuedAudioMs: _queuedAudioMs,
    processedPreviewWindows: _processedPreviewWindows,
    droppedPreviewWindows: _droppedPreviewWindows,
    isRecognizing: !_isStopped && isRecognizing,
    // 音频新鲜度包含尚未结束的语音，丢弃任务绝不算已经识别。
    previewLagMs: (_receivedThroughMs - _recognizedThroughMs).clamp(
      0,
      _receivedThroughMs,
    ),
    lastErrorCode: _lastErrorCode,
  );

  bool get _isStopped =>
      _state == AsrPreviewState.recordingOnly ||
      _state == AsrPreviewState.disposed;

  @override
  Future<void> initialize() => _initializeOperation ??= _initialize();

  Future<void> _initialize() async {
    if (_isStopped) return;
    try {
      await engine.initialize();
      if (!_isStopped) {
        _initialized = true;
        _startDraining();
      }
    } on Object catch (error) {
      _enterRecordingOnly(
        error is AsrEngineException
            ? error.failure.code
            : 'asr.preview.initialize_failed',
      );
    }
  }

  @override
  Future<void> add(RecordingPcmChunk chunk) {
    if (_isStopped) return Future<void>.value();
    try {
      final startSample = chunk.startByteOffset ~/ recordingBytesPerSample;
      final expected = _expectedNextSample;
      if (expected != null && expected != startSample) {
        _missingInputSamples += (startSample - expected).abs();
        _dropAllPending();
        _clearUnstableSpeech();
        _groups.clear(); // 当前推理的旧分组失效，迟到结果不能重新出现在 UI。
        vad.reset(nextStartSample: startSample);
        _timeline.reset(startSample: startSample);
      } else if (_timeline.isEmpty) {
        vad.reset(nextStartSample: startSample);
        _timeline.reset(startSample: startSample);
      }
      final samples = _decodePcm16(chunk.bytes);
      var offset = 0;
      while (offset < samples.length) {
        final cursor = startSample + offset;
        var length = _min(recordingSampleRate, samples.length - offset);
        final speech = _speech;
        if (speech != null) {
          final remaining = _hardSpeechEnd(speech) - cursor;
          if (remaining <= 0) {
            _flushSpeech();
            continue;
          }
          length = _min(length, remaining);
        }
        final block = Float32List.sublistView(samples, offset, offset + length);
        _timeline.appendOwned(startSample: cursor, samples: block);
        final completed = vad.accept(block);
        _receivedThroughMs = _timeline.endSample * 1000 ~/ recordingSampleRate;
        _acceptSegments(completed);
        if (vad.isSpeechDetected) {
          _speech ??= _LiveSpeech(
            id: 'vad-${++_nextSegmentSequence}',
            startSample: _max(
              _timeline.startSample,
              cursor - _speechStartPrerollMs * recordingSampleRate ~/ 1000,
            ),
          );
          if (_timeline.endSample >= _hardSpeechEnd(_speech!)) {
            _flushSpeech();
          } else {
            _offerPartial();
          }
        }
        offset += length;
        _trimTimeline();
      }
      _expectedNextSample = startSample + samples.length;
      _emitMetrics();
    } on Object catch (error) {
      _enterRecordingOnly(
        error is AsrEngineException
            ? error.failure.code
            : 'asr.preview.vad_failed',
      );
    }
    return Future<void>.value();
  }

  int _hardSpeechEnd(_LiveSpeech speech) =>
      speech.startSample +
      (planner.maximumWindowMs -
              planner.contextBeforeMs -
              planner.contextAfterMs) *
          recordingSampleRate ~/
          1000;

  @override
  Future<void> flush() async {
    if (_isStopped || _timeline.isEmpty) return;
    try {
      _flushSpeech();
      // 暂停只提交尾句，不等待可丢弃的推理积压。
    } on Object catch (error) {
      _enterRecordingOnly(
        error is AsrEngineException
            ? error.failure.code
            : 'asr.preview.flush_failed',
      );
    }
  }

  void _flushSpeech() {
    _acceptSegments(vad.flush());
    _clearUnstableSpeech();
    vad.reset(nextStartSample: _timeline.endSample);
  }

  void _offerPartial() {
    final speech = _speech!;
    final end = _timeline.endSample;
    final intervalMs = _max(
      partialInterval.inMilliseconds,
      _lastInferenceMs * 2,
    );
    final earliest = speech.lastPartialEndSample == null
        ? speech.startSample +
              partialInterval.inMilliseconds * recordingSampleRate ~/ 1000
        : speech.lastPartialEndSample! +
              intervalMs * recordingSampleRate ~/ 1000;
    if (end < earliest) return;
    // 已结束的语音优先；同一活动语音只保留最新一个临时请求。
    final group = _TranscriptGroup(
      id: speech.id,
      startMs: speech.startSample * 1000 ~/ recordingSampleRate,
      windowCount: 1,
      stable: false,
    );
    _replaceGroup(group);
    _offer(
      _PreviewJob(
        group: group,
        window: AsrPreviewWindow(
          groupId: group.id,
          windowIndex: 0,
          windowCount: 1,
          startSample: speech.startSample,
          endSample: end,
          sampleRate: recordingSampleRate,
          samples: _timeline.read(
            startSample: speech.startSample,
            endSample: end,
          ),
        ),
        offeredAt: _clock.elapsed,
      ),
    );
    speech.lastPartialEndSample = end;
  }

  void _acceptSegments(List<VadSpeechSegment> segments) {
    for (final segment in segments) {
      _vadSegmentCount++;
      final intervals = planner(
        segment: segment,
        availableStartSample: _timeline.startSample,
        availableEndSample: _timeline.endSample,
      );
      final id = _speech?.id ?? 'vad-${++_nextSegmentSequence}';
      _speech = null;
      final group = _TranscriptGroup(
        id: id,
        startMs: segment.startSample * 1000 ~/ recordingSampleRate,
        windowCount: intervals.length,
        stable: true,
      );
      _replaceGroup(group);
      for (var index = 0; index < intervals.length; index++) {
        final interval = intervals[index];
        _offer(
          _PreviewJob(
            group: group,
            window: AsrPreviewWindow(
              groupId: id,
              windowIndex: index,
              windowCount: intervals.length,
              startSample: interval.startSample,
              endSample: interval.endSample,
              sampleRate: recordingSampleRate,
              samples: _timeline.read(
                startSample: interval.startSample,
                endSample: interval.endSample,
              ),
            ),
            offeredAt: _clock.elapsed,
          ),
        );
      }
    }
  }

  void _replaceGroup(_TranscriptGroup group) {
    final previous = _groups[group.id];
    group.hadText = previous?.hadText ?? false;
    _groups[group.id] = group;
    for (final job
        in _pending.where((job) => job.group.id == group.id).toList()) {
      _pending.remove(job);
      _queuedAudioMs -= job.window.audioDurationMs;
      _coalescedPartialWindows++;
    }
  }

  void _offer(_PreviewJob job) {
    final outstanding = _active?.window.audioDurationMs ?? 0;
    while (_queuedAudioMs + outstanding + job.window.audioDurationMs >
            maximumQueuedAudioMs &&
        _pending.isNotEmpty) {
      final partial = _pending
          .where((pending) => !pending.group.stable)
          .firstOrNull;
      // 新临时请求不能挤掉闭段任务；稳定请求先淘汰可替换的临时窗。
      if (partial == null && !job.group.stable) break;
      final victim = partial ?? _pending.first;
      _pending.remove(victim);
      _dropJob(victim);
    }
    if (_queuedAudioMs + outstanding + job.window.audioDurationMs >
        maximumQueuedAudioMs) {
      _dropJob(job, wasQueued: false);
      return;
    }
    if (job.group.stable) {
      final firstPartial = _pending
          .where((pending) => !pending.group.stable)
          .firstOrNull;
      if (firstPartial != null) {
        _pending.remove(firstPartial);
        _pending.addLast(job);
        _pending.addLast(firstPartial);
      } else {
        _pending.addLast(job);
      }
    } else {
      _pending.addLast(job);
    }
    _queuedAudioMs += job.window.audioDurationMs;
    _startDraining();
    _updateQueueState();
  }

  void _startDraining() {
    if (_draining != null || !_initialized || _pending.isEmpty || _isStopped) {
      return;
    }
    final operation = _drain();
    _draining = operation;
    unawaited(
      operation.whenComplete(() {
        _draining = null;
        if (_pending.isNotEmpty && !_isStopped) _startDraining();
      }),
    );
  }

  Future<void> _drain() async {
    while (_pending.isNotEmpty && !_isStopped) {
      final job = _pending.removeFirst();
      _queuedAudioMs -= job.window.audioDurationMs;
      _active = job;
      _updateQueueState();
      _emitMetrics();
      final startedAt = _clock.elapsed;
      var published = false;
      try {
        await engine.acceptAudio(
          job.window.samples,
          sampleRate: job.window.sampleRate,
          startMs: job.window.startMs,
        );
        _processedPreviewWindows++;
        if (!_isStopped && identical(_groups[job.group.id], job.group)) {
          _recognizedThroughMs = _max(_recognizedThroughMs, job.window.endMs);
          job.group.texts[job.window.windowIndex] = job.text ?? '';
          job.group.endMs = _max(job.group.endMs, job.window.endMs);
          job.group.remainingWindows--;
          published = _publishGroup(job.group);
        }
      } on Object catch (error) {
        _enterRecordingOnly(
          error is AsrEngineException
              ? error.failure.code
              : 'asr.preview.engine_failed',
        );
      } finally {
        final inference = _clock.elapsed - startedAt;
        _lastInferenceMs = inference.inMilliseconds;
        _active = null;
        try {
          onObservation?.call(
            AsrPreviewObservation(
              audioStartMs: job.window.startMs,
              audioEndMs: job.window.endMs,
              isStable: job.group.stable,
              queueWait: startedAt - job.offeredAt,
              inference: inference,
              wasPublished: published,
            ),
          );
        } on Object {
          // 基准观测失败不得影响预览或事实录音。
        }
        _updateQueueState();
        _emitMetrics();
      }
    }
  }

  void _handleEngineEvent(TranscriptEvent event) {
    if (_isStopped) return;
    if (event is! TranscriptSegmentEvent) {
      _events.add(event);
      return;
    }
    final job = _active;
    if (job != null &&
        event.startMs == job.window.startMs &&
        event.endMs == _engineWindowEndMs(job.window)) {
      job.text = event.text;
    }
  }

  bool _publishGroup(_TranscriptGroup group) {
    var merged = '';
    for (var index = 0; index < group.windowCount; index++) {
      merged = mergeOverlappingTranscriptText(merged, group.texts[index] ?? '');
    }
    final finished = group.stable && group.remainingWindows == 0;
    final publish = merged.isNotEmpty || (finished && group.hadText);
    if (publish) {
      _events.add(
        TranscriptSegmentEvent(
          segmentId: group.id,
          startMs: group.startMs,
          endMs: _max(group.startMs + 1, group.endMs),
          text: merged,
          modelId: engine.descriptor.modelId,
          modelVersion: engine.descriptor.version,
          isFinalForWindow: finished,
        ),
      );
      group.hadText = merged.isNotEmpty;
    }
    if (finished) _groups.remove(group.id);
    return publish;
  }

  void _dropJob(_PreviewJob job, {bool wasQueued = true}) {
    if (wasQueued) _queuedAudioMs -= job.window.audioDurationMs;
    _droppedPreviewWindows++;
    if (identical(_groups[job.group.id], job.group)) {
      job.group.remainingWindows--;
      _publishGroup(job.group);
    }
  }

  void _dropAllPending() {
    while (_pending.isNotEmpty) {
      _dropJob(_pending.removeFirst());
    }
  }

  void _clearUnstableSpeech() {
    final speech = _speech;
    _speech = null;
    if (speech == null) return;
    final group = _groups.remove(speech.id);
    for (final job
        in _pending.where((job) => job.group.id == speech.id).toList()) {
      _pending.remove(job);
      _queuedAudioMs -= job.window.audioDurationMs;
      _coalescedPartialWindows++;
    }
    if (group?.hadText == true && !_events.isClosed) {
      _events.add(
        TranscriptSegmentEvent(
          segmentId: speech.id,
          startMs: group!.startMs,
          endMs: _max(group.startMs + 1, group.endMs),
          text: '',
          modelId: engine.descriptor.modelId,
          modelVersion: engine.descriptor.version,
          isFinalForWindow: true,
        ),
      );
    }
  }

  void _updateQueueState() {
    if (_isStopped) return;
    if (_queuedAudioMs >= highWaterMs) {
      _state = AsrPreviewState.backlogged;
    } else if (_queuedAudioMs <= lowWaterMs) {
      _state = AsrPreviewState.ready;
    }
  }

  void _enterRecordingOnly(String errorCode) {
    if (_state == AsrPreviewState.disposed) return;
    _state = AsrPreviewState.recordingOnly;
    _lastErrorCode = errorCode;
    _dropAllPending();
    _clearUnstableSpeech();
    _groups.clear();
    _emitMetrics();
  }

  void _trimTimeline() {
    _timeline.trimBefore(
      _timeline.endSample - _timelineRetentionMs * recordingSampleRate ~/ 1000,
    );
  }

  void _emitMetrics() {
    if (!_metricsChanges.isClosed) _metricsChanges.add(metrics);
  }

  @override
  Future<void> stop() => _stopOperation ??= _stop();

  Future<void> _stop() async {
    if (_state != AsrPreviewState.disposed) {
      _state = AsrPreviewState.disposed;
      _dropAllPending();
      _groups.clear();
      _speech = null;
      engine.cancel();
      _emitMetrics();
    }
    try {
      await _engineEvents.cancel();
    } on Object {
      /* 继续释放其余资源。 */
    }
    try {
      await _draining?.timeout(stopTimeout);
    } on Object {
      /* 不等待预览积压。 */
    }
    try {
      vad.dispose();
    } on Object {
      /* 继续释放 Engine。 */
    }
    try {
      await _events.close();
    } on Object {
      /* 继续关闭指标流。 */
    }
    try {
      await _metricsChanges.close();
    } on Object {
      /* 继续释放 Engine。 */
    }
    try {
      final disposal = engine.dispose();
      _engineDisposal ??= disposal;
      unawaited(disposal.catchError((Object _) {}));
    } on Object {
      /* 派生资源释放不得延长结束会议。 */
    }
  }

  @override
  Future<void> dispose() => _disposeOperation ??= _dispose();

  Future<void> _dispose() async {
    await stop();
    try {
      await _engineDisposal;
    } on Object {
      /* 保持释放幂等。 */
    }
  }
}

final class _LiveSpeech {
  _LiveSpeech({required this.id, required this.startSample});
  final String id;
  final int startSample;
  int? lastPartialEndSample;
}

final class _PreviewJob {
  _PreviewJob({
    required this.group,
    required this.window,
    required this.offeredAt,
  });
  final _TranscriptGroup group;
  final AsrPreviewWindow window;
  final Duration offeredAt;
  String? text;
}

final class _TranscriptGroup {
  _TranscriptGroup({
    required this.id,
    required this.startMs,
    required this.windowCount,
    required this.stable,
  });
  final String id;
  final int startMs;
  final int windowCount;
  final bool stable;
  final Map<int, String> texts = {};
  late int remainingWindows = windowCount;
  int endMs = 0;
  bool hadText = false;
}

Float32List _decodePcm16(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Float32List(bytes.length ~/ recordingBytesPerSample);
  for (var index = 0; index < samples.length; index++) {
    samples[index] =
        data.getInt16(index * recordingBytesPerSample, Endian.little) / 32768;
  }
  return samples;
}

int _engineWindowEndMs(AsrPreviewWindow window) =>
    window.startMs +
    (window.samples.length * 1000 + window.sampleRate - 1) ~/ window.sampleRate;
int _max(int left, int right) => left > right ? left : right;
int _min(int left, int right) => left < right ? left : right;

final class _TimelineSampleBuffer {
  final Queue<_TimelineSampleBlock> _blocks = Queue<_TimelineSampleBlock>();

  int _startSample = 0;
  int _endSample = 0;

  bool get isEmpty => _blocks.isEmpty;
  int get startSample => _startSample;
  int get endSample => _endSample;

  void reset({required int startSample}) {
    _blocks.clear();
    _startSample = startSample;
    _endSample = startSample;
  }

  /// 接管刚解码的样本；调用方不得在加入后继续修改该缓冲区。
  void appendOwned({required int startSample, required Float32List samples}) {
    if (samples.isEmpty) {
      return;
    }
    if (startSample != _endSample) {
      throw StateError('预览音频时间轴不连续');
    }
    _blocks.addLast(
      _TimelineSampleBlock(startSample: startSample, samples: samples),
    );
    _endSample += samples.length;
    if (_blocks.length == 1) {
      _startSample = startSample;
    }
  }

  Float32List read({required int startSample, required int endSample}) {
    if (startSample < _startSample ||
        endSample > _endSample ||
        endSample <= startSample) {
      throw StateError('请求的预览窗口不在音频缓冲区内');
    }
    final result = Float32List(endSample - startSample);
    var destinationOffset = 0;
    for (final block in _blocks) {
      final overlapStart = _max(startSample, block.startSample);
      final overlapEnd = _min(endSample, block.endSample);
      if (overlapEnd <= overlapStart) {
        continue;
      }
      final sourceStart = overlapStart - block.startSample;
      final length = overlapEnd - overlapStart;
      result.setRange(
        destinationOffset,
        destinationOffset + length,
        block.samples,
        sourceStart,
      );
      destinationOffset += length;
    }
    if (destinationOffset != result.length) {
      throw StateError('预览音频缓冲区存在缺口');
    }
    return result;
  }

  void trimBefore(int sample) {
    final target = sample.clamp(_startSample, _endSample);
    while (_blocks.isNotEmpty && _blocks.first.endSample <= target) {
      _blocks.removeFirst();
    }
    if (_blocks.isNotEmpty && _blocks.first.startSample < target) {
      final first = _blocks.removeFirst();
      final offset = target - first.startSample;
      _blocks.addFirst(
        _TimelineSampleBlock(
          startSample: target,
          samples: Float32List.fromList(first.samples.sublist(offset)),
        ),
      );
    }
    _startSample = _blocks.isEmpty ? _endSample : _blocks.first.startSample;
  }
}

final class _TimelineSampleBlock {
  const _TimelineSampleBlock({
    required this.startSample,
    required this.samples,
  });

  final int startSample;
  final Float32List samples;

  int get endSample => startSample + samples.length;
}
