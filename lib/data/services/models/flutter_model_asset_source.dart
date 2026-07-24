import 'package:flutter/services.dart';

import 'bundled_model_preparation_service.dart';

final class FlutterModelAssetSource implements ModelAssetSource {
  const FlutterModelAssetSource(this.bundle);

  final AssetBundle bundle;

  @override
  Future<Uint8List> load(String assetUrl) async {
    final uri = Uri.tryParse(assetUrl);
    if (uri == null || uri.scheme != 'asset') {
      throw ArgumentError.value(assetUrl, 'assetUrl', '必须使用 asset:// URL');
    }
    final key = [uri.host, ...uri.pathSegments].join('/');
    if (key.isEmpty) {
      throw ArgumentError.value(assetUrl, 'assetUrl', '缺少 asset key');
    }
    final data = await bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
