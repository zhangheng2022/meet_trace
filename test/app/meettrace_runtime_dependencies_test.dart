import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/app/meettrace_runtime_dependencies.dart';

void main() {
  test('Manifest 瞬时读取失败后显式重试会重新访问资源包', () async {
    final bundle = _RecoveringAssetBundle();

    await expectLater(
      loadRuntimeManifestAsset('assets/models/manifest.json', bundle: bundle),
      throwsA(isA<FlutterError>()),
    );

    expect(
      await loadRuntimeManifestAsset(
        'assets/models/manifest.json',
        bundle: bundle,
      ),
      '{"schemaVersion":1}',
    );
    expect(bundle.loadCalls, 2);
  });
}

final class _RecoveringAssetBundle extends CachingAssetBundle {
  int loadCalls = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCalls++;
    if (loadCalls == 1) {
      throw FlutterError('transient missing asset');
    }
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode('{"schemaVersion":1}')),
    );
  }
}
