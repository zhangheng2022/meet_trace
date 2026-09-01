import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/services/monitoring/sentry_monitoring.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('HTTP Breadcrumb 只保留域名、方法、状态码和耗时', () {
    final breadcrumb = Breadcrumb.http(
      url: Uri.parse(
        'https://download.example.com/models/private.bin?token=secret#part',
      ),
      method: 'get',
      statusCode: 503,
      reason: 'private failure detail',
      requestDuration: const Duration(milliseconds: 250),
      requestBodySize: 12,
      responseBodySize: 34,
    );

    final sanitized = SentryMonitoring.sanitizeBreadcrumb(breadcrumb, Hint());

    expect(sanitized?.message, isNull);
    expect(sanitized?.data, {
      'url': 'download.example.com',
      'method': 'GET',
      'status_code': 503,
      'duration': '0:00:00.250000',
    });
  });

  test('错误事件删除 HTTP 内容、标识和请求细节', () {
    final event = SentryEvent(
      user: SentryUser(id: 'persistent-user'),
      serverName: 'private-device-name',
      request: SentryRequest(
        url: 'https://api.example.com/meetings/secret?id=42',
        method: 'post',
        queryString: 'id=42',
        cookies: 'session=secret',
        data: 'private body',
        headers: {'Authorization': 'secret'},
      ),
    );

    final sanitized = SentryMonitoring.sanitizeEvent(event, Hint());

    expect(sanitized?.user, isNull);
    expect(sanitized?.serverName, isNull);
    expect(sanitized?.request?.url, 'api.example.com');
    expect(sanitized?.request?.method, 'POST');
    expect(sanitized?.request?.queryString, isNull);
    expect(sanitized?.request?.cookies, isNull);
    expect(sanitized?.request?.data, isNull);
    expect(sanitized?.request?.headers, isEmpty);
  });

  test('Metrics Hook 只允许匿名录音性能窗口', () {
    final recording = SentryGaugeMetric(
      timestamp: DateTime.utc(2026),
      name: 'recording.write_backlog',
      value: 2,
      traceId: SentryId.newId(),
    );
    final business = SentryGaugeMetric(
      timestamp: DateTime.utc(2026),
      name: 'feature.share.count',
      value: 1,
      traceId: SentryId.newId(),
    );

    expect(SentryMonitoring.sanitizeMetric(recording), same(recording));
    expect(SentryMonitoring.sanitizeMetric(business), isNull);
  });
}
