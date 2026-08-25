import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/release/testflight_submission.dart';

void main() {
  group('verifyTestFlightStatus', () {
    test('接受已审批且在固定外测组 Testing 的 build', () {
      final receipt = verifyTestFlightStatus(jsonEncode(_status()), _request());

      expect(receipt['distribution'], 'testFlightExternal');
      expect(receipt['verificationMode'], 'appStoreConnectApi');
      expect(receipt['buildId'], 'build-123');
      expect(receipt['betaReviewState'], 'APPROVED');
      expect(receipt['testing'], isTrue);
      expect(receipt['sourceRunId'], 123);
    });

    test('拒绝未处理完或未通过 Beta App Review 的 build', () {
      for (final status in <Map<String, Object?>>[
        _status()..['processingState'] = 'PROCESSING',
        _status()..['betaReviewState'] = 'IN_REVIEW',
        _status()..['externalBuildState'] = 'WAITING_FOR_BETA_REVIEW',
        _status()..['testing'] = false,
      ]) {
        expect(
          () => verifyTestFlightStatus(jsonEncode(status), _request()),
          throwsFormatException,
        );
      }
    });

    test('拒绝过期、错误外测组或临时 public link', () {
      final expired = _status()..['expired'] = true;
      final wrongGroup = _status()
        ..['externalGroups'] = <Object?>['Different Group'];
      final wrongLink = _status()
        ..['publicLink'] = 'https://testflight.apple.com/join/OTHER';

      for (final status in [expired, wrongGroup, wrongLink]) {
        expect(
          () => verifyTestFlightStatus(jsonEncode(status), _request()),
          throwsFormatException,
        );
      }
    });

    test('拒绝版本、构建号或候选身份不匹配', () {
      final wrongSchema = _status()..['schemaVersion'] = 2;
      final wrongVersion = _status()..['marketingVersion'] = '1.0.1';
      final wrongBuild = _status()..['buildNumber'] = 2002;
      for (final status in [wrongSchema, wrongVersion, wrongBuild]) {
        expect(
          () => verifyTestFlightStatus(jsonEncode(status), _request()),
          throwsFormatException,
        );
      }
      expect(
        () => verifyTestFlightStatus(
          jsonEncode(_status()),
          _request(candidateCommitSha: 'A' * 40),
        ),
        throwsFormatException,
      );
    });

    test('拒绝不安全 ID 和超过 512 KiB 的响应', () {
      final unsafe = _status()..['buildId'] = 'build\nspoof';
      expect(
        () => verifyTestFlightStatus(jsonEncode(unsafe), _request()),
        throwsFormatException,
      );
      expect(
        () => verifyTestFlightStatus(
          ' ' * (testFlightStatusMaximumResponseBytes + 1),
          _request(),
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _status() => <String, Object?>{
  'schemaVersion': 1,
  'bundleId': 'com.meettrace.app',
  'marketingVersion': '1.0.0',
  'buildNumber': '2001',
  'appId': 'app-123',
  'buildId': 'build-123',
  'processingState': 'VALID',
  'expired': false,
  'betaReviewState': 'APPROVED',
  'externalBuildState': 'READY_FOR_EXTERNAL_TESTING',
  'testing': true,
  'externalGroups': <Object?>['MeetTrace Alpha'],
  'publicLink': 'https://testflight.apple.com/join/ABC123',
};

TestFlightVerificationRequest _request({
  String candidateCommitSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => TestFlightVerificationRequest(
  bundleId: 'com.meettrace.app',
  marketingVersion: '1.0.0',
  buildNumber: 2001,
  externalGroup: 'MeetTrace Alpha',
  publicLink: Uri.parse('https://testflight.apple.com/join/ABC123'),
  releaseId: 'v1.0.0-alpha.1',
  candidateCommitSha: candidateCommitSha,
  sourceRunId: 123,
  verifiedAt: DateTime.utc(2026, 8, 25),
);
