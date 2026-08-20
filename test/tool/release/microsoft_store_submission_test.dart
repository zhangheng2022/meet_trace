import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/release/microsoft_store_submission.dart';

void main() {
  group('verifyMicrosoftStoreSubmission', () {
    test('接受同一公开 x64 Store 版本并生成去敏回执', () {
      final receipt = verifyMicrosoftStoreSubmission(
        jsonEncode(_submission()),
        _request(),
      );

      expect(receipt['productId'], '9PHHSJMWK06G');
      expect(receipt['verificationMode'], 'partnerCenterApi');
      expect(receipt['submissionId'], 'submission-123');
      expect(receipt['status'], 'Published');
      expect(receipt['visibility'], 'Public');
      expect(receipt['candidateCommitSha'], 'a' * 40);
      expect(receipt['sourceRunId'], 123);
      expect(receipt.toString(), isNot(contains('client-secret')));
      expect(receipt['package'], <String, Object?>{
        'fileName': 'meettrace-v1.0.0-alpha.1-windows-store-x64.msix',
        'version': '1.0.11.0',
        'architecture': 'x64',
        'fileStatus': 'Uploaded',
      });
    });

    test('兼容 Microsoft CLI 的字段大小写但拒绝重复字段', () {
      final lowerCase = _submission().map(
        (key, value) => MapEntry(key.toLowerCase(), value),
      );
      expect(
        verifyMicrosoftStoreSubmission(jsonEncode(lowerCase), _request()),
        isNotEmpty,
      );

      final duplicated = _submission()..['status'] = 'Published';
      expect(
        () =>
            verifyMicrosoftStoreSubmission(jsonEncode(duplicated), _request()),
        throwsFormatException,
      );
    });

    test('拒绝尚未公开或仍为 Private 的 submission', () {
      for (final submission in <Map<String, Object?>>[
        _submission()..['Status'] = 'Certification',
        _submission()..['Visibility'] = 'Private',
      ]) {
        expect(
          () => verifyMicrosoftStoreSubmission(
            jsonEncode(submission),
            _request(),
          ),
          throwsFormatException,
        );
      }
    });

    test('拒绝版本、文件名或架构不匹配的 Store 包', () {
      final mutations = <void Function(Map<String, Object?>)>[
        (package) => package['Version'] = '1.0.10.0',
        (package) => package['FileName'] = 'different.msix',
        (package) => package['Architecture'] = 'arm64',
      ];
      for (final mutate in mutations) {
        final submission = _submission();
        final package =
            (submission['ApplicationPackages']! as List).single
                as Map<String, Object?>;
        mutate(package);
        expect(
          () => verifyMicrosoftStoreSubmission(
            jsonEncode(submission),
            _request(),
          ),
          throwsFormatException,
        );
      }
    });

    test('拒绝未上传完成、多个包或缺失字段', () {
      final pending = _submission();
      ((pending['ApplicationPackages']! as List).single
              as Map<String, Object?>)['FileStatus'] =
          'PendingUpload';
      final multiple = _submission();
      (multiple['ApplicationPackages']! as List).add(<String, Object?>{
        'FileName': 'extra.msix',
        'Version': '1.0.11.0',
        'Architecture': 'x64',
        'FileStatus': 'Uploaded',
      });
      final missing = _submission()..remove('Id');

      for (final submission in [pending, multiple, missing]) {
        expect(
          () => verifyMicrosoftStoreSubmission(
            jsonEncode(submission),
            _request(),
          ),
          throwsFormatException,
        );
      }
    });

    test('拒绝不安全的 submission ID 和超过 2 MiB 的响应', () {
      final unsafeId = _submission()
        ..['Id'] = 'submission\n[伪造摘要](https://example.com)';
      expect(
        () => verifyMicrosoftStoreSubmission(jsonEncode(unsafeId), _request()),
        throwsFormatException,
      );
      expect(
        () => verifyMicrosoftStoreSubmission(
          ' ' * (microsoftStoreSubmissionMaximumResponseBytes + 1),
          _request(),
        ),
        throwsFormatException,
      );
    });

    test('拒绝错误产品、来源身份和非 UTC 时间', () {
      final invalidRequests = <MicrosoftStoreSubmissionVerificationRequest>[
        _request(productId: 'OTHER'),
        _request(expectedPackageVersion: '1.0.65536.0'),
        _request(candidateCommitSha: 'A' * 40),
        _request(sourceRunId: 0),
        _request(verifiedAt: DateTime(2026, 8, 20)),
      ];
      for (final request in invalidRequests) {
        expect(
          () => verifyMicrosoftStoreSubmission(
            jsonEncode(_submission()),
            request,
          ),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, Object?> _submission() => <String, Object?>{
  'Id': 'submission-123',
  'Status': 'Published',
  'Visibility': 'Public',
  'ApplicationPackages': <Object?>[
    <String, Object?>{
      'FileName': 'meettrace-v1.0.0-alpha.1-windows-store-x64.msix',
      'Version': '1.0.11.0',
      'Architecture': 'X64',
      'FileStatus': 'Uploaded',
    },
  ],
};

MicrosoftStoreSubmissionVerificationRequest _request({
  String productId = '9PHHSJMWK06G',
  String expectedPackageVersion = '1.0.11.0',
  String candidateCommitSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int sourceRunId = 123,
  DateTime? verifiedAt,
}) => MicrosoftStoreSubmissionVerificationRequest(
  productId: productId,
  expectedPackageVersion: expectedPackageVersion,
  expectedArtifactName: 'meettrace-v1.0.0-alpha.1-windows-store-x64.msix',
  releaseId: 'v1.0.0-alpha.1',
  candidateCommitSha: candidateCommitSha,
  sourceRunId: sourceRunId,
  verifiedAt: verifiedAt ?? DateTime.utc(2026, 8, 20),
);
