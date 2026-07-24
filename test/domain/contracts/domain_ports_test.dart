import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/repositories/repository_contracts.dart';
import 'package:meetily_ai/data/services/asr/asr_engine.dart';
import 'package:meetily_ai/domain/models/asr_model.dart';
import 'package:meetily_ai/domain/models/audio_source.dart';
import 'package:meetily_ai/domain/models/meeting.dart';
import 'package:meetily_ai/domain/models/transcript.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';

void main() {
  test('Factory 只按已锁定模型 ID 和版本创建统一 AsrEngine', () async {
    final factory = _FakeAsrEngineFactory();

    final engine = await factory.create(
      modelId: 'paraformer',
      modelVersion: '1',
    );

    expect(engine.descriptor.modelId, 'paraformer');
    expect(engine.descriptor.version, '1');
  });

  test('Repository 端口读写领域模型而不暴露存储对象', () async {
    final repository = _InMemoryMeetingRepository();
    final meeting = Meeting(
      id: 'meeting-1',
      title: '周会',
      createdAt: DateTime.utc(2026, 7, 24),
      status: MeetingState.created,
      audioDurationMs: 0,
      requestedModelId: 'paraformer',
      recordingModelId: 'paraformer',
      recordingModelVersion: '1',
    );

    await repository.save(meeting);

    expect(await repository.getById(meeting.id), same(meeting));
  });
}

final class _FakeAsrEngineFactory implements AsrEngineFactory {
  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
  }) async {
    return _FakeAsrEngine(modelId: modelId, modelVersion: modelVersion);
  }
}

final class _FakeAsrEngine implements AsrEngine {
  _FakeAsrEngine({required String modelId, required String modelVersion})
    : descriptor = AsrModelDescriptor(
        modelId: modelId,
        displayName: '测试模型',
        tier: AsrModelTier.standard,
        version: modelVersion,
        supportedLanguages: const ['zh'],
        installationType: AsrInstallationType.bundled,
        requiredBytes: 1,
        capabilities: const {'offline'},
      );

  @override
  final AsrModelDescriptor descriptor;

  @override
  Stream<TranscriptEvent> get events => const Stream.empty();

  @override
  Future<void> acceptAudio(
    Float32List samples, {
    required int sampleRate,
    required int startMs,
  }) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<TranscriptSnapshot> finalizeMeeting(AudioSource source) {
    throw UnimplementedError('本测试只验证接口形状');
  }

  @override
  Future<void> initialize() async {}
}

final class _InMemoryMeetingRepository implements MeetingRepository {
  final Map<String, Meeting> _meetings = {};

  @override
  Future<void> delete(String meetingId) async {
    _meetings.remove(meetingId);
  }

  @override
  Future<Meeting?> getById(String meetingId) async => _meetings[meetingId];

  @override
  Future<void> save(Meeting meeting) async {
    _meetings[meeting.id] = meeting;
  }

  @override
  Stream<List<Meeting>> watchAll() {
    return Stream.value(List.unmodifiable(_meetings.values));
  }
}
