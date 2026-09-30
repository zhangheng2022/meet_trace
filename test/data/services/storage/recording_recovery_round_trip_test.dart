import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_processing_task_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/domain/models/asr_model.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/audio_source.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/ports/asr_engine.dart';
import 'package:meettrace/domain/ports/repositories.dart';
import 'package:meettrace/domain/ports/speaker_diarization.dart';
import 'package:meettrace/domain/use_cases/final_inference_scheduler.dart';
import 'package:meettrace/domain/use_cases/run_final_transcription.dart';
import 'package:meettrace/data/services/audio/pcm_audio_playback_service.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/startup_recovery_service.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/ports/asr_preview_session.dart';
import 'package:meettrace/domain/use_cases/manage_recording_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  for (final fault in ['checkpoint', 'reference', 'database']) {
    test('真实录音发生 $fault 故障后重启仍可播放和进入最终转录', () async {
      final root = await Directory.systemTemp.createTemp(
        'meettrace-round-trip-',
      );
      addTearDown(() => root.delete(recursive: true));
      final layout = AppFileLayout(rootPath: root.path);
      final database = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        path: layout.databasePath,
      );
      addTearDown(database.close);
      final meetings = SqfliteMeetingRepository(database);
      final now = DateTime.utc(2026, 9, 30);
      const id = 'recording';
      final meeting = Meeting(
        id: id,
        title: id,
        createdAt: now,
        status: MeetingState.created,
        audioDurationMs: 0,
        recordingModelId: senseVoiceDefaultModelId,
        recordingModelVersion: AsrModelRegistry.alpha.defaultModel.version,
      ).startRecording(startedAt: now);
      await meetings.save(meeting);
      final checkpoints = _CheckpointStore(
        JsonRecordingCheckpointStore(layout),
      );
      final capture = _Capture();
      addTearDown(capture.dispose);
      final meter = PcmAudioLevelMeter();
      final recording = ReliableRecordingService(
        capture: capture,
        layout: layout,
        checkpoints: checkpoints,
        storageCapacity: _Capacity(),
        audioLevelMeter: meter,
        factCommitInterval: Duration.zero,
        checkpointSaveBytesThreshold: 0,
        now: () => now,
      );
      addTearDown(() async {
        if (recording.canFinalize) {
          try {
            await recording.stop();
          } on Object {
            // 故障测试提前失败时仍尽量封闭音频句柄。
          }
        }
      });
      final lifecycle = ManageRecordingSessionUseCase(
        meetings: meetings,
        recording: recording,
        preview: _Preview(),
        now: () => now.add(const Duration(seconds: 1)),
      );
      await lifecycle.start(meeting);
      checkpoints.fail = fault == 'checkpoint';
      final pcm = Uint8List.fromList(
        List.generate(32000, (index) => index % 251),
      );
      capture.chunks.add(pcm);
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (recording.persistedBytes != pcm.length ||
          (checkpoints.fail && recording.state != RecordingState.failed)) {
        if (DateTime.now().isAfter(deadline)) fail('PCM did not reach disk');
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final db = await database.open();
      if (fault != 'checkpoint') {
        await db.execute('''
          CREATE TRIGGER reject_finish
          BEFORE UPDATE ON meetings
          WHEN NEW.id = '$id' ${fault == 'reference' ? "AND NEW.status = 'processing'" : ''}
          BEGIN
            SELECT RAISE(FAIL, 'forced persistence failure');
          END
        ''');
      }
      await expectLater(
        lifecycle.finish(meeting),
        throwsA(isA<ManageRecordingSessionException>()),
      );
      if (fault == 'reference') {
        final failed = (await meetings.getById(id))!;
        expect(failed.audioPath, layout.meetingAudioPath(id));
        expect(failed.audioDurationMs, 1000);
      }
      if (fault != 'checkpoint') await db.execute('DROP TRIGGER reject_finish');
      await database.close();

      final restarted = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        path: layout.databasePath,
      );
      addTearDown(restarted.close);
      final recovery = StartupRecoveryService(
        database: restarted,
        layout: layout,
      );
      final report = await recovery.recover(
        now: now.add(const Duration(seconds: 2)),
      );
      expect(report.failedRecordings, 0);
      final recovered = (await SqfliteMeetingRepository(restarted)
          .getById(id))!;
      expect(recovered.audioPath, layout.meetingAudioPath(id));
      expect(recovered.audioDurationMs, 1000);
      expect(
        recovered.beginFinalTranscription().status,
        MeetingState.processing,
      );
      expect(await File(recovered.audioPath!).readAsBytes(), pcm);
      final output = _Output();
      final playback = PcmAudioPlaybackService(
        output: output,
        layout: layout,
        meetingId: id,
      );
      addTearDown(playback.dispose);
      await playback.play(
        audioPath: recovered.audioPath!,
        startMs: 0,
        endMs: 1000,
      );
      expect((await File(output.path!).readAsBytes()).sublist(44), pcm);
      await playback.stop();
      final engine = _Engine(now);
      final transcripts = SqfliteTranscriptRepository(restarted);
      final tasks = SqfliteProcessingTaskRepository(restarted);
      final finalizer = FinalResultCoordinator(
        meetings: SqfliteMeetingRepository(restarted),
        transcripts: transcripts,
        tasks: tasks,
        engineFactory: _Factory(engine),
        diarization: _Diarization(),
        diarizationPreferences: _DiarizationPreference(),
        scheduler: FinalInferenceScheduler(),
        now: () => now.add(const Duration(seconds: 3)),
      );
      final result = await finalizer.transcribe(meetingId: id);
      expect(engine.bytes, pcm);
      expect(result.meeting.status, MeetingState.completed);
      expect(result.snapshot.segments.single.text, '恢复后的测试转录');
      expect(
        (await transcripts.getById(result.snapshot.id))!.status,
        TranscriptSnapshotStatus.complete,
      );
      // 兼容未保存冻结 profile 的历史本地会议；不会遗留运行中的任务。
      expect(await tasks.listByMeeting(id), isEmpty);
      expect(
        (await SqfliteMeetingRepository(restarted).getById(id))!
            .activeTranscriptSnapshotId,
        result.snapshot.id,
      );
      // 清理空的会议缓存目录后，后续启动没有重复的录音恢复。
      await recovery.recover(now: now.add(const Duration(seconds: 3)));
      expect(
        (await recovery.recover(now: now.add(const Duration(seconds: 4))))
            .totalChanges,
        0,
      );
    });
  }
}

final class _Capture implements PcmAudioCapture {
  final chunks = StreamController<Uint8List>();
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<Stream<Uint8List>> start({
    LockedRecordingInput input = const LockedRecordingInput.systemDefault(),
  }) async => chunks.stream;
  @override
  Future<void> stop() => chunks.close();
  @override
  Future<void> dispose() => chunks.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Capacity implements RecordingStorageCapacityProvider {
  @override
  Future<int> getFreeBytes() async => 1024 * 1024 * 1024;
}

final class _CheckpointStore implements RecordingCheckpointStore {
  _CheckpointStore(this.delegate);
  final RecordingCheckpointStore delegate;
  bool fail = false;
  @override
  Future<void> save(RecordingCheckpoint checkpoint) async {
    if (fail) throw const FileSystemException('checkpoint unavailable');
    await delegate.save(checkpoint);
  }

  @override
  Future<RecordingCheckpoint?> load(String id) => delegate.load(id);
  @override
  Future<void> delete(String id) => delegate.delete(id);
}

final class _Preview implements AsrPreviewSession {
  @override
  Future<void> stop() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Output implements DeviceAudioOutput {
  String? path;
  @override
  Stream<String> get onCompleted => const Stream.empty();
  @override
  Future<void> playDeviceFile(String path) async => this.path = path;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

final class _Factory implements AsrEngineFactory {
  _Factory(this.engine);
  final _Engine engine;
  @override
  Future<AsrEngine> create({
    required String modelId,
    required String modelVersion,
    String language = 'auto',
    bool useInverseTextNormalization = true,
  }) async => engine;
}

final class _Engine implements AsrEngine {
  _Engine(this.now);
  final DateTime now;
  Uint8List? bytes;
  @override
  AsrModelDescriptor get descriptor => AsrModelRegistry.alpha.defaultModel;
  @override
  Future<TranscriptSnapshot> finalizeMeeting(
    AudioSource source, {
    required String meetingId,
    String? snapshotId,
  }) async {
    bytes = await File(source.path).readAsBytes();
    return TranscriptSnapshot(
      id: snapshotId!,
      meetingId: meetingId,
      kind: TranscriptSnapshotKind.finalTranscript,
      actualModelId: descriptor.modelId,
      actualModelVersion: descriptor.version,
      createdAt: now,
      status: TranscriptSnapshotStatus.complete,
      segments: [
        TranscriptSegment(
          id: '$snapshotId-1',
          snapshotId: snapshotId,
          startMs: 0,
          endMs: source.durationMs,
          text: '恢复后的测试转录',
          modelId: descriptor.modelId,
          modelVersion: descriptor.version,
        ),
      ],
    );
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Diarization implements SpeakerDiarizationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DiarizationPreference implements DiarizationPreferenceRepository {
  @override
  Future<bool> getEnabled() async => false;
  @override
  Future<void> setEnabled(bool value) async {}
}
