import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../tool/benchmarks/rebuild_android_emulator_smoke_evidence.dart';

void main() {
  group('rebuildAndroidEmulatorSmokeEvidence', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('meettrace-smoke-evidence-');
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('仅从四个完整通过日志重建并哈希证据', () async {
      final report = await _fixture(root);

      final evidence = await rebuildAndroidEmulatorSmokeEvidence(
        interruptedReport: report,
        repositoryRoot: root,
        apiLevel: 36,
        abi: 'x86_64',
      );
      final results = evidence['results']! as List<Object?>;
      final measurements = evidence['measurements']! as Map<String, Object?>;

      expect(evidence['status'], 'passed');
      expect(evidence['nativeLifecycleCycles'], 100);
      expect(evidence['vadLifecycleCycles'], 100);
      expect(
        results.cast<Map<String, Object?>>().every(
          (result) => (result['logSha256']! as String).length == 64,
        ),
        isTrue,
      );
      expect(measurements['meetingFlow'], isA<Map<String, Object?>>());
      expect(evidence.toString(), isNot(contains(root.path)));
    });

    test('拒绝非零退出码和越过仓库根目录的日志引用', () async {
      final failed = await _fixture(root);
      final failedResults = failed['results']! as List<Object?>;
      (failedResults.first! as Map<String, Object?>)['exitCode'] = 1;
      expect(
        () => rebuildAndroidEmulatorSmokeEvidence(
          interruptedReport: failed,
          repositoryRoot: root,
          apiLevel: 36,
          abi: 'x86_64',
        ),
        throwsFormatException,
      );

      final escaped = await _fixture(root);
      final escapedResults = escaped['results']! as List<Object?>;
      (escapedResults.first! as Map<String, Object?>)['log'] = '../outside.log';
      expect(
        () => rebuildAndroidEmulatorSmokeEvidence(
          interruptedReport: escaped,
          repositoryRoot: root,
          apiLevel: 36,
          abi: 'x86_64',
        ),
        throwsFormatException,
      );
    });

    test('拒绝并非后处理失败或缺少有效 UTC 时间的报告', () async {
      final passed = await _fixture(root);
      passed['status'] = 'passed';
      expect(
        () => rebuildAndroidEmulatorSmokeEvidence(
          interruptedReport: passed,
          repositoryRoot: root,
          apiLevel: 36,
          abi: 'x86_64',
        ),
        throwsFormatException,
      );

      final missingTimestamp = await _fixture(root);
      missingTimestamp['capturedAtUtc'] = '2026-07-31 00:00:00';
      expect(
        () => rebuildAndroidEmulatorSmokeEvidence(
          interruptedReport: missingTimestamp,
          repositoryRoot: root,
          apiLevel: 36,
          abi: 'x86_64',
        ),
        throwsFormatException,
      );
    });
  });
}

Future<Map<String, Object?>> _fixture(Directory root) async {
  final logs = <String, String>{
    'build-android-x64-debug':
        r'Built build\app\outputs\flutter-apk\app-debug.apk',
    'whisper-base-native': '00:01 +1: All tests passed!',
    'reliable-recording':
        'MEETTRACE_STEP07_RECORDING:'
        '{"schemaVersion":1,"recordingSeconds":30}\n'
        '00:01 +1: All tests passed!',
    'android-emulator-meeting-flow':
        'MEETTRACE_ANDROID_EMULATOR_FLOW:'
        '{"schemaVersion":1,"meetingModelLocked":true}\n'
        'MEETTRACE_ANDROID_NATIVE_CYCLES:'
        '{"schemaVersion":1,"cycles":100}\n'
        'MEETTRACE_ANDROID_NATIVE_VAD:'
        '{"schemaVersion":1,"cycles":100}\n'
        'MEETTRACE_ANDROID_RECORDING_CYCLES:'
        '{"schemaVersion":1,"cycles":100}\n'
        '00:01 +4: All tests passed!',
  };
  final results = <Map<String, Object?>>[];
  const commands = {
    'build-android-x64-debug':
        'flutter build apk --debug --target-platform android-x64',
    'whisper-base-native':
        'flutter test integration_test/whisper_base_standard_asr_engine_test.dart',
    'reliable-recording':
        'flutter test integration_test/reliable_recording_test.dart',
    'android-emulator-meeting-flow':
        'flutter test integration_test/android_emulator_meeting_flow_test.dart',
  };
  for (final entry in logs.entries) {
    final relative = p.join('logs', '${entry.key}.log');
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    results.add({
      'name': entry.key,
      'command': commands[entry.key],
      'exitCode': 0,
      'elapsedMs': 1,
      'log': relative,
    });
  }
  return {
    'schemaVersion': 1,
    'status': 'failed',
    'capturedAtUtc': '2026-07-31T00:00:00Z',
    'error': 'post-processing failed',
    'results': results,
  };
}
