import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/updates/bounded_https_client.dart';

void main() {
  late HttpServer server;
  late BoundedHttpsClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = BoundedHttpsClient(allowInsecureLocalhostForTesting: true);
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('读取受限响应并跟随同样受 HTTPS 规则约束的重定向', () async {
    server.listen((request) async {
      if (request.uri.path == '/redirect') {
        request.response
          ..statusCode = HttpStatus.temporaryRedirect
          ..headers.set(HttpHeaders.locationHeader, '/manifest');
      } else {
        request.response.add(<int>[1, 2, 3]);
      }
      await request.response.close();
    });

    final bytes = await client.getBytes(_uri(server, '/redirect'), maxBytes: 3);

    expect(bytes, <int>[1, 2, 3]);
  });

  test('拒绝超出上限的响应和非 HTTPS 外部地址', () async {
    server.listen((request) async {
      request.response.add(List<int>.filled(5, 1));
      await request.response.close();
    });

    await expectLater(
      client.getBytes(_uri(server, '/large'), maxBytes: 4),
      throwsA(isA<HttpException>()),
    );
    await expectLater(
      client.getBytes(Uri.parse('http://example.test/file'), maxBytes: 4),
      throwsA(isA<HttpException>()),
    );
  });

  test('下载必须精确匹配 Manifest 声明长度', () async {
    final temporary = await Directory.systemTemp.createTemp('update-http-');
    addTearDown(() => temporary.delete(recursive: true));
    server.listen((request) async {
      request.response
        ..contentLength = 3
        ..add(<int>[1, 2, 3]);
      await request.response.close();
    });

    final output = File('${temporary.path}/update.apk');
    await client.download(
      uri: _uri(server, '/apk'),
      destination: output,
      expectedBytes: 3,
    );
    expect(await output.readAsBytes(), <int>[1, 2, 3]);

    await expectLater(
      client.download(
        uri: _uri(server, '/apk'),
        destination: output,
        expectedBytes: 4,
      ),
      throwsA(isA<HttpException>()),
    );
  });
}

Uri _uri(HttpServer server, String path) =>
    Uri.parse('http://${server.address.address}:${server.port}$path');
