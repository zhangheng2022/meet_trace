import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_transcription_profile_repository.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/data/repositories/sqflite_processing_task_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase db;
  late SqfliteTranscriptionProfileRepository profiles;
  setUp(() {
    db = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    profiles = SqfliteTranscriptionProfileRepository(db);
  });
  tearDown(() => db.close());

  test('远程配置无需假安装；修订递增、默认选择和删除回退', () async {
    final initial = _profile();
    expect(initial.descriptor.installationType, AsrInstallationType.remote);
    expect(initial.descriptor.requiredBytes, 0);
    expect(initial.identityVersion, 'unreported');
    expect(initial.modelVersion, isNull);
    expect(
      await profiles.getDefaultProfileId(),
      TranscriptionProfile.localProfileId,
    );
    await profiles.save(initial);
    await profiles.setDefaultProfileId(initial.id);
    final edited = _profile(
      revision: 2,
      endpoint: 'https://second.example/transcribe',
    );
    await profiles.save(edited);
    await expectLater(profiles.save(initial), throwsStateError);
    expect((await profiles.getById(initial.id))!.endpoint, edited.endpoint);
    expect(initial.endpoint!.host, 'first.example');
    final database = await db.open();
    expect(await database.query('model_installations'), isEmpty);
    await profiles.delete(initial.id);
    expect(
      await profiles.getDefaultProfileId(),
      TranscriptionProfile.localProfileId,
    );
    expect(await profiles.list(), hasLength(1));
  });

  test('会议、快照和任务保留旧端点与凭据引用，编辑删除配置不改历史', () async {
    final profile = _profile();
    await profiles.save(profile);
    final meetings = SqfliteMeetingRepository(db);
    final transcripts = SqfliteTranscriptRepository(db);
    final tasks = SqfliteProcessingTaskRepository(db);
    final now = DateTime.utc(2026, 9, 8);
    final meeting = Meeting(
      id: 'meeting',
      title: '会议',
      createdAt: now,
      status: MeetingState.processing,
      audioPath: '/audio/fact.pcm',
      audioDurationMs: 1000,
      recordingModelId: profile.modelId,
      recordingModelVersion: profile.identityVersion,
      transcriptionProfile: profile,
    );
    await meetings.save(meeting);
    await transcripts.save(
      TranscriptSnapshot(
        id: 'snapshot',
        meetingId: meeting.id,
        kind: TranscriptSnapshotKind.finalTranscript,
        actualModelId: profile.modelId,
        actualModelVersion: profile.identityVersion,
        createdAt: now,
        status: TranscriptSnapshotStatus.processing,
        segments: [],
        transcriptionProfile: profile,
        timingPrecision: TranscriptTimingPrecision.audioWindow,
      ),
    );
    await tasks.save(
      ProcessingTask(
        id: 'task',
        meetingId: meeting.id,
        kind: ProcessingTaskKind.finalTranscription,
        state: ProcessingState.queued,
        createdAt: now,
        updatedAt: now,
        transcriptionProfile: profile,
      ),
    );
    final redirected = _profile(
      revision: 2,
      endpoint: 'https://redirect.example/asr',
    );
    await expectLater(
      meetings.save(
        Meeting(
          id: meeting.id,
          title: meeting.title,
          createdAt: now,
          status: MeetingState.processing,
          audioDurationMs: 1000,
          recordingModelId: profile.modelId,
          recordingModelVersion: profile.identityVersion,
          transcriptionProfile: redirected,
        ),
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
    await expectLater(
      tasks.save(
        ProcessingTask(
          id: 'task',
          meetingId: meeting.id,
          kind: ProcessingTaskKind.finalTranscription,
          state: ProcessingState.queued,
          createdAt: now,
          updatedAt: now,
          transcriptionProfile: redirected,
        ),
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
    await profiles.save(
      _profile(revision: 2, endpoint: 'https://second.example/transcribe'),
    );
    await profiles.delete(profile.id);
    for (final frozen in [
      (await meetings.getById(meeting.id))!.transcriptionProfile,
      (await transcripts.getById('snapshot'))!.transcriptionProfile,
      (await tasks.getById('task'))!.transcriptionProfile,
    ]) {
      expect(frozen!.hasSameConfiguration(profile), isTrue);
      expect(jsonEncode(frozen.toJson()), isNot(contains('Authorization')));
    }
    expect(
      (await transcripts.getById('snapshot'))!.timingPrecision,
      TranscriptTimingPrecision.audioWindow,
    );
  });

  test('端点拒绝内嵌凭据、远程明文与错误协议，允许本机网关', () {
    for (final endpoint in [
      'http://api.example/asr',
      'https://secret@api.example/asr',
      'wss://api.example/asr',
    ]) {
      expect(() => _profile(endpoint: endpoint), throwsArgumentError);
    }
    expect(
      _profile(endpoint: 'http://127.0.0.1:8080/asr').endpoint!.port,
      8080,
    );
  });
}

TranscriptionProfile _profile({
  int revision = 1,
  String endpoint = 'https://first.example/transcribe',
}) => TranscriptionProfile(
  id: 'remote',
  name: '自定义转录',
  revision: revision,
  protocol: TranscriptionProtocol.audioTranscriptions,
  modelId: 'user-model',
  endpoint: Uri.parse(endpoint),
  credentialRef: 'remote-key-v1',
);
