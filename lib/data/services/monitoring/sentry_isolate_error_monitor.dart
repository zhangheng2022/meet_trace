import 'dart:async';
import 'dart:isolate';

import 'package:sentry_flutter/sentry_flutter.dart';

typedef IsolateErrorCapture = FutureOr<void> Function(
  Object error,
  StackTrace? stackTrace,
);

/// 将后台 Isolate 未处理错误转交 Sentry，并在退出后释放端口。
final class SentryIsolateErrorMonitor {
  SentryIsolateErrorMonitor.attach(
    this._isolate, {
    IsolateErrorCapture capture = _captureWithSentry,
  }) : _port = RawReceivePort((Object? message) => _handle(message, capture)) {
    _isolate.addErrorListener(_port!.sendPort);
  }

  final Isolate _isolate;
  RawReceivePort? _port;

  void close() {
    final port = _port;
    if (port == null) {
      return;
    }
    _port = null;
    _isolate.removeErrorListener(port.sendPort);
    port.close();
  }

  static Future<void> _captureWithSentry(
    Object error,
    StackTrace? stackTrace,
  ) => Sentry.captureException(error, stackTrace: stackTrace);

  static void _handle(Object? message, IsolateErrorCapture capture) {
    if (message is! List<Object?> || message.length != 2) {
      return;
    }
    if (message[0] == null) {
      return;
    }
    final stackText = message[1];
    Future<void>.sync(
      () => capture(
        const _BackgroundIsolateError(),
        stackText is String ? StackTrace.fromString(stackText) : null,
      ),
    ).ignore();
  }
}

final class _BackgroundIsolateError implements Exception {
  const _BackgroundIsolateError();

  @override
  String toString() => 'BackgroundIsolateError';
}
