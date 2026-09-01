import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

final class BoundedHttpsClient {
  BoundedHttpsClient({
    http.Client? client,
    this.allowInsecureLocalhostForTesting = false,
    this.maxRedirects = 5,
  }) : _client = SentryHttpClient(client: client, captureFailedRequests: false);

  final SentryHttpClient _client;
  final bool allowInsecureLocalhostForTesting;
  final int maxRedirects;

  Future<Uint8List> getBytes(Uri uri, {required int maxBytes}) async {
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes');
    }
    final response = await _open(uri);
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > maxBytes) {
      await response.stream.drain<void>();
      throw const HttpException('响应超过允许大小');
    }
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      received += chunk.length;
      if (received > maxBytes) {
        throw const HttpException('响应超过允许大小');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<void> download({
    required Uri uri,
    required File destination,
    required int expectedBytes,
  }) async {
    if (expectedBytes <= 0) {
      throw ArgumentError.value(expectedBytes, 'expectedBytes');
    }
    final response = await _open(uri);
    if (response.contentLength != null &&
        response.contentLength != expectedBytes) {
      await response.stream.drain<void>();
      throw const HttpException('下载长度与 Manifest 不一致');
    }
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(minutes: 5),
      )) {
        received += chunk.length;
        if (received > expectedBytes) {
          throw const HttpException('下载内容超过 Manifest 声明长度');
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (received != expectedBytes) {
      throw const HttpException('下载内容未达到 Manifest 声明长度');
    }
  }

  Future<http.StreamedResponse> _open(Uri initialUri) async {
    var uri = initialUri;
    for (var redirect = 0; redirect <= maxRedirects; redirect++) {
      _validateUri(uri);
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers[HttpHeaders.acceptHeader] = 'application/octet-stream'
        ..headers[HttpHeaders.userAgentHeader] = 'MeetTrace-AppUpdate/1';
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == HttpStatus.ok) {
        return response;
      }
      if (_isRedirect(response.statusCode)) {
        final location = response.headers[HttpHeaders.locationHeader];
        await response.stream.drain<void>();
        if (location == null || redirect == maxRedirects) {
          throw const HttpException('更新下载重定向无效或过多');
        }
        uri = uri.resolve(location);
        continue;
      }
      await response.stream.drain<void>();
      throw HttpException('更新服务器返回 HTTP ${response.statusCode}', uri: uri);
    }
    throw const HttpException('更新下载重定向过多');
  }

  void _validateUri(Uri uri) {
    final allowedTestUri =
        allowInsecureLocalhostForTesting &&
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost');
    if ((!uri.isScheme('https') && !allowedTestUri) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const HttpException('更新网络请求只允许无用户信息的 HTTPS URL');
    }
  }

  bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  void close() => _client.close();
}
