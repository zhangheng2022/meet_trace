import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../../domain/models/asr_preview.dart';
import '../../../domain/models/recording.dart';
import '../../../domain/models/transcript.dart';
import '../../../domain/use_cases/plan_asr_preview_windows.dart';
import '../audio/recording_ports.dart';
import '../vad/voice_activity_segmenter.dart';
import 'asr_engine.dart';
import 'asr_preview_session.dart';

export 'asr_preview_session.dart';

const defaultMaximumQueuedPreviewAudioMs = 30000;
const defaultPreviewHighWaterMs = 15000;
const defaultPreviewLowWaterMs = 5000;
const _timelineRetentionMs = 20000;

final class AsrPreviewCoordinator
    implements RecordingPreviewSink, AsrPreviewSession {
  AsrPreviewCoordinator({
    required this.vad,
    required this.engine,
    this.planner = const AsrPreviewWindowPlanner(),
    this.maximumQueuedAudioMs = defaultMaximumQueuedPreviewAudioMs,
    this.highWaterMs = defaultPreviewHighWaterMs,
    this.lowWaterMs = defaultPreviewLowWaterMs,
  }) {
    if (vad.sampleRate != recordingSampleRate ||
        planner.sampleRate != recordingSampleRate) {
      throw ArgumentError('录音、VAD 与 ASR 预览必须统一使用 16 kHz');
    }
    if (maximumQueuedAudioMs <= 0 ||
        highWaterMs <= 0 ||
        highWaterMs > maximumQueuedAudioMs ||
        lowWaterMs < 0 ||
        lowWaterMs >= highWaterMs) {
      throw ArgumentError('预览队列水位参数无效');
    }
    _engineEvents = engine.events.listen(_handleEngineEvent);
  }

  final VoiceActivitySegmenter vad;
  final AsrEngine engine;
  final AsrPreviewWindowPlanner planner;
  final int maximumQueuedAudioMs;
  final int highWaterMs;
  final int lowWaterMs;

  final Queue<AsrPreviewWindow> _pending = Queue<AsrPreviewWindow>();
  final _TimelineSampleBuffer _timeline = _TimelineSampleBuffer();
  final Map<String, Queue<_WindowReference>> _windowReferences = {};
  final Map<String, _TranscriptGroup> _transcriptGroups = {};
  final StreamController<TranscriptEvent> _events =
      StreamController<TranscriptEvent>.broadcast(sync: true);
  final StreamController<AsrPreviewMetrics> _metricsChanges =
      StreamController<AsrPreviewMetrics>.broadcast(sync: true);

  late final StreamSubscription<TranscriptEvent> _engineEvents;
  Future<void>? _draining;
  AsrPreviewWindow? _active;
  AsrPreviewState _state = AsrPreviewState.ready;
  int? _expectedNextSample;
  int _nextSegmentSequence = 0;
  int _vadSegmentCount = 0;
  int _queuedAudioMs = 0;
  int _processedPreviewWindows = 0;
  int _droppedPreviewWindows = 0;
  int _latestWindowEndMs = 0;
  int _coveredThroughMs = 0;
  String? _lastErrorCode;

  @override
  Stream<TranscriptEvent> get events => _events.stream;
  @override
  Stream<AsrPreviewMetrics> get metricsChanges => _metricsChanges.stream;

  @override
  AsrPreviewMetrics get metrics => AsrPreviewMetrics(
    state: _state,
    vadSegmentCount: _vadSegmentCount,
    queuedAudioMs: _queuedAudioMs,
    processedPreviewWindows: _processedPreviewWindows,
    droppedPreviewWindows: _droppedPreviewWindows,
    previewLagMs: (_latestWindowEndMs - _coveredThroughMs).clamp(
      0,
      _latestWindowEndMs,
    ),
    lastErrorCode: _lastErrorCode,
  );

  @override
  Future<void> add(RecordingPcmChunk chunk) async {
    if (_state == AsrPreviewState.recordingOnly ||
        _state == AsrPreviewState.disposed) {
      return;
    }
    try {
      final startSample = chunk.startByteOffset ~/ recordingBytesPerSample;
      final samples = _decodePcm16(chunk.bytes);
      final expected = _expectedNextSample;
      if (expected != null && expected != startSample) {
        await vad.reset(nextStartSample: startSample);
        _timeline.reset(startSample: startSample);
        _dropAllPending();
      } else if (_timeline.isEmpty) {
        _timeline.reset(startSample: startSample);
      }
      _timeline.append(startSample: startSample, samples: samples);
      _expectedNextSample = startSample + samples.length;
      _acceptSegments(await vad.accept(samples));
      _trimTimeline();
    } on Object catch (error) {
      _enterRecordingOnly(
        error is AsrEngineException
            ? error.failure.code
            : 'asr.preview.vad_failed',
      );
    }
  }

  @override
  Future<void> flush() async {
    if (_state == AsrPreviewState.recordingOnly ||
        _state == AsrPreviewState.disposed) {
      return;
    }
    try {
      _acceptSegments(await vad.flush());
      await _draining;
    } on Object catch (error) {
      _enterRecordingOnly(
        error is AsrEngineException
            ? error.failure.code
            : 'asr.preview.flush_failed',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_state == AsrPreviewState.disposed) {
      return;
    }
    _state = AsrPreviewState.disposed;
    _dropAllPending();
    engine.cancel();
    await _draining;
    await vad.dispose();
    await _engineEvents.cancel();
    await engine.dispose();
    _emitMetrics();
    await _events.close();
    await _metricsChanges.close();
  }

  void _acceptSegments(List<VadSpeechSegment> segments) {
    for (final segment in segments) {
      _vadSegmentCount++;
      final intervals = planner(
        segment: segment,
        availableStartSample: _timeline.startSample,
        availableEndSample: _timeline.endSample,
      );
      final groupId =
          'vad-${++_nextSegmentSequence}-${segment.startSample}-${segment.endSample}';
      final group = _TranscriptGroup(
        groupId: groupId,
        startMs: intervals.first.startSample * 1000 ~/ recordingSampleRate,
        windowCount: intervals.length,
      );
      _transcriptGroups[groupId] = group;
      for (var index = 0; index < intervals.length; index++) {
        final interval = intervals[index];
        final window = AsrPreviewWindow(
          groupId: groupId,
          windowIndex: index,
          windowCount: intervals.length,
          startSample: interval.startSample,
          endSample: interval.endSample,
          sampleRate: recordingSampleRate,
          samples: _timeline.read(
            startSample: interval.startSample,
            endSample: interval.endSample,
          ),
        );
        _registerWindow(window);
        _offer(window);
      }
    }
    _emitMetrics();
  }

  void _offer(AsrPreviewWindow window) {
    _latestWindowEndMs = _max(_latestWindowEndMs, window.endMs);
    while (_queuedAudioMs + window.audioDurationMs > maximumQueuedAudioMs &&
        _pending.isNotEmpty) {
      _dropWindow(_pending.removeFirst());
    }
    if (_queuedAudioMs + window.audioDurationMs > maximumQueuedAudioMs) {
      _dropWindow(window, wasQueued: false);
      return;
    }

    _pending.addLast(window);
    _queuedAudioMs += window.audioDurationMs;
    if (_queuedAudioMs >= highWaterMs) {
      _state = AsrPreviewState.backlogged;
    }
    _startDraining();
  }

  void _startDraining() {
    if (_draining != null ||
        _pending.isEmpty ||
        _state == AsrPreviewState.recordingOnly ||
        _state == AsrPreviewState.disposed) {
      return;
    }
    final operation = _drain();
    _draining = operation;
    unawaited(
      operation.whenComplete(() {
        _draining = null;
        if (_pending.isNotEmpty &&
            _state != AsrPreviewState.recordingOnly &&
            _state != AsrPreviewState.disposed) {
          _startDraining();
        }
      }),
    );
  }

  Future<void> _drain() async {
    while (_pending.isNotEmpty &&
        _state != AsrPreviewState.recordingOnly &&
        _state != AsrPreviewState.disposed) {
      final window = _pending.removeFirst();
      _active = window;
      var processed = false;
      try {
        await engine.acceptAudio(
          window.samples,
          sampleRate: window.sampleRate,
          startMs: window.startMs,
        );
        processed = true;
        if (_removeWindowReference(window)) {
          _markWindowFinished(window.groupId);
        }
        _processedPreviewWindows++;
        _coveredThroughMs = _max(_coveredThroughMs, window.endMs);
      } on AsrEngineException catch (error) {
        _enterRecordingOnly(error.failure.code);
      } on Object {
        _enterRecordingOnly('asr.preview.engine_failed');
      } finally {
        _active = null;
        _queuedAudioMs -= window.audioDurationMs;
        if (!processed) {
          _removeWindowReference(window);
          _markWindowFinished(window.groupId);
        }
        if (_state == AsrPreviewState.backlogged &&
            _queuedAudioMs <= lowWaterMs) {
          _state = AsrPreviewState.ready;
        }
        _emitMetrics();
      }
    }
  }

  void _dropWindow(AsrPreviewWindow window, {bool wasQueued = true}) {
    if (wasQueued && !identical(window, _active)) {
      _queuedAudioMs -= window.audioDurationMs;
    }
    _droppedPreviewWindows++;
    _coveredThroughMs = _max(_coveredThroughMs, window.endMs);
    _removeWindowReference(window);
    _markWindowFinished(window.groupId);
  }

  void _dropAllPending() {
    while (_pending.isNotEmpty) {
      _dropWindow(_pending.removeFirst());
    }
  }

  void _enterRecordingOnly(String errorCode) {
    if (_state == AsrPreviewState.disposed) {
      return;
    }
    _state = AsrPreviewState.recordingOnly;
    _lastErrorCode = errorCode;
    _dropAllPending();
    _emitMetrics();
  }

  void _registerWindow(AsrPreviewWindow window) {
    final key = _windowKey(window.startMs, window.endMs);
    (_windowReferences[key] ??= Queue<_WindowReference>()).addLast(
      _WindowReference(window),
    );
  }

  bool _removeWindowReference(AsrPreviewWindow window) {
    final key = _windowKey(window.startMs, window.endMs);
    final references = _windowReferences[key];
    if (references == null) {
      return false;
    }
    final previousLength = references.length;
    references.removeWhere(
      (reference) =>
          reference.window.groupId == window.groupId &&
          reference.window.windowIndex == window.windowIndex,
    );
    if (references.isEmpty) {
      _windowReferences.remove(key);
    }
    return references.length != previousLength;
  }

  void _handleEngineEvent(TranscriptEvent event) {
    if (event is! TranscriptSegmentEvent) {
      _events.add(event);
      return;
    }
    final key = _windowKey(event.startMs, event.endMs);
    final references = _windowReferences[key];
    if (references == null || references.isEmpty) {
      _events.add(event);
      return;
    }
    final reference = references.removeFirst();
    if (references.isEmpty) {
      _windowReferences.remove(key);
    }
    final group = _transcriptGroups[reference.window.groupId];
    if (group == null) {
      _events.add(event);
      return;
    }
    group.texts[reference.window.windowIndex] = event.text;
    group.endMs = _max(group.endMs, event.endMs);
    group.remainingWindows--;
    var merged = '';
    for (var index = 0; index < group.windowCount; index++) {
      final text = group.texts[index];
      if (text != null) {
        merged = mergeOverlappingTranscriptText(merged, text);
      }
    }
    _events.add(
      TranscriptSegmentEvent(
        segmentId: group.groupId,
        startMs: group.startMs,
        endMs: group.endMs,
        text: merged,
        modelId: event.modelId,
        modelVersion: event.modelVersion,
        isFinalForWindow: group.remainingWindows == 0,
      ),
    );
    if (group.remainingWindows == 0) {
      _transcriptGroups.remove(group.groupId);
    }
  }

  void _markWindowFinished(String groupId) {
    final group = _transcriptGroups[groupId];
    if (group == null) {
      return;
    }
    group.remainingWindows--;
    if (group.remainingWindows == 0) {
      _transcriptGroups.remove(groupId);
    }
  }

  void _trimTimeline() {
    final retentionSamples =
        _timelineRetentionMs *
        recordingSampleRate ~/
        Duration.millisecondsPerSecond;
    _timeline.trimBefore(_timeline.endSample - retentionSamples);
  }

  void _emitMetrics() {
    if (!_metricsChanges.isClosed) {
      _metricsChanges.add(metrics);
    }
  }
}

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

  void append({required int startSample, required Float32List samples}) {
    if (samples.isEmpty) {
      return;
    }
    if (startSample != _endSample) {
      throw StateError('预览音频时间轴不连续');
    }
    _blocks.addLast(
      _TimelineSampleBlock(
        startSample: startSample,
        samples: Float32List.fromList(samples),
      ),
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

final class _WindowReference {
  const _WindowReference(this.window);

  final AsrPreviewWindow window;
}

final class _TranscriptGroup {
  _TranscriptGroup({
    required this.groupId,
    required this.startMs,
    required this.windowCount,
  });

  final String groupId;
  final int startMs;
  final int windowCount;
  final Map<int, String> texts = {};
  late int remainingWindows = windowCount;
  int endMs = 0;
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

String _windowKey(int startMs, int endMs) => '$startMs:$endMs';

int _max(int left, int right) => left > right ? left : right;
int _min(int left, int right) => left < right ? left : right;
