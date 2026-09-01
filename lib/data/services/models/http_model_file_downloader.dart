import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'downloadable_model_service.dart';
import 'model_download_types.dart';

final class HttpModelFileDownloader implements ModelFileDownloader {
  HttpModelFileDownloader({
    HttpClient Function()? clientFactory,
    this.requireHttps = true,
    this.responseBodyTimeout = const Duration(seconds: 60),
  }) : _clientFactory = clientFactory ?? HttpClient.new {
    if (responseBodyTimeout <= Duration.zero) {
      throw ArgumentError.value(
        responseBodyTimeout,
        'responseBodyTimeout',
        '必须大于零',
      );
    }
  }

  final HttpClient Function() _clientFactory;
  final bool requireHttps;
  final Duration responseBodyTimeout;

  @override
  Future<ModelFileDownloadResult> download({
    required Uri source,
    required String destinationPath,
    required int resumeFrom,
    required int expectedBytes,
    required ModelDownloadCancellationToken cancellation,
    required void Function(int absoluteFileBytes) onProgress,
  }) async {
    if (requireHttps && source.scheme != 'https') {
      throw const DownloadableModelException(
        code: 'model.download.url',
        message: '模型下载只允许 HTTPS',
      );
    }
    if (resumeFrom < 0 || resumeFrom > expectedBytes) {
      throw ArgumentError.value(resumeFrom, 'resumeFrom', '超出文件范围');
    }

    cancellation.throwIfCanceled();
    await Directory(p.dirname(destinationPath)).create(recursive: true);
    final ioClient = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
    final client = SentryHttpClient(
      client: IOClient(ioClient),
      captureFailedRequests: false,
    );
    void cancelRequest() => ioClient.close(force: true);
    cancellation.addCancelListener(cancelRequest);

    RandomAccessFile? output;
    try {
      final request = http.Request('GET', source)
        ..headers[HttpHeaders.userAgentHeader] = 'MeetTrace-Mobile-Alpha/1.0';
      if (resumeFrom > 0) {
        request.headers[HttpHeaders.rangeHeader] = 'bytes=$resumeFrom-';
      }
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      cancellation.throwIfCanceled();

      final acceptedResume =
          resumeFrom > 0 && response.statusCode == HttpStatus.partialContent;
      if (response.statusCode != HttpStatus.ok && !acceptedResume) {
        throw DownloadableModelException(
          code: 'model.download.http.${response.statusCode}',
          message: '模型文件下载失败：HTTP ${response.statusCode}',
        );
      }
      if (acceptedResume) {
        final contentRange = response.headers[HttpHeaders.contentRangeHeader];
        if (contentRange == null ||
            !contentRange.startsWith('bytes $resumeFrom-')) {
          throw const DownloadableModelException(
            code: 'model.download.range',
            message: '服务器返回了不兼容的续传范围',
          );
        }
      }

      final effectiveStart = acceptedResume ? resumeFrom : 0;
      output = await File(destinationPath)
          .open(mode: acceptedResume ? FileMode.append : FileMode.write);
      var written = effectiveStart;
      onProgress(written);
      await for (final chunk in response.stream.timeout(responseBodyTimeout)) {
        cancellation.throwIfCanceled();
        await output.writeFrom(chunk);
        written += chunk.length;
        if (written > expectedBytes) {
          throw const DownloadableModelException(
            code: 'model.download.size',
            message: '服务器返回的模型文件超过 Manifest 大小',
          );
        }
        onProgress(written);
      }
      cancellation.throwIfCanceled();
      await output.flush();
      return ModelFileDownloadResult(
        finalBytes: written,
        resumed: acceptedResume,
      );
    } on TimeoutException catch (error, stackTrace) {
      if (cancellation.isCanceled) {
        Error.throwWithStackTrace(
          const ModelDownloadCanceledException(),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(
        DownloadableModelException(
          code: 'model.download.timeout',
          message: '模型文件下载超时，请重试',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      if (cancellation.isCanceled && error is! ModelDownloadCanceledException) {
        Error.throwWithStackTrace(
          const ModelDownloadCanceledException(),
          stackTrace,
        );
      }
      rethrow;
    } finally {
      cancellation.removeCancelListener(cancelRequest);
      ioClient.close(force: true);
      client.close();
      await output?.close();
    }
  }
}
