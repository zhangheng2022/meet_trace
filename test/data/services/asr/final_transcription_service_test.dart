import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/repository_contracts.dart';
import 'package:meettrace/data/services/asr/asr_engine.dart';
import 'package:meettrace/data/services/asr/final_transcription_service.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';

void main() {
  late _MeetingRepository meetings;
  late _TranscriptRepository transcripts;
  late _EngineFactory engines;
  late FinalTranscriptionService service;
  final now = DateTime.utc(2026, 7, 25, 8);

  setUp(() {
    meetings = _MeetingRepository();
    transcripts = _TranscriptRepository(meetings);
    engines = _EngineFactory();
    service = FinalTranscriptionService(
      meetings: meetings,
      transcripts: transcripts,
      engineFactory: engines,
      now: () => now,
      snapshotIdFactory: (_, _) => 'snapshot-attempt-1',
    );
  });

  test('默认使用本场锁定模型读取完整事实音频并原子激活', () async {
    meetings.value = _meeting();
    engines.resultBuilder =
        ({required descriptor, required meetingId, required snapshotId}) {
          return _snapshot(
            id: snapshotId,
            meetingId: meetingId,
            descriptor: descriptor,
            createdAt: now,
          );
        };

    final result = await service.transcribe(meetingId: 'meeting-1');

    expect(engines.createCalls.single, (
      whisperBaseStandardModelId,
      'v1.9.1-q5_1',
    ));
    expect(engines.purposes, [AsrEnginePurpose.finalTranscript]);
    expect(engines.engine!.source!.path, '/audio/meeting-1.pcm');
    expect(engines.engine!.source!.durationMs, 2000);
    expect(engines.engine!.snapshotId, 'snapshot-attempt-1');
    expect(transcripts.saved.map((snapshot) => snapshot.status), [
      TranscriptSnapshotStatus.processing,
      TranscriptSnapshotStatus.complete,
    ]);
    expect(transcripts.expectedActiveIds.single, isNull);
    expect(result.meeting.status, MeetingState.completed);
    expect(result.meeting.activeTranscriptSnapshotId, 'snapshot-attempt-1');
    expect(result.snapshot.actualModelId, whisperBaseStandardModelId);
  });

  test('推理失败时保留旧活动快照、音频并保存失败尝试', () async {
    meetings.value = _meeting(
      activeTranscriptSnapshotId: 'old-snapshot',
      activeSummaryId: 'old-summary',
    );
    engines.error = StateError('推理失败');

    await expectLater(
      service.transcribe(meetingId: 'meeting-1'),
      throwsA(isA<StateError>()),
    );

    expect(meetings.value!.audioPath, '/audio/meeting-1.pcm');
    expect(meetings.value!.activeTranscriptSnapshotId, 'old-snapshot');
    expect(meetings.value!.activeSummaryId, 'old-summary');
    expect(meetings.value!.status, MeetingState.failed);
    expect(transcripts.activeSnapshotId, 'old-snapshot');
    expect(transcripts.saved.last.status, TranscriptSnapshotStatus.failed);
    expect(transcripts.saved.last.actualModelId, whisperBaseStandardModelId);
  });

  test('完整音频片段越界时拒绝激活且不混入活动快照', () async {
    meetings.value = _meeting(activeTranscriptSnapshotId: 'old-snapshot');
    engines.resultBuilder =
        ({required descriptor, required meetingId, required snapshotId}) {
          return _snapshot(
            id: snapshotId,
            meetingId: meetingId,
            descriptor: descriptor,
            createdAt: now,
            segmentEndMs: 2001,
          );
        };

    await expectLater(
      service.transcribe(meetingId: 'meeting-1'),
      throwsA(
        isA<FinalTranscriptionException>().having(
          (error) => error.code,
          'code',
          'final_transcription.segment_out_of_bounds',
        ),
      ),
    );

    expect(transcripts.activeSnapshotId, 'old-snapshot');
    expect(transcripts.saved.last.status, TranscriptSnapshotStatus.failed);
  });

  test('重新转录可显式选择另一已安装模型并生成独立快照', () async {
    meetings.value = _meeting(
      status: MeetingState.completed,
      activeTranscriptSnapshotId: 'old-snapshot',
      activeSummaryId: 'old-summary',
    );
    engines.resultBuilder =
        ({required descriptor, required meetingId, required snapshotId}) {
          return _snapshot(
            id: snapshotId,
            meetingId: meetingId,
            descriptor: descriptor,
            createdAt: now,
          );
        };
    final qwen = AsrModelRegistry.alpha.requireById(
      whisperSmallAdvancedModelId,
    );

    final result = await service.transcribe(
      meetingId: 'meeting-1',
      modelId: qwen.modelId,
      modelVersion: qwen.version,
    );

    expect(engines.createCalls.single, (qwen.modelId, qwen.version));
    expect(result.snapshot.id, 'snapshot-attempt-1');
    expect(result.snapshot.id, isNot('old-snapshot'));
    expect(result.snapshot.actualModelId, qwen.modelId);
    expect(result.meeting.activeSummaryId, isNull);
  });

  test('同一 retrySnapshotId 已激活完成时直接返回且不重复推理', () async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    final completed = _snapshot(
      id: 'retry-snapshot',
      meetingId: 'meeting-1',
      descriptor: descriptor,
      createdAt: now,
    );
    meetings.value = _meeting(
      status: MeetingState.completed,
      activeTranscriptSnapshotId: completed.id,
    );
    transcripts.records[completed.id] = completed;
    transcripts.activeSnapshotId = completed.id;

    final result = await service.transcribe(
      meetingId: 'meeting-1',
      retrySnapshotId: completed.id,
    );

    expect(result.snapshot.id, completed.id);
    expect(result.snapshot.actualModelId, whisperBaseStandardModelId);
    expect(engines.createCalls, isEmpty);
    expect(transcripts.saved, isEmpty);
  });

  test('同一会议的并发最终转录会串行执行并基于最新活动快照', () async {
    meetings.value = _meeting();
    var snapshotSequence = 0;
    var finalizeCalls = 0;
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    engines.beforeFinalize = () async {
      finalizeCalls++;
      if (finalizeCalls == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
    };
    engines.resultBuilder =
        ({required descriptor, required meetingId, required snapshotId}) {
          return _snapshot(
            id: snapshotId,
            meetingId: meetingId,
            descriptor: descriptor,
            createdAt: now,
          );
        };
    service = FinalTranscriptionService(
      meetings: meetings,
      transcripts: transcripts,
      engineFactory: engines,
      now: () => now,
      snapshotIdFactory: (_, _) => 'snapshot-${++snapshotSequence}',
    );

    final first = service.transcribe(meetingId: 'meeting-1');
    await firstStarted.future;
    final second = service.transcribe(meetingId: 'meeting-1');
    await Future<void>.delayed(Duration.zero);

    expect(engines.createCalls, hasLength(1));

    releaseFirst.complete();
    final results = await Future.wait([first, second]);

    expect(engines.createCalls, hasLength(2));
    expect(results[0].snapshot.id, 'snapshot-1');
    expect(results[1].snapshot.id, 'snapshot-2');
    expect(transcripts.expectedActiveIds, [null, 'snapshot-1']);
    expect(meetings.value!.status, MeetingState.completed);
    expect(meetings.value!.activeTranscriptSnapshotId, 'snapshot-2');
  });

  test('原子激活冲突时不会用失败状态覆盖已提交的赢家', () async {
    final descriptor = AsrModelRegistry.alpha.requireById(
      whisperBaseStandardModelId,
    );
    final winner = _snapshot(
      id: 'winner-snapshot',
      meetingId: 'meeting-1',
      descriptor: descriptor,
      createdAt: now,
    );
    meetings.value = _meeting();
    transcripts.conflictingWinner = winner;
    engines.resultBuilder =
        ({required descriptor, required meetingId, required snapshotId}) {
          return _snapshot(
            id: snapshotId,
            meetingId: meetingId,
            descriptor: descriptor,
            createdAt: now,
          );
        };

    await expectLater(
      service.transcribe(meetingId: 'meeting-1'),
      throwsA(isA<StateError>()),
    );

    expect(meetings.value!.status, MeetingState.completed);
    expect(meetings.value!.activeTranscriptSnapshotId, 'winner-snapshot');
    expect(transcripts.activeSnapshotId, 'winner-snapshot');
    expect(transcripts.saved.last.status, TranscriptSnapshotStatus.failed);
  });

  test('Engine 释放失败不覆盖已原子激活的最终转录', () async {
    meetings.value = _meeting();
    engines.disposeError = StateError('dispose failed');
    engines.resultBuilder =
        ({required descriptor, required meetingId, required snapshotId}) {
          return _snapshot(
            id: snapshotId,
            meetingId: meetingId,
            descriptor: descriptor,
            createdAt: now,
          );
        };

    final result = await service.transcribe(meetingId: 'meeting-1');

    expect(result.meeting.status, MeetingState.completed);
    expect(result.snapshot.status, TranscriptSnapshotStatus.complete);
    expect(meetings.value!.status, MeetingState.completed);
    expect(meetings.value!.activeTranscriptSnapshotId, 'snapshot-attempt-1');
  });
}

Meeting _meeting({
  MeetingState status = MeetingState.processing,
  String? activeTranscriptSnapshotId,
  String? activeSummaryId,
}) {
  return Meeting(
    id: 'meeting-1',
    title: '周会',
    createdAt: DateTime.utc(2026, 7, 25, 7),
    startedAt: DateTime.utc(2026, 7, 25, 7),
    endedAt: DateTime.utc(2026, 7, 25, 7, 0, 2),
    status: status,
    audioPath: '/audio/meeting-1.pcm',
    audioDurationMs: 2000,
    requestedModelId: whisperBaseStandardModelId,
    recordingModelId: whisperBaseStandardModelId,
    recordingModelVersion: 'v1.9.1-q5_1',
    activeTranscriptSnapshotId: activeTranscriptSnapshotId,
    activeSummaryId: activeSummaryId,
  );
}

TranscriptSnapshot _snapshot({
  required String id,
  required String meetingId,
  required AsrModelDescriptor descriptor,
  required DateTime createdAt,
  int segmentEndMs = 2000,
}) {
  return TranscriptSnapshot(
    id: id,
    meetingId: meetingId,
    kind: TranscriptSnapshotKind.finalTranscript,
    actualModelId: descriptor.modelId,
    actualModelVersion: descriptor.version,
    createdAt: createdAt,
    status: TranscriptSnapshotStatus.complete,
    segments: [
      TranscriptSegment(
        id: '$id-segment-1',
        snapshotId: id,
        startMs: 0,
        endMs: segmentEndMs,
        text: '最终事实文本',
        modelId: descriptor.modelId,
        modelVersion: descriptor.version,
      ),
    ],
  );
}

final class _MeetingRepository implements MeetingRepository {
  Meeting? value;

  @override
  Future<Meeting?> getById(String meetingId) async =>
      value?.id == meetingId ? value : null;

  @override
  Stream<List<Meeting>> watchAll() => Stream.value([?value]);

  @override
  Future<void> save(Meeting meeting) async {
    value = meeting;
  }

  @override
  Future<void> delete(String meetingId) async {
    if (value?.id == meetingId) {
      value = null;
    }
  }
}

final class _TranscriptRepository implements TranscriptRepository {
  _TranscriptRepository(this.meetings);

  final _MeetingRepository meetings;
  final Map<String, TranscriptSnapshot> records = {};
  final List<TranscriptSnapshot> saved = [];
  final List<String?> expectedActiveIds = [];
  String? activeSnapshotId;
  TranscriptSnapshot? conflictingWinner;

  @override
  Future<TranscriptSnapshot?> getById(String snapshotId) async =>
      records[snapshotId];

  @override
  Future<List<TranscriptSnapshot>> listByMeeting(String meetingId) async {
    return records.values
        .where((snapshot) => snapshot.meetingId == meetingId)
        .toList();
  }

  @override
  Future<void> save(TranscriptSnapshot snapshot) async {
    activeSnapshotId ??= meetings.value?.activeTranscriptSnapshotId;
    records[snapshot.id] = snapshot;
    saved.add(snapshot);
  }

  @override
  Future<void> saveFinalAndActivate({
    required TranscriptSnapshot snapshot,
    required String? expectedActiveSnapshotId,
  }) async {
    final winner = conflictingWinner;
    if (winner != null) {
      conflictingWinner = null;
      records[winner.id] = winner;
      activeSnapshotId = winner.id;
      meetings.value = meetings.value!.activateFinalTranscript(winner);
      throw StateError('活动快照已改变');
    }
    if (activeSnapshotId != expectedActiveSnapshotId) {
      throw StateError('活动快照已改变');
    }
    records[snapshot.id] = snapshot;
    saved.add(snapshot);
    expectedActiveIds.add(expectedActiveSnapshotId);
    activeSnapshotId = snapshot.id;
    meetings.value = meetings.value!.activateFinalTranscript(snapshot);
  }

  @override
  Future<TranscriptSnapshot> updateSpeakerLabels({
    required String snapshotId,
    required Map<String, String?> labelsBySegmentId,
  }) async {
    return records[snapshotId]!;
  }
}

typedef _ResultBuilder =
    TranscriptSnapshot Function({
      required AsrModelDescriptor descriptor,
      required String meetingId,
      required String snapshotId,
    });

final class _EngineFactory implements AsrEngineFactory {
  final List<(String, String)> createCalls = [];
  final List<AsrEnginePurpose> purposes = [];
  _Engine? engine;
  Object? error;
  Object? disposeError;
  _ResultBuilder? resultBuilder;
  Future<void> Function()? beforeFinalize;

  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
    AsrEnginePurpose purpose = AsrEnginePurpose.finalTranscript,
  }) async {
    createCalls.add((modelId, modelVersion));
    purposes.add(purpose);
    final created = _Engine(
      descriptor: AsrModelRegistry.alpha.requireById(modelId),
      error: error,
      disposeError: disposeError,
      resultBuilder: resultBuilder,
      beforeFinalize: beforeFinalize,
    );
    engine = created;
    return created;
  }
}

final class _Engine implements AsrEngine {
  _Engine({
    required this.descriptor,
    required this.error,
    required this.disposeError,
    required this.resultBuilder,
    required this.beforeFinalize,
  });

  @override
  final AsrModelDescriptor descriptor;
  final Object? error;
  final Object? disposeError;
  final _ResultBuilder? resultBuilder;
  final Future<void> Function()? beforeFinalize;
  final StreamController<AsrFinalizationProgress> _progress =
      StreamController.broadcast();
  AudioSource? source;
  String? snapshotId;

  @override
  List<AsrWindowDiagnostic> get diagnostics => const [];

  @override
  AsrDeviceRiskState get deviceRisk => const AsrDeviceRiskState.supported();

  @override
  Stream<AsrDeviceRiskState> get deviceRisks => const Stream.empty();

  @override
  Stream<TranscriptEvent> get events => const Stream.empty();

  @override
  Stream<AsrFinalizationProgress> get finalizationProgress => _progress.stream;

  @override
  AsrEngineMetrics get metrics => AsrEngineMetrics(
    modelId: descriptor.modelId,
    modelVersion: descriptor.version,
    totalWindowCount: 0,
    recognizedWindowCount: 0,
    emptyWindowCount: 0,
    failedWindowCount: 0,
    totalAudioDuration: Duration.zero,
    totalInferenceDuration: Duration.zero,
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) async {}

  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
    String? snapshotId,
  }) async {
    this.source = source;
    this.snapshotId = snapshotId;
    await beforeFinalize?.call();
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return resultBuilder!(
      descriptor: descriptor,
      meetingId: meetingId,
      snapshotId: snapshotId!,
    );
  }

  @override
  void cancel() {}

  @override
  Future<void> dispose() async {
    await _progress.close();
    final failure = disposeError;
    if (failure != null) {
      throw failure;
    }
  }
}
