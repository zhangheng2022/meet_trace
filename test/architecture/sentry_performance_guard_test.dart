import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全部 Dart 网络入口统一使用官方 SentryHttpClient', () async {
    for (final path in [
      'lib/data/services/models/http_model_file_downloader.dart',
      'lib/data/services/updates/bounded_https_client.dart',
    ]) {
      final source = await File(path).readAsString();
      expect(source, contains('SentryHttpClient'));
      expect(source, isNot(contains('HttpClient()')));
      expect(source, isNot(contains('HttpClient.new')));
    }
  });

  test('Sentry HTTP、Metrics 与传播隐私边界保持开启', () async {
    final bootstrap = await File(
      'lib/data/services/monitoring/sentry_bootstrap.dart',
    ).readAsString();
    final monitoring = await File(
      'lib/data/services/monitoring/sentry_monitoring.dart',
    ).readAsString();

    expect(bootstrap, contains('recordHttpBreadcrumbs = true'));
    expect(
      bootstrap,
      contains('maxRequestBodySize = MaxRequestBodySize.never'),
    );
    expect(bootstrap, contains('tracePropagationTargets.clear()'));
    expect(bootstrap, contains('beforeSendTransaction'));
    expect(bootstrap, contains('beforeSendMetric'));
    expect(monitoring, contains("metric.name.startsWith('recording.')"));
  });

  test('四个主页面保持静态命名路由与 TTFD 上报', () async {
    final flow = await File('lib/app/meettrace_flow.dart').readAsString();
    final recording = await File(
      'lib/ui/features/meetings/views/recording/recording_session_view.dart',
    ).readAsString();
    final detail = await File(
      'lib/ui/features/meetings/views/detail/meeting_detail_view.dart',
    ).readAsString();

    expect(flow, contains("RouteSettings(name: '/recording')"));
    expect(flow, contains("RouteSettings(name: '/meeting-detail')"));
    expect(flow, contains("RouteSettings(name: '/settings')"));
    expect(flow, contains('reportFullyDisplayed()'));
    expect(recording, contains('reportFullyDisplayed()'));
    expect(detail, contains('reportFullyDisplayed()'));
  });
}
