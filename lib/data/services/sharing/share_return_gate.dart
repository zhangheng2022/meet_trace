import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

abstract interface class ShareReturnGate {
  void start();

  Future<void> waitUntilReturned();

  void dispose();
}

typedef ShareReturnGateFactory = ShareReturnGate Function();

ShareReturnGate createPlatformShareReturnGate() {
  return FlutterShareReturnGate(waitForLifecycle: Platform.isAndroid);
}

final class FlutterShareReturnGate
    with WidgetsBindingObserver
    implements ShareReturnGate {
  FlutterShareReturnGate({
    required this.waitForLifecycle,
    this.returnTimeout = const Duration(minutes: 2),
  }) {
    if (returnTimeout <= Duration.zero) {
      throw ArgumentError.value(returnTimeout, 'returnTimeout', '必须大于零');
    }
  }

  final bool waitForLifecycle;
  final Duration returnTimeout;
  final Completer<void> _returned = Completer<void>();
  bool _leftForeground = false;
  bool _observing = false;

  @override
  void start() {
    if (!waitForLifecycle || _observing) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _leftForeground = true;
      return;
    }
    if (_leftForeground && !_returned.isCompleted) {
      _returned.complete();
    }
  }

  @override
  Future<void> waitUntilReturned() {
    if (!waitForLifecycle) {
      return Future.value();
    }
    return _returned.future.timeout(returnTimeout, onTimeout: () {});
  }

  @override
  void dispose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }
}
