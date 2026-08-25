import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/release/release_orchestration_gate.dart';

void main() {
  group('verifyReleaseOrchestrationGate', () {
    test('接受同一候选的 TestFlight、Store 和两阶段真实分发证据', () {
      final receipt = verifyReleaseOrchestrationGate(
        jsonEncode(_gate()),
        _request(),
      );

      expect(receipt['releaseId'], 'v1.2.3-alpha.4');
      expect(receipt['testFlightBuildId'], 'build-2001');
      expect(receipt['flightValidationRunId'], 301);
      expect(receipt['productionValidationRunId'], 302);
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

    test('拒绝 Flight 与 production 复用同一次专用机验证', () {
      final gate = _gate();
      final validations = gate['validations']! as Map<String, Object?>;
      (validations['production']! as Map<String, Object?>)['validationRunId'] =
          301;

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
      windowsArtifactName: 'meettrace-v1.2.3-alpha.4-windows-store-x64.msix',
      windowsPackageVersion: '1.0.2001.0',
      windowsFlightId: 'flight-fixed',
      testFlightPublicLink: Uri.parse(
        'https://testflight.apple.com/join/MeetTrace',
      ),
    );

Map<String, Object?> _gate() => <String, Object?>{
  'schemaVersion': 1,
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
    'externalBuildState': 'TESTING',
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
    'flight': _validation('flight', 301),
    'production': _validation('production', 302),
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

Map<String, Object?> _validation(String stage, int validationRunId) =>
    <String, Object?>{
      'schemaVersion': 1,
      'validation': 'candidateDistribution',
      'stage': stage,
      'releaseId': 'v1.2.3-alpha.4',
      'candidateCommitSha': 'a' * 40,
      'sourceRunId': 101,
      'reconcileRunId': 202,
      'validationRunId': validationRunId,
      'androidFirebaseArm': 'passed',
      'windowsStoreLifecycle': 'passed',
    };
