import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/data/services/models/downloadable_model_service.dart';
import 'package:meetily_ai/data/services/models/http_model_file_downloader.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('meetily-http-download-');
  });

  tearDown(() => root.delete(recursive: true));

  test('服务器支持 Range 时从已有字节续传', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestHandled = server.first.then((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=2-');
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 2-4/5')
        ..contentLength = 3;
      request.response.add('llo'.codeUnits);
      await request.response.close();
    });
    final destination = p.join(root.path, 'model.bin');
    await File(destination).writeAsString('he');
    final progress = <int>[];

    final result = await HttpModelFileDownloader(requireHttps: false).download(
      source: Uri.parse(
        'http://${server.address.address}:${server.port}/model.bin',
      ),
      destinationPath: destination,
      resumeFrom: 2,
      expectedBytes: 5,
      cancellation: ModelDownloadCancellationToken(),
      onProgress: progress.add,
    );
    await requestHandled;

    expect(result.resumed, isTrue);
    expect(result.finalBytes, 5);
    expect(await File(destination).readAsString(), 'hello');
    expect(progress, [2, 5]);
  });

  test('生产默认配置拒绝非 HTTPS 地址', () async {
    await expectLater(
      HttpModelFileDownloader().download(
        source: Uri.parse('http://example.com/model.bin'),
        destinationPath: p.join(root.path, 'model.bin'),
        resumeFrom: 0,
        expectedBytes: 5,
        cancellation: ModelDownloadCancellationToken(),
        onProgress: (_) {},
      ),
      throwsA(
        isA<DownloadableModelException>().having(
          (error) => error.code,
          'code',
          'model.download.url',
        ),
      ),
    );
  });
}
