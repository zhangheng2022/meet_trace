import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

abstract final class SentryMonitoring {
  static Future<T> trace<T>({
    required String name,
    required String operation,
    required Future<T> Function() run,
  }) async {
    ISentrySpan? span;
    try {
      span =
          Sentry.getSpan()?.startChild(operation, description: name) ??
          Sentry.startTransaction(name, operation, bindToScope: false);
    } on Object {
      // 遥测启动失败不能阻断被观测操作。
    }
    addBreadcrumb(category: operation, phase: 'started');
    try {
      final result = await run();
      span?.status = const SpanStatus.ok();
      addBreadcrumb(category: operation, phase: 'completed');
      return result;
    } on Object catch (error) {
      span
        ?..status = const SpanStatus.internalError()
        ..setData('error.type', error.runtimeType.toString());
      addBreadcrumb(
        category: operation,
        phase: 'failed',
        data: {'error_type': error.runtimeType.toString()},
      );
      rethrow;
    } finally {
      try {
        span?.finish().ignore();
      } on Object {
        // 遥测结束失败不能覆盖业务结果。
      }
    }
  }

  static void addBreadcrumb({
    required String category,
    required String phase,
    Map<String, Object?> data = const {},
  }) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: category,
          type: 'state',
          data: <String, Object?>{'phase': phase, ...data},
        ),
      ).ignore();
    } on Object {
      // Breadcrumb 是旁路诊断，失败不得影响主流程。
    }
  }

  static SentryEvent? sanitizeEvent(SentryEvent event, Hint _) {
    event
      ..user = null
      ..serverName = null
      ..request = _sanitizeRequest(event.request)
      ..breadcrumbs = _sanitizeBreadcrumbs(event.breadcrumbs);
    return event;
  }

  static SentryTransaction? sanitizeTransaction(
    SentryTransaction transaction,
    Hint _,
  ) {
    try {
      if (sanitizeEvent(transaction, Hint()) == null) {
        return null;
      }
      for (final span in transaction.spans) {
        if (span.context.operation == 'http.client') {
          _sanitizeHttpSpan(span);
        }
      }
      return transaction;
    } on Object {
      return null;
    }
  }

  static Breadcrumb? sanitizeBreadcrumb(Breadcrumb? breadcrumb, Hint _) {
    if (breadcrumb == null) {
      return null;
    }
    if (breadcrumb.type == 'http' || breadcrumb.category == 'http') {
      final source = breadcrumb.data ?? const <String, dynamic>{};
      breadcrumb
        ..message = null
        ..data = <String, Object?>{
          'url': ?_host(source['url']),
          'method': ?_method(source['method']),
          if (source['status_code'] case final num status)
            'status_code': status.toInt(),
          'duration': ?_duration(source['duration']),
        };
    }
    return breadcrumb;
  }

  static SentryMetric? sanitizeMetric(SentryMetric metric) =>
      metric.name.startsWith('recording.') ? metric : null;

  static void sanitizeSpan(SentrySpanV2 span) {
    final attributes = span.attributes;
    final isHttp = attributes.keys.any(
      (key) => key.startsWith('http.') || key.startsWith('url.'),
    );
    if (!isHttp) {
      return;
    }
    final host = _host(
      attributes['url.full']?.value ?? attributes['server.address']?.value,
    );
    final method = _method(attributes['http.request.method']?.value);
    final status = attributes['http.response.status_code']?.value;
    for (final key in attributes.keys.toList(growable: false)) {
      if (key.startsWith('http.') ||
          key.startsWith('url.') ||
          key.contains('header') ||
          key.contains('body') ||
          key.contains('file')) {
        span.removeAttribute(key);
      }
    }
    if (host != null) {
      span.setAttribute('server.address', SentryAttribute.string(host));
    }
    if (method != null) {
      span.setAttribute('http.request.method', SentryAttribute.string(method));
    }
    if (status is int) {
      span.setAttribute(
        'http.response.status_code',
        SentryAttribute.int(status),
      );
    }
    final name = [?method, ?host].join(' ');
    span.name = name.isEmpty ? 'HTTP' : name;
  }

  static List<Breadcrumb>? _sanitizeBreadcrumbs(List<Breadcrumb>? breadcrumbs) {
    if (breadcrumbs == null) {
      return null;
    }
    return [
      for (final breadcrumb in breadcrumbs)
        ?sanitizeBreadcrumb(breadcrumb, Hint()),
    ];
  }

  static SentryRequest? _sanitizeRequest(SentryRequest? request) {
    if (request == null) {
      return null;
    }
    return SentryRequest(
      url: _host(request.url),
      method: _method(request.method),
    );
  }

  static void _sanitizeHttpSpan(SentrySpan span) {
    final source = Map<String, dynamic>.from(span.data);
    final description = span.context.description;
    final describedUrl = description?.split(RegExp(r'\s+')).skip(1).firstOrNull;
    final host = _host(source['url'] ?? describedUrl);
    final method = _method(source['http.request.method']);
    final status = source['http.response.status_code'];
    final sanitizedDescription = [?method, ?host].join(' ');
    span.context.description = sanitizedDescription.isEmpty
        ? null
        : sanitizedDescription;
    for (final key in source.keys) {
      span.removeData(key);
    }
    if (host != null) {
      span.setData('server.address', host);
    }
    if (method != null) {
      span.setData('http.request.method', method);
    }
    if (status is num) {
      span.setData('http.response.status_code', status.toInt());
    }
  }

  static String? _host(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(raw) ? raw : null;
  }

  static String? _method(Object? value) {
    final method = value?.toString().trim().toUpperCase();
    return method != null && RegExp(r'^[A-Z]+$').hasMatch(method)
        ? method
        : null;
  }

  static Object? _duration(Object? value) {
    if (value is num) {
      return value;
    }
    final duration = value?.toString().trim();
    return duration != null && RegExp(r'^[0-9:.]+$').hasMatch(duration)
        ? duration
        : null;
  }
}
