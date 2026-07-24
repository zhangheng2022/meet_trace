import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/models/flutter_model_asset_source.dart';

void main() {
  test('asset URL 映射为 Flutter asset key', () async {
    final bundle = _FakeAssetBundle();
    final source = FlutterModelAssetSource(bundle);

    final bytes = await source.load(
      'asset://assets/models/paraformer/model.onnx',
    );

    expect(bundle.lastKey, 'assets/models/paraformer/model.onnx');
    expect(bytes, [1, 2, 3]);
  });

  test('拒绝非 asset URL', () {
    final source = FlutterModelAssetSource(_FakeAssetBundle());

    expect(
      () => source.load('https://example.com/model.onnx'),
      throwsArgumentError,
    );
  });
}

final class _FakeAssetBundle extends CachingAssetBundle {
  String? lastKey;

  @override
  Future<ByteData> load(String key) async {
    lastKey = key;
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}
