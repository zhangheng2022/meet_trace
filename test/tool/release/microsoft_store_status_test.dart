import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/release/microsoft_store_status.dart';

void main() {
  group('classifyMicrosoftStoreSubmission', () {
    test('接受精确的 Published/Public production', () {
      final result = _classify(
        status: 'Published',
        visibility: 'Public',
        packages: <Object?>[_package()],
      );

      expect(result, <String, Object?>{
        'ready': true,
        'present': true,
        'blocked': false,
        'status': 'Published',
      });
    });

    test('把首次 NotSubmitted 识别为可提交而非阻塞', () {
      final result = _classify(status: 'NotSubmitted', packages: const []);

      expect(result['ready'], false);
      expect(result['present'], false);
      expect(result['blocked'], false);
    });

    test('阻断携带候选包的异常 NotSubmitted', () {
      final result = _classify(
        status: 'NotSubmitted',
        packages: <Object?>[_package()],
      );

      expect(result['present'], true);
      expect(result['blocked'], true);
    });

    test('把无包的 production certification 识别为已存在的正常等待', () {
      final result = _classify(status: 'Certification', packages: const []);

      expect(result['ready'], false);
      expect(result['present'], true);
      expect(result['blocked'], false);
    });

    test('允许已发布旧包被新候选替换', () {
      final result = _classify(
        status: 'Published',
        visibility: 'Public',
        packages: <Object?>[
          _package(fileName: 'meettrace-v1.2.3-alpha.3-windows-store-x64.msix'),
        ],
      );

      expect(result['ready'], false);
      expect(result['present'], false);
      expect(result['blocked'], false);
    });

    test('阻断 Flight Published 回执中的错误包', () {
      final result = _classify(
        status: 'Published',
        production: false,
        packages: <Object?>[
          _package(fileName: 'meettrace-v1.2.3-alpha.3-windows-store-x64.msix'),
        ],
      );

      expect(result['ready'], false);
      expect(result['blocked'], true);
    });

    test('阻断未知状态并拒绝大小写重复字段', () {
      expect(
        () => _classify(status: 'Mystery', packages: const []),
        returnsNormally,
      );
      expect(_classify(status: 'Mystery', packages: const [])['blocked'], true);
      final source = jsonEncode(<String, Object?>{
        'Status': 'Published',
        'status': 'Published',
        'Visibility': 'Public',
        'ApplicationPackages': <Object?>[_package()],
      });
      expect(
        () => classifyMicrosoftStoreSubmission(
          source,
          expectedArtifactName: _artifactName,
          expectedPackageVersion: '1.0.2001.0',
          production: true,
        ),
        throwsFormatException,
      );
    });
  });
}

const _artifactName = 'meettrace-v1.2.3-alpha.4-windows-store-x64.msix';

Map<String, Object?> _classify({
  required String status,
  required List<Object?> packages,
  String visibility = '',
  bool production = true,
}) => classifyMicrosoftStoreSubmission(
  jsonEncode(<String, Object?>{
    'Status': status,
    'Visibility': visibility,
    'ApplicationPackages': packages,
  }),
  expectedArtifactName: _artifactName,
  expectedPackageVersion: '1.0.2001.0',
  production: production,
);

Map<String, Object?> _package({String fileName = _artifactName}) =>
    <String, Object?>{
      'FileName': fileName,
      'Version': '1.0.2001.0',
      'Architecture': 'x64',
      'FileStatus': 'Uploaded',
    };
