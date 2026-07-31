import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/app/application.dart';
import 'package:meettrace/data/repositories/sqflite_meeting_repository.dart';
import 'package:meettrace/data/repositories/sqflite_model_installation_repository.dart';
import 'package:meettrace/data/repositories/sqflite_model_usage_lease_repository.dart';
import 'package:meettrace/data/repositories/sqflite_transcript_repository.dart';
import 'package:meettrace/data/services/asr/asr_preview_coordinator.dart';
import 'package:meettrace/data/services/asr/platform_asr_device_risk_monitor.dart';
import 'package:meettrace/data/services/asr/whisper_asr_engine_factory.dart';
import 'package:meettrace/data/services/audio/device_recording_storage_capacity.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/audio/recording_ports.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:meettrace/data/services/storage/platform_database_factory.dart';
import 'package:meettrace/data/services/vad/voice_activity_segmenter.dart';
import 'package:meettrace/data/services/vad/whisper_vad_segmenter.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/asr_preview.dart';
import 'package:meettrace/domain/models/meeting.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/models/model_installation.dart';
import 'package:meettrace/domain/models/transcript.dart';
import 'package:meettrace/domain/models/workflow_states.dart';
import 'package:meettrace/domain/use_cases/check_meeting_readiness.dart';
import 'package:meettrace/domain/use_cases/manage_recording_session.dart';
import 'package:meettrace/domain/use_cases/run_final_transcription.dart';
import 'package:meettrace/domain/use_cases/start_meeting.dart';
import 'package:meettrace/ui/features/meetings/view_models/recording/recording_session_view_model.dart';
import 'package:meettrace/ui/features/meetings/views/recording/recording_session_view.dart';
import 'package:meettrace_whisper_native/meettrace_whisper_native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _modelAsset =
    'assets/models/whisper-cpp-base-q5_1-v1.9.1/ggml-base-q5_1.bin';
const _vadAsset =
    'assets/models/whisper-vad-silero-v6.2.0/ggml-silero-v6.2.0.bin';
const _recordingDuration = Duration(seconds: 3);
const _nativeLifecycleCycles = int.fromEnvironment(
  'MEETTRACE_NATIVE_LIFECYCLE_CYCLES',
  defaultValue: 1,
);
const _vadLifecycleCycles = int.fromEnvironment(
  'MEETTRACE_VAD_LIFECYCLE_CYCLES',
  defaultValue: 100,
);
const _meetingLifecycleCycles = int.fromEnvironment(
  'MEETTRACE_MEETING_LIFECYCLE_CYCLES',
  defaultValue: 10,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实外壳中预览失败不阻断事实录音与 Base 最终快照', (tester) async {
    final fixture = await _MeetingFlowFixture.create();
    try {
      await fixture.startMeeting();
      await tester.pumpWidget(
        Application(
          home: _MeetingFlowHarness(
            viewModel: fixture.recordingViewModel!,
            finalTranscription: fixture.finalTranscription,
            result: fixture.result,
          ),
        ),
      );
      await _waitFor(
        tester,
        () => fixture.recording.state == RecordingState.recording,
        timeout: const Duration(seconds: 30),
        reason: '真实麦克风录音未进入 recording',
      );

      await Future<void>.delayed(_recordingDuration);
      await tester.pump();
      final firstPersistedBytes = fixture.recording.persistedBytes;
      expect(firstPersistedBytes, greaterThan(0));
      expect(
        fixture.preview.metrics.state,
        AsrPreviewState.recordingOnly,
        reason: '故障 VAD 应只让预览进入 recordingOnly',
      );

      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      expect(
        fixture.recording.persistedBytes,
        greaterThan(firstPersistedBytes),
        reason: '预览失败后事实 PCM 必须继续增长',
      );

      await tester.tap(find.text('结束会议'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('结束并保存'));
      await tester.pump();

      final finalResult = await fixture.result.future.timeout(
        const Duration(minutes: 3),
      );
      await tester.pumpAndSettle();
      final persisted = await fixture.meetings.getById(finalResult.meeting.id);
      final snapshots = await fixture.transcripts.listByMeeting(
        finalResult.meeting.id,
      );
      final audio = File(finalResult.meeting.audioPath!);
      final diagnostics = fixture.recording.pcmDiagnostics;
      final meetingModelLocked =
          finalResult.meeting.recordingModelId ==
              finalResult.snapshot.actualModelId &&
          finalResult.meeting.recordingModelVersion ==
              finalResult.snapshot.actualModelVersion;
      final factPcmSoleSourcePassed =
          await audio.length() == fixture.recording.persistedBytes &&
          diagnostics.totalBytes == fixture.recording.persistedBytes &&
          diagnostics.duration.inMilliseconds ==
              finalResult.meeting.audioDurationMs;

      expect(persisted?.status, MeetingState.completed);
      expect(persisted?.activeTranscriptSnapshotId, finalResult.snapshot.id);
      expect(finalResult.snapshot.status, TranscriptSnapshotStatus.complete);
      expect(finalResult.snapshot.actualModelId, whisperBaseStandardModelId);
      expect(
        finalResult.snapshot.actualModelVersion,
        AsrModelRegistry.alpha.defaultModel.version,
      );
      expect(
        snapshots
            .where(
              (item) => item.kind == TranscriptSnapshotKind.finalTranscript,
            )
            .length,
        1,
      );
      expect(meetingModelLocked, isTrue);
      expect(factPcmSoleSourcePassed, isTrue);
      expect(fixture.preview.metrics.state, AsrPreviewState.disposed);

      debugPrintSynchronously(
        'MEETTRACE_ANDROID_EMULATOR_FLOW:${jsonEncode({'schemaVersion': 1, 'modelId': finalResult.snapshot.actualModelId, 'modelVersion': finalResult.snapshot.actualModelVersion, 'meetingModelLocked': meetingModelLocked, 'factPcmSoleSourcePassed': factPcmSoleSourcePassed, 'audioBytes': fixture.recording.persistedBytes, 'audioDurationMs': finalResult.meeting.audioDurationMs, 'previewFailureCode': 'asr.preview.vad_failed', 'previewDegradedWithoutRecordingLoss': true, 'finalSnapshotStatus': finalResult.snapshot.status.name, 'finalSegmentCount': finalResult.snapshot.segments.length, 'pcmRms': diagnostics.rmsNormalized, 'pcmPeak': diagnostics.peakNormalized, 'pcmClippingRatio': diagnostics.clippingRatio})}',
        wrapWidth: null,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await fixture.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Base Native context 连续创建、推理和释放', (_) async {
    expect(_nativeLifecycleCycles, greaterThan(0));
    final temporary = await getTemporaryDirectory();
    final root = Directory(
      p.join(
        temporary.path,
        'meettrace-native-cycles-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final modelPath = p.join(root.path, 'ggml-base-q5_1.bin');
    await root.create(recursive: true);
    await _copyAsset(_modelAsset, modelPath);

    try {
      final metrics = await compute(_runNativeLifecycle, {
        'modelPath': modelPath,
        'cycles': _nativeLifecycleCycles,
      });
      expect(
        metrics['steadyStateGrowthBytes']! as int,
        lessThan(32 * 1024 * 1024),
      );
      debugPrintSynchronously(
        'MEETTRACE_ANDROID_NATIVE_CYCLES:${jsonEncode(metrics)}',
        wrapWidth: null,
      );
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  testWidgets('官方 Silero VAD 可加载、分段并幂等释放', (_) async {
    final temporary = await getTemporaryDirectory();
    final root = Directory(
      p.join(
        temporary.path,
        'meettrace-vad-native-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final modelPath = p.join(root.path, 'ggml-silero-v6.2.0.bin');
    await root.create(recursive: true);
    await _copyAsset(_vadAsset, modelPath);

    try {
      expect(_vadLifecycleCycles, greaterThanOrEqualTo(1));
      final nativeMetrics = await compute(_runNativeVadLifecycle, {
        'modelPath': modelPath,
        'cycles': _vadLifecycleCycles,
      });
      expect(
        nativeMetrics['steadyStateGrowthBytes']! as int,
        lessThan(32 * 1024 * 1024),
      );

      final streaming = WhisperVadSegmenter(modelPath: modelPath);
      final streamingSegments = <VadSpeechSegment>[];
      streamingSegments.addAll(await streaming.accept(Float32List(2 * 16000)));
      streamingSegments.addAll(await streaming.flush());
      await streaming.dispose();
      expect(streamingSegments, isEmpty);

      debugPrintSynchronously(
        'MEETTRACE_ANDROID_NATIVE_VAD:${jsonEncode({...nativeMetrics, 'streamingSilenceSegmentCount': streamingSegments.length, 'workerIsolateVerified': true})}',
        wrapWidth: null,
      );
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('事实 PCM 会话连续开始、停止且不残留采集流', (_) async {
    final temporary = await getTemporaryDirectory();
    final root = Directory(
      p.join(
        temporary.path,
        'meettrace-recording-cycles-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final layout = AppFileLayout(rootPath: root.path);
    await layout.createBaseDirectories();
    var totalBytes = 0;

    try {
      for (var cycle = 0; cycle < _nativeLifecycleCycles; cycle++) {
        final capture = _DeterministicPcmAudioCapture();
        final service = ReliableRecordingService(
          capture: capture,
          layout: layout,
          checkpoints: JsonRecordingCheckpointStore(layout),
          storageCapacity: const DeviceRecordingStorageCapacityProvider(),
          foreground: const NoopRecordingForegroundLifecycle(),
          audioLevelMeter: PcmAudioLevelMeter(),
        );
        final meetingId = 'recording-cycle-$cycle';
        await service.start(meetingId: meetingId);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final artifact = await service.stop();
        final checkpoint = await JsonRecordingCheckpointStore(
          layout,
        ).load(meetingId);

        expect(service.state, RecordingState.completed);
        expect(artifact.bytes, greaterThan(0));
        expect(await File(artifact.audioPath).length(), artifact.bytes);
        expect(service.pcmDiagnostics.totalBytes, artifact.bytes);
        expect(checkpoint?.state, RecordingCheckpointState.finalized);
        expect(capture.isStopped, isTrue);
        totalBytes += artifact.bytes;
      }

      debugPrintSynchronously(
        'MEETTRACE_ANDROID_RECORDING_CYCLES:${jsonEncode({'schemaVersion': 1, 'cycles': _nativeLifecycleCycles, 'totalBytes': totalBytes, 'allCaptureStreamsClosed': true})}',
        wrapWidth: null,
      );
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('完整会议连续开始、停止且释放模型租约与预览资源', (_) async {
    expect(_meetingLifecycleCycles, greaterThanOrEqualTo(10));
    var sealedMeetings = 0;
    var totalBytes = 0;
    var allCaptureStreamsClosed = true;
    var allPreviewSessionsDisposed = true;
    var allModelLeasesReleased = true;

    for (var cycle = 0; cycle < _meetingLifecycleCycles; cycle++) {
      final fixture = await _MeetingFlowFixture.create();
      try {
        await fixture.startMeeting();
        final started = await fixture.recordingViewModel!.start();
        expect(started, isTrue, reason: '第 $cycle 次会议未能开始录音');
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final completed = await fixture.recordingViewModel!.stop();
        expect(completed, isNotNull, reason: '第 $cycle 次会议未能封存事实录音');
        expect(completed!.status, MeetingState.processing);
        expect(fixture.recording.persistedBytes, greaterThan(0));
        expect(
          await File(completed.audioPath!).length(),
          fixture.recording.persistedBytes,
        );
        final captureStreamClosed = fixture.capture.isStopped;
        final previewSessionDisposed =
            fixture.preview.metrics.state == AsrPreviewState.disposed;
        final modelLeaseReleased = await fixture.hasNoActiveModelLeases();
        expect(captureStreamClosed, isTrue);
        expect(previewSessionDisposed, isTrue);
        expect(modelLeaseReleased, isTrue);
        allCaptureStreamsClosed &= captureStreamClosed;
        allPreviewSessionsDisposed &= previewSessionDisposed;
        allModelLeasesReleased &= modelLeaseReleased;
        totalBytes += fixture.recording.persistedBytes;
      } finally {
        await fixture.dispose();
      }
      sealedMeetings++;
    }

    debugPrintSynchronously(
      'MEETTRACE_ANDROID_MEETING_CYCLES:${jsonEncode({'schemaVersion': 1, 'cycles': _meetingLifecycleCycles, 'sealedMeetings': sealedMeetings, 'totalBytes': totalBytes, 'allCaptureStreamsClosed': allCaptureStreamsClosed, 'allPreviewSessionsDisposed': allPreviewSessionsDisposed, 'allModelLeasesReleased': allModelLeasesReleased})}',
      wrapWidth: null,
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Map<String, Object> _runNativeLifecycle(Map<String, Object> input) {
  final modelPath = input['modelPath']! as String;
  final cycles = input['cycles']! as int;
  final rssSamples = <int>[];
  var emittedSegmentCount = 0;

  for (var cycle = 0; cycle < cycles; cycle++) {
    final context = WhisperNativeContext.open(
      modelPath: modelPath,
      threadCount: 2,
      language: 'zh',
    );
    try {
      final result = context.transcribe(Float32List(16000));
      emittedSegmentCount += result.segments.length;
      for (final segment in result.segments) {
        if (segment.endMs <= segment.startMs) {
          throw StateError('Native ASR 返回了非正时长片段');
        }
      }
    } finally {
      context.dispose();
      context.dispose();
    }
    rssSamples.add(ProcessInfo.currentRss);
  }

  final growthBytes = rssSamples.length < 2
      ? 0
      : rssSamples.last - rssSamples.first;
  final warmupIndex = rssSamples.length > 10 ? 9 : 0;
  final steadyStateGrowthBytes = rssSamples.last - rssSamples[warmupIndex];
  return {
    'schemaVersion': 1,
    'cycles': cycles,
    'runtimeVersion': WhisperNativeContext.runtimeVersion,
    'rssSamplesBytes': rssSamples,
    'rssGrowthBytes': growthBytes,
    'steadyStateGrowthBytes': steadyStateGrowthBytes,
    'steadyStateGrowthLimitBytes': 32 * 1024 * 1024,
    'silenceSegmentCount': emittedSegmentCount,
    'workerIsolateVerified': true,
    'disposeIdempotent': true,
  };
}

Map<String, Object> _runNativeVadLifecycle(Map<String, Object> input) {
  final modelPath = input['modelPath']! as String;
  final cycles = input['cycles']! as int;
  final samples = Float32List(4 * 16000);
  for (var index = 16000; index < 3 * 16000; index++) {
    samples[index] = (index ~/ 40).isEven ? 0.25 : -0.25;
  }
  final rssSamples = <int>[];
  var syntheticSegmentCount = 0;

  for (var cycle = 0; cycle < cycles; cycle++) {
    final context = WhisperVadNativeContext.open(modelPath: modelPath);
    try {
      if (cycle == 0) {
        context.cancel();
        try {
          context.segment(Float32List(16000));
          throw StateError('VAD cancel 后仍允许 segment');
        } on WhisperNativeException catch (error) {
          if (error.code != 'cancelled') {
            rethrow;
          }
        }
        context.reset();
        final synthetic = context.segment(samples);
        syntheticSegmentCount = synthetic.length;
        for (final segment in synthetic) {
          if (segment.startSample < 0 ||
              segment.endSample <= segment.startSample ||
              segment.endSample > samples.length) {
            throw StateError('Native VAD 返回了越界片段');
          }
        }
      }
      if (context.segment(Float32List(16000)).isNotEmpty) {
        throw StateError('Native VAD 在纯静音上产生了片段');
      }
    } finally {
      context.dispose();
      context.dispose();
    }
    rssSamples.add(ProcessInfo.currentRss);
  }

  final warmupIndex = rssSamples.length > 10 ? 9 : 0;
  return {
    'schemaVersion': 1,
    'model': 'ggml-silero-v6.2.0',
    'cycles': cycles,
    'silenceSegmentCount': 0,
    'syntheticSegmentCount': syntheticSegmentCount,
    'rssSamplesBytes': rssSamples,
    'steadyStateGrowthBytes': rssSamples.last - rssSamples[warmupIndex],
    'cancelResetVerified': true,
    'disposeIdempotent': true,
  };
}

final class _MeetingFlowFixture {
  _MeetingFlowFixture._({
    required this.root,
    required this.database,
    required this.meetings,
    required this.transcripts,
    required this.installations,
    required this.leases,
    required this.engineFactory,
    required this.finalTranscription,
    required this.layout,
    required this.preview,
    required this.recording,
    required this.capture,
  });

  final Directory root;
  final AppDatabase database;
  final SqfliteMeetingRepository meetings;
  final SqfliteTranscriptRepository transcripts;
  final SqfliteModelInstallationRepository installations;
  final SqfliteModelUsageLeaseRepository leases;
  final WhisperAsrEngineFactory engineFactory;
  final FinalTranscriptionService finalTranscription;
  final AppFileLayout layout;
  final Completer<FinalTranscriptionResult> result =
      Completer<FinalTranscriptionResult>();

  AsrPreviewCoordinator preview;
  ReliableRecordingService recording;
  final _DeterministicPcmAudioCapture capture;
  RecordingSessionViewModel? recordingViewModel;
  StartedMeetingSession? _session;

  static Future<_MeetingFlowFixture> create() async {
    final temporary = await getTemporaryDirectory();
    final root = Directory(
      p.join(
        temporary.path,
        'meettrace-emulator-flow-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final layout = AppFileLayout(rootPath: root.path);
    await layout.createBaseDirectories();
    final database = AppDatabase(
      databaseFactory: createPlatformDatabaseFactory(),
      path: layout.databasePath,
    );
    final meetings = SqfliteMeetingRepository(database);
    final transcripts = SqfliteTranscriptRepository(
      database,
      onMeetingChanged: meetings.notifyChanged,
    );
    final installations = SqfliteModelInstallationRepository(database);
    final leases = SqfliteModelUsageLeaseRepository(database);
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    final modelRoot = layout.modelVersionDirectory(
      descriptor.modelId,
      descriptor.version,
    );
    await Directory(modelRoot).create(recursive: true);
    await _copyAsset(_modelAsset, p.join(modelRoot, 'ggml-base-q5_1.bin'));
    await _copyAsset(
      _vadAsset,
      p.join(modelRoot, 'vad', 'ggml-silero-v6.2.0.bin'),
    );
    await installations.saveInstalledAndActivate(
      ModelInstallation(
        modelId: descriptor.modelId,
        version: descriptor.version,
        installationType: descriptor.installationType,
        state: ModelInstallationState.installed,
        installedPath: modelRoot,
        verifiedAt: DateTime.now(),
        bytes: descriptor.requiredBytes,
      ),
    );
    final engineFactory = WhisperAsrEngineFactory(
      installations: installations,
      leases: leases,
      riskMonitor: createPlatformAsrDeviceRiskMonitor(),
      ownerId: 'android-emulator-flow',
    );
    final session =
        await StartMeetingUseCase(
          meetings: meetings,
          engineFactory: engineFactory,
          readinessChecker: const _ReadyMeetingChecker(),
          meetingIdFactory: () =>
              'emulator-meeting-${DateTime.now().microsecondsSinceEpoch}',
          now: DateTime.now,
        ).execute(
          defaultModelId: descriptor.modelId,
          availableVersions: {descriptor.modelId: descriptor.version},
        );
    final preview = AsrPreviewCoordinator(
      vad: _FailingVoiceActivitySegmenter(),
      engine: session.engine,
    );
    final capture = _DeterministicPcmAudioCapture();
    final recording = ReliableRecordingService(
      capture: capture,
      layout: layout,
      checkpoints: JsonRecordingCheckpointStore(layout),
      storageCapacity: const DeviceRecordingStorageCapacityProvider(),
      foreground: const NoopRecordingForegroundLifecycle(),
      previewSink: preview,
      audioLevelMeter: PcmAudioLevelMeter(),
    );
    final fixture = _MeetingFlowFixture._(
      root: root,
      database: database,
      meetings: meetings,
      transcripts: transcripts,
      installations: installations,
      leases: leases,
      engineFactory: engineFactory,
      finalTranscription: FinalTranscriptionService(
        meetings: meetings,
        transcripts: transcripts,
        engineFactory: engineFactory,
        now: DateTime.now,
      ),
      layout: layout,
      preview: preview,
      recording: recording,
      capture: capture,
    );
    fixture._session = session;
    return fixture;
  }

  Future<void> startMeeting() async {
    final session = _session!;
    recordingViewModel = RecordingSessionViewModel(
      session: session,
      recording: recording,
      preview: preview,
      sessionLifecycle: ManageRecordingSessionUseCase(
        meetings: meetings,
        recording: recording,
        preview: preview,
        now: DateTime.now,
      ),
    );
  }

  Future<bool> hasNoActiveModelLeases() async {
    final descriptor = AsrModelRegistry.alpha.defaultModel;
    final active = await leases.listActive(
      modelId: descriptor.modelId,
      version: descriptor.version,
      now: DateTime.now(),
    );
    return active.isEmpty;
  }

  Future<void> dispose() async {
    recordingViewModel?.dispose();
    if (recording.canFinalize) {
      try {
        await recording.stop();
      } on Object {
        // 保留测试失败的原始断言。
      }
    }
    if (preview.metrics.state != AsrPreviewState.disposed) {
      await preview.dispose();
    }
    await _session?.engine.dispose();
    expect(await hasNoActiveModelLeases(), isTrue);
    await meetings.dispose();
    await installations.dispose();
    await database.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

final class _MeetingFlowHarness extends StatefulWidget {
  const _MeetingFlowHarness({
    required this.viewModel,
    required this.finalTranscription,
    required this.result,
  });

  final RecordingSessionViewModel viewModel;
  final FinalTranscriptionService finalTranscription;
  final Completer<FinalTranscriptionResult> result;

  @override
  State<_MeetingFlowHarness> createState() => _MeetingFlowHarnessState();
}

final class _MeetingFlowHarnessState extends State<_MeetingFlowHarness> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    if (_processing) {
      return const Center(child: Text('正在生成最终转录'));
    }
    return RecordingSessionView(
      viewModel: widget.viewModel,
      onFinished: (meeting) {
        setState(() => _processing = true);
        unawaited(_finish(meeting));
      },
    );
  }

  Future<void> _finish(Meeting meeting) async {
    try {
      final result = await widget.finalTranscription.transcribe(
        meetingId: meeting.id,
      );
      if (!widget.result.isCompleted) {
        widget.result.complete(result);
      }
    } on Object catch (error, stackTrace) {
      if (!widget.result.isCompleted) {
        widget.result.completeError(error, stackTrace);
      }
    }
  }
}

final class _FailingVoiceActivitySegmenter implements VoiceActivitySegmenter {
  @override
  int get sampleRate => 16000;

  @override
  Future<List<VadSpeechSegment>> accept(Float32List samples) async {
    throw StateError('injected VAD failure after PCM persistence');
  }

  @override
  Future<List<VadSpeechSegment>> flush() async => const [];

  @override
  Future<void> reset({required int nextStartSample}) async {}

  @override
  Future<void> dispose() async {}
}

final class _ReadyMeetingChecker implements MeetingReadinessChecker {
  const _ReadyMeetingChecker();

  @override
  Future<MeetingReadiness> check({
    bool requestMicrophonePermission = false,
  }) async {
    return const MeetingReadiness(
      microphonePermissionGranted: true,
      freeBytes: 1024 * 1024 * 1024,
      defaultModelId: whisperBaseStandardModelId,
      defaultModelName: 'Whisper Base',
      defaultModelAvailable: true,
    );
  }
}

final class _DeterministicPcmAudioCapture implements PcmAudioCapture {
  StreamController<Uint8List>? _controller;
  Timer? _timer;
  int _chunkSequence = 0;

  bool get isStopped => _controller == null && _timer == null;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<Stream<Uint8List>> start() async {
    final controller = StreamController<Uint8List>();
    _controller = controller;
    _startTimer();
    return controller.stream;
  }

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> resume() async => _startTimer();

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    await controller?.close();
  }

  @override
  Future<void> dispose() => stop();

  void _startTimer() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final controller = _controller;
      if (controller == null || controller.isClosed) {
        return;
      }
      const samplesPerChunk = 1600;
      final bytes = Uint8List(samplesPerChunk * 2);
      final data = ByteData.sublistView(bytes);
      for (var index = 0; index < samplesPerChunk; index++) {
        final sample = ((_chunkSequence * samplesPerChunk + index) ~/ 20).isEven
            ? 4096
            : -4096;
        data.setInt16(index * 2, sample, Endian.little);
      }
      _chunkSequence++;
      controller.add(bytes);
    });
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String reason,
}) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed >= timeout) {
      fail(reason);
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Future<void> _copyAsset(String assetKey, String targetPath) async {
  final data = await rootBundle.load(assetKey);
  final target = File(targetPath);
  await target.parent.create(recursive: true);
  await target.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
