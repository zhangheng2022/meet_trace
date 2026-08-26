import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/release/release_orchestration_gate.dart';

void main() {
  group('verifyReleaseOrchestrationGate', () {
    test('接受单次 Android 与两阶段 Windows Store 精确回执', () {
      final receipt = verifyReleaseOrchestrationGate(
        jsonEncode(_gate()),
        _request(),
      );

      expect(receipt['releaseId'], 'v1.2.3-alpha.4');
      expect(receipt['testFlightBuildId'], 'build-2001');
      expect(receipt['androidValidationRunId'], 101);
      expect(receipt['windowsFlightSubmissionId'], 'flight-1');
      expect(receipt['windowsProductionSubmissionId'], 'production-1');
    });

    test('拒绝未通过 Beta App Review 的 TestFlight 证据', () {
      final gate = _gate();
      (gate['testFlight']! as Map<String, Object?>)['betaReviewState'] =
          'IN_REVIEW';

      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );
    });

    test('拒绝非 Apple 官方 IN_BETA_TESTING 的外测状态', () {
      for (final state in <String>[
        'TESTING',
        'READY_FOR_EXTERNAL_TESTING',
        'READY_FOR_BETA_TESTING',
        'BETA_APPROVED',
      ]) {
        final gate = _gate();
        (gate['testFlight']! as Map<String, Object?>)['externalBuildState'] =
            state;

        expect(
          () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
          throwsFormatException,
        );
      }
    });

    test('拒绝旧版 schema 2 门禁', () {
      final gate = _gate();
      gate['schemaVersion'] = 2;

      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );
    });

    test('接受带原始 Artifact 证明的 Android 单次验证复用', () {
      final gate = _gate();
      final validations = gate['validations']! as Map<String, Object?>;
      final android = validations['android']! as Map<String, Object?>;
      android
        ..['validationRunId'] = 99
        ..['reused'] = true
        ..['reusedFromRunId'] = 99
        ..['reusedFromArtifactId'] = 1234
        ..['reusedFromArtifactName'] =
            'meettrace-android-distribution-v1.2.3-alpha.4'
        ..['originalReceiptSha256'] = 'c' * 64;

      final receipt = verifyReleaseOrchestrationGate(
        jsonEncode(gate),
        _request(),
      );

      expect(receipt['androidValidationRunId'], 99);
    });

    test('拒绝缺少原始 Artifact 证明的 Android 回执复制', () {
      final gate = _gate();
      final validations = gate['validations']! as Map<String, Object?>;
      (validations['android']! as Map<String, Object?>)['validationRunId'] = 99;

      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );
    });

    test('拒绝 Android 验证回执绑定其他 APK 摘要', () {
      final gate = _gate();
      final validations = gate['validations']! as Map<String, Object?>;
      (validations['android']! as Map<String, Object?>)['artifactSha256'] =
          'c' * 64;

      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );
    });

    test('拒绝 Flight 回执绑定其他候选', () {
      final gate = _gate();
      final flight = gate['windowsFlight']! as Map<String, Object?>;
      flight['candidateCommitSha'] = 'c' * 40;

      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );
    });

    test('拒绝生产包不公开或不是同一 MSIX', () {
      final gate = _gate();
      final production = gate['windowsProduction']! as Map<String, Object?>;
      production['visibility'] = 'Hidden';

      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );

      production['visibility'] = 'Public';
      (production['package']! as Map<String, Object?>)['fileName'] =
          'different.msix';
      expect(
        () => verifyReleaseOrchestrationGate(jsonEncode(gate), _request()),
        throwsFormatException,
      );
    });

    test('拒绝门禁来源运行与最终发布输入不一致', () {
      expect(
        () => verifyReleaseOrchestrationGate(
          jsonEncode(_gate()),
          _request(sourceRunId: 999),
        ),
        throwsFormatException,
      );
    });
  });
}

ReleaseOrchestrationGateRequest _request({int sourceRunId = 101}) =>
    ReleaseOrchestrationGateRequest(
      releaseId: 'v1.2.3-alpha.4',
      candidateCommitSha: 'a' * 40,
      sourceRunId: sourceRunId,
      orchestrationRunId: 202,
      buildNumber: 2001,
      marketingVersion: '1.2.3',
      testFlightExternalGroup: 'MeetTrace External',
      androidArtifactSha256: 'b' * 64,
      windowsArtifactName: 'meettrace-v1.2.3-alpha.4-windows-store-x64.msix',
      windowsPackageVersion: '1.0.2001.0',
      windowsFlightId: 'flight-fixed',
      testFlightPublicLink: Uri.parse(
        'https://testflight.apple.com/join/MeetTrace',
      ),
    );

Map<String, Object?> _gate() => <String, Object?>{
  'schemaVersion': 3,
  'releaseId': 'v1.2.3-alpha.4',
  'candidateCommitSha': 'a' * 40,
  'sourceRunId': 101,
  'orchestrationRunId': 202,
  'buildNumber': 2001,
  'testFlight': <String, Object?>{
    'schemaVersion': 1,
    'distribution': 'testFlightExternal',
    'verificationMode': 'appStoreConnectApi',
    'releaseId': 'v1.2.3-alpha.4',
    'candidateCommitSha': 'a' * 40,
    'sourceRunId': 101,
    'buildNumber': 2001,
    'bundleId': 'com.meettrace.app',
    'marketingVersion': '1.2.3',
    'buildId': 'build-2001',
    'processingState': 'VALID',
    'betaReviewState': 'APPROVED',
    'externalBuildState': 'IN_BETA_TESTING',
    'testing': true,
    'expired': false,
    'externalGroup': 'MeetTrace External',
    'publicLink': 'https://testflight.apple.com/join/MeetTrace',
  },
  'windowsFlight': <String, Object?>{
    ..._storeReceipt('microsoftStoreFlight', 'flight-1'),
    'flightId': 'flight-fixed',
  },
  'windowsProduction': <String, Object?>{
    ..._storeReceipt('microsoftStore', 'production-1'),
    'visibility': 'Public',
  },
  'validations': <String, Object?>{
    'android': <String, Object?>{
      'schemaVersion': 2,
      'validation': 'androidCandidateDistribution',
      'releaseId': 'v1.2.3-alpha.4',
      'candidateCommitSha': 'a' * 40,
      'sourceRunId': 101,
      'validationRunId': 101,
      'androidFirebaseArm': 'passed',
      'artifactSha256': 'b' * 64,
      'reused': false,
    },
  },
};

Map<String, Object?> _storeReceipt(String distribution, String submissionId) =>
    <String, Object?>{
      'schemaVersion': 1,
      'distribution': distribution,
      'verificationMode': 'partnerCenterApi',
      'productId': '9PHHSJMWK06G',
      'submissionId': submissionId,
      'status': 'Published',
      'releaseId': 'v1.2.3-alpha.4',
      'candidateCommitSha': 'a' * 40,
      'sourceRunId': 101,
      'package': <String, Object?>{
        'fileName': 'meettrace-v1.2.3-alpha.4-windows-store-x64.msix',
        'version': '1.0.2001.0',
        'architecture': 'x64',
        'fileStatus': 'Uploaded',
      },
    };
