import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meettrace/data/services/audio/device_recording_storage_capacity.dart';
import 'package:meettrace/data/services/audio/flutter_foreground_recording_lifecycle.dart';
import 'package:meettrace/data/services/audio/record_pcm_audio_capture.dart';
import 'package:meettrace/data/services/audio/recording_checkpoint_store.dart';
import 'package:meettrace/data/services/audio/reliable_recording_service.dart';
import 'package:meettrace/data/services/audio/spike/recording_continuity_metrics.dart';
import 'package:meettrace/data/services/storage/app_file_layout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _recordingSeconds = int.fromEnvironment(
  'MEETTRACE_RECORDING_SECONDS',
  defaultValue: 30,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('前后台切换时事实 PCM 持续写入并原子封存', (_) async {
    final temporary = await getTemporaryDirectory();
    final root = Directory(
      p.join(
        temporary.path,
        'meettrace-step07-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    final layout = AppFileLayout(rootPath: root.path);
    final checkpoints = JsonRecordingCheckpointStore(layout);
    final service = ReliableRecordingService(
      capture: RecordPcmAudioCapture(),
      layout: layout,
      checkpoints: checkpoints,
      storageCapacity: const DeviceRecordingStorageCapacityProvider(),
      foreground: FlutterForegroundRecordingLifecycle(),
    );
    final watch = Stopwatch();

    try {
      await service.start(meetingId: 'device-recording');
      watch.start();
      await Future<void>.delayed(const Duration(seconds: _recordingSeconds));
      watch.stop();
      final artifact = await service.stop();
      final fileBytes = await File(artifact.audioPath).length();
      final metrics = RecordingContinuityMetrics(
        bytesWritten: artifact.bytes,
        elapsed: watch.elapsed,
        sampleRate: 16000,
        channelCount: 1,
      );
      final checkpoint = await checkpoints.load('device-recording');

      expect(fileBytes, artifact.bytes);
      expect(artifact.bytes, greaterThan(0));
      expect(metrics.completenessRatio, greaterThanOrEqualTo(0.98));
      expect(checkpoint?.state, RecordingCheckpointState.finalized);
      expect(checkpoint?.persistedBytes, artifact.bytes);

      final report = <String, Object>{
        'schemaVersion': 1,
        'recordingSeconds': _recordingSeconds,
        'fileBytes': fileBytes,
        'persistedBytes': artifact.bytes,
        'persistenceRatio': fileBytes / artifact.bytes,
        'captureCompletenessRatio': metrics.completenessRatio,
        'droppedPreviewChunks': service.droppedPreviewChunks,
      };
      debugPrintSynchronously(
        'MEETTRACE_STEP07_RECORDING:${jsonEncode(report)}',
        wrapWidth: null,
      );
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
