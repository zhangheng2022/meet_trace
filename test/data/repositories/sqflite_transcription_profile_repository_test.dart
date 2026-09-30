import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_diarization_preference_repository.dart';
import 'package:meettrace/data/repositories/sqflite_recording_input_preference_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcription_profile_repository.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/data/repositories/sqflite_processing_task_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/processing_task.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/recording_input.dart';
import 'package:meettrace/domain/use_cases/check_meeting_readiness.dart';
import 'package:meettrace/domain/use_cases/lock_recording_input.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/model_selection_fakes.dart';

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
      credentialRef: 'remote-key-v2',
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
      _profile(
        revision: 2,
        endpoint: 'https://second.example/transcribe',
        credentialRef: 'remote-key-v2',
      ),
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

  test('本地来源从共享仓储读取分离偏好，无本场选择启动也冻结关闭值', () async {
    final preferences = SqfliteDiarizationPreferenceRepository(db);
    await preferences.setEnabled(false);
    final local = (await profiles.getById(
      TranscriptionProfile.localProfileId,
    ))!;
    expect(local.diarizationEnabled, isFalse);
    expect((await profiles.list()).first.diarizationEnabled, isFalse);

    final model = AsrModelRegistry.alpha.defaultModel;
    final installations = TestActiveInstallations();
    addTearDown(installations.dispose);
    installations.install(installations.installed(model), active: true);
    final readiness = CheckMeetingReadinessUseCase(
      device: _DeviceReadiness(),
      preferences: TestModelPreferences(model.modelId),
      installations: installations,
      profiles: profiles,
    );
    final meetings = SqfliteMeetingRepository(db);
    final session = await StartMeetingUseCase(
      meetings: meetings,
      engineFactory: TestAsrEngineFactory(),
      readinessChecker: readiness,
      meetingIdFactory: () => 'default-local-meeting',
      now: () => DateTime.utc(2026, 9, 8),
      recordingInputLock: LockRecordingInputUseCase(
        preferences: SqfliteRecordingInputPreferenceRepository(db),
        devices: _RecordingDevices(),
      ),
    ).execute();
    addTearDown(session.engine.dispose);
    expect(session.meeting.transcriptionProfile!.diarizationEnabled, isFalse);

    await preferences.setEnabled(true);
    expect((await profiles.list()).first.diarizationEnabled, isTrue);
    expect(
      (await meetings.getById(session.meeting.id))!
          .transcriptionProfile!
          .diarizationEnabled,
      isFalse,
    );
  });

  test('仓储拒绝跨接收方复用旧凭据，保持已有配置和默认来源', () async {
    final initial = _profile();
    await profiles.save(initial);
    await profiles.setDefaultProfileId(initial.id);
    for (final (endpoint, protocol) in [
      (
        'https://other.example/transcribe',
        TranscriptionProtocol.audioTranscriptions,
      ),
      (
        'https://first.example:8443/transcribe',
        TranscriptionProtocol.audioTranscriptions,
      ),
      (
        'wss://first.example/transcribe',
        TranscriptionProtocol.realtimeTranscription,
      ),
    ]) {
      await expectLater(
        profiles.save(
          _profile(revision: 2, endpoint: endpoint, protocol: protocol),
        ),
        throwsStateError,
      );
      expect(
        (await profiles.getById(initial.id))!.hasSameConfiguration(initial),
        isTrue,
      );
      expect(await profiles.getDefaultProfileId(), initial.id);
    }
  });

  test('同接收方路径及默认端口变化可复用凭据，新修订不会被当作幂等写入', () async {
    final initial = _profile();
    await profiles.save(initial);
    final edited = _profile(
      revision: 2,
      endpoint: 'https://first.example:443/another?region=cn',
    );
    await profiles.save(edited);
    await profiles.save(edited);
    expect(
      (await profiles.getById(initial.id))!.credentialRef,
      initial.credentialRef,
    );
    final revised = _profile(revision: 3, endpoint: edited.endpoint.toString());
    await profiles.save(revised);
    expect((await profiles.getById(initial.id))!.revision, 3);
    expect(edited.hasSameConfiguration(revised), isFalse);
  });

  test('跨接收方可明确更换凭据或清空认证，无凭据来源也可更换接收方', () async {
    await profiles.save(_profile());
    await profiles.save(
      _profile(
        revision: 2,
        endpoint: 'https://second.example/asr',
        credentialRef: 'remote-key-v2',
      ),
    );
    await profiles.save(
      _profile(
        revision: 3,
        endpoint: 'https://third.example/asr',
        credentialRef: null,
      ),
    );
    await profiles.save(
      _profile(
        revision: 4,
        endpoint: 'https://fourth.example/asr',
        credentialRef: null,
      ),
    );
    final current = (await profiles.getById('remote'))!;
    expect(current.revision, 4);
    expect(current.endpoint!.host, 'fourth.example');
    expect(current.credentialRef, isNull);
  });

  test('固定本地来源不可写删，未知默认被拒绝且本地始终排首位', () async {
    await expectLater(
      profiles.save(TranscriptionProfile.local()),
      throwsArgumentError,
    );
    await expectLater(
      profiles.delete(TranscriptionProfile.localProfileId),
      throwsArgumentError,
    );
    await expectLater(
      profiles.save(_profile(id: TranscriptionProfile.localProfileId)),
      throwsArgumentError,
    );
    await profiles.save(_profile(id: 'z-online'));
    await profiles.save(_profile(id: 'a-online'));
    await profiles.setDefaultProfileId('z-online');
    await expectLater(
      profiles.setDefaultProfileId('unknown'),
      throwsStateError,
    );
    expect(await profiles.getDefaultProfileId(), 'z-online');
    expect((await profiles.list()).map((profile) => profile.id), [
      TranscriptionProfile.localProfileId,
      'a-online',
      'z-online',
    ]);
  });

  test('端点拒绝内嵌凭据、远程明文与错误协议，允许本机网关', () {
    for (final endpoint in [
      'http://api.example/asr',
      'https://secret@api.example/asr',
      'wss://api.example/asr',
      'http://[2001:db8::1]:8080/asr',
    ]) {
      expect(() => _profile(endpoint: endpoint), throwsArgumentError);
    }
    expect(
      _profile(endpoint: 'http://127.0.0.1:8080/asr').endpoint!.port,
      8080,
    );
    final ipv6 = Uri.parse('http://[::1]:8080/asr');
    expect(ipv6.host, '::1');
    expect(_profile(endpoint: ipv6.toString()).endpoint, ipv6);
  });
}

TranscriptionProfile _profile({
  String id = 'remote',
  int revision = 1,
  String endpoint = 'https://first.example/transcribe',
  String? credentialRef = 'remote-key-v1',
  TranscriptionProtocol protocol = TranscriptionProtocol.audioTranscriptions,
}) => TranscriptionProfile(
  id: id,
  name: '自定义转录',
  revision: revision,
  protocol: protocol,
  modelId: 'user-model',
  endpoint: Uri.parse(endpoint),
  credentialRef: credentialRef,
);

final class _DeviceReadiness implements RecordingDeviceReadinessProbe {
  @override
  Future<RecordingDeviceReadiness> check({
    required bool requestMicrophonePermission,
  }) async => const RecordingDeviceReadiness(
    microphonePermissionGranted: true,
    freeBytes: minimumRecordingFreeBytes,
  );
}

final class _RecordingDevices implements RecordingInputDeviceCatalog {
  @override
  Future<List<RecordingInputDevice>> listAvailable() async => const [
    RecordingInputDevice(id: 'test-mic', label: '测试麦克风'),
  ];
}
