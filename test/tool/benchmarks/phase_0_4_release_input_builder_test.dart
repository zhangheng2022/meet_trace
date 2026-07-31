import 'package:flutter_test/flutter_test.dart';

import '../../../tool/benchmarks/phase_0_4_release_input_builder.dart';

void main() {
  group('Phase04ReleaseInputBuilder', () {
    test('从 Android 模拟器原始证据推导工程门禁并绑定 SHA-256', () {
      final input = const Phase04ReleaseInputBuilder().build(
        template: _template(),
        androidEvidence: _androidEvidence(),
        androidEvidenceRef:
            'docs/quality/evidence/android-emulator/android-emulator-smoke.json',
        androidEvidenceSha256: 'a' * 64,
      );
      final environment = input['environment']! as Map<String, Object?>;
      final phase04 = input['phase04']! as Map<String, Object?>;
      final vad = input['vad']! as Map<String, Object?>;
      final evidence = input['evidence']! as Map<String, Object?>;

      expect(input['evaluationScope'], 'phase-0-4');
      expect(environment['deviceId'], 'android-emulator-x86_64-api-36');
      expect(phase04['meetingModelLocked'], isTrue);
      expect(phase04['factPcmSoleSourcePassed'], isTrue);
      expect(phase04['emulatorLifecyclePassed'], isTrue);
      expect(phase04['asrFailureRecordingContinues'], isTrue);
      expect(phase04['asrContextLifecyclePassed'], isTrue);
      expect(phase04['vadContextLifecyclePassed'], isTrue);
      expect(vad['failureRecordingContinues'], isTrue);
      expect(evidence['androidSha256'], 'a' * 64);
      expect(input.toString(), isNot(contains('.pcm')));
      expect(input.toString(), isNot(contains('emulator-5554')));
    });

    test('生命周期不足时生成 failed 值而不是伪造通过', () {
      final android = _androidEvidence();
      final measurements = android['measurements']! as Map<String, Object?>;
      final meetingLifecycle =
          measurements['meetingLifecycle']! as Map<String, Object?>;
      final asrLifecycle =
          measurements['asrLifecycle']! as Map<String, Object?>;
      meetingLifecycle['cycles'] = 9;
      asrLifecycle['steadyStateGrowthBytes'] = 40 * 1024 * 1024;

      final input = const Phase04ReleaseInputBuilder().build(
        template: _template(),
        androidEvidence: android,
        androidEvidenceRef: 'evidence/android.json',
        androidEvidenceSha256: 'b' * 64,
      );
      final phase04 = input['phase04']! as Map<String, Object?>;

      expect(phase04['emulatorLifecyclePassed'], isFalse);
      expect(phase04['asrContextLifecyclePassed'], isFalse);
    });

    test('已有质量证据时不被后续 Android 冒烟覆盖评测设备', () {
      final template = _template()..['rawMetricsRef'] = 'evidence/quality.json';
      (template['environment']! as Map<String, Object?>)['deviceId'] =
          'quality-device';

      final input = const Phase04ReleaseInputBuilder().build(
        template: template,
        androidEvidence: _androidEvidence(),
        androidEvidenceRef: 'evidence/android.json',
        androidEvidenceSha256: 'a' * 64,
      );

      expect(
        (input['environment']! as Map<String, Object?>)['deviceId'],
        'quality-device',
      );
    });

    test('拒绝非 passed、非 x86_64 或无效哈希证据', () {
      final failed = _androidEvidence()..['status'] = 'failed';
      expect(
        () => const Phase04ReleaseInputBuilder().build(
          template: _template(),
          androidEvidence: failed,
          androidEvidenceRef: 'evidence/android.json',
          androidEvidenceSha256: 'c' * 64,
        ),
        throwsFormatException,
      );

      final arm64 = _androidEvidence()..['abi'] = 'arm64-v8a';
      expect(
        () => const Phase04ReleaseInputBuilder().build(
          template: _template(),
          androidEvidence: arm64,
          androidEvidenceRef: 'evidence/android.json',
          androidEvidenceSha256: 'd' * 64,
        ),
        throwsFormatException,
      );

      expect(
        () => const Phase04ReleaseInputBuilder().build(
          template: _template(),
          androidEvidence: _androidEvidence(),
          androidEvidenceRef: 'evidence/android.json',
          androidEvidenceSha256: 'pending',
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _template() => {
  'schemaVersion': 7,
  'rawMetricsRef': null,
  'rawMetricsSha256': null,
  'environment': <String, Object?>{'deviceId': null},
  'vad': <String, Object?>{'failureRecordingContinues': null},
  'phase04': <String, Object?>{
    'productBoundaryApproved': true,
    'meetingModelLocked': null,
    'factPcmSoleSourcePassed': null,
    'emulatorLifecyclePassed': null,
    'asrFailureRecordingContinues': null,
    'startFailureDiagnosticsPassed': true,
    'asrContextLifecyclePassed': null,
    'vadContextLifecyclePassed': null,
  },
  'evidence': <String, Object?>{'android': null},
};

Map<String, Object?> _androidEvidence() => {
  'schemaVersion': 1,
  'status': 'passed',
  'platform': 'android-emulator',
  'abi': 'x86_64',
  'apiLevel': 36,
  'measurements': <String, Object?>{
    'recording': <String, Object?>{'persistenceRatio': 1.0},
    'meetingFlow': <String, Object?>{
      'meetingModelLocked': true,
      'factPcmSoleSourcePassed': true,
      'previewDegradedWithoutRecordingLoss': true,
      'audioBytes': 163200,
    },
    'asrLifecycle': <String, Object?>{
      'cycles': 100,
      'disposeIdempotent': true,
      'steadyStateGrowthBytes': 1024,
      'steadyStateGrowthLimitBytes': 32 * 1024 * 1024,
    },
    'vadLifecycle': <String, Object?>{
      'cycles': 100,
      'cancelResetVerified': true,
      'workerIsolateVerified': true,
      'disposeIdempotent': true,
      'steadyStateGrowthBytes': 1024,
    },
    'recordingLifecycle': <String, Object?>{
      'cycles': 100,
      'allCaptureStreamsClosed': true,
    },
    'meetingLifecycle': <String, Object?>{
      'cycles': 10,
      'sealedMeetings': 10,
      'allCaptureStreamsClosed': true,
      'allPreviewSessionsDisposed': true,
      'allModelLeasesReleased': true,
    },
  },
};
