import 'package:flutter/widgets.dart';

class _PatrolHarnessKey extends ValueKey<String> {
  const _PatrolHarnessKey(super.value);
}

const patrolHarnessKeys = PatrolHarnessKeys();

final class PatrolHarnessKeys {
  const PatrolHarnessKeys();

  final activateButton = const _PatrolHarnessKey(
    'patrol-harness-activate-button',
  );
  final activatedLabel = const _PatrolHarnessKey(
    'patrol-harness-activated-label',
  );
  final readyLabel = const _PatrolHarnessKey('patrol-harness-ready-label');
}
