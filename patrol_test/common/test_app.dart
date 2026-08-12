import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:patrol/patrol.dart';

import '../api_clients/api_clients.dart';
import '../keys.dart';
import '../modules/modules.dart';
import '../system/system.dart';

typedef TestAppCallback =
    Future<void> Function(
      PatrolIntegrationTester $,
      Modules modules,
      System system,
      ApiClients apiClients,
    );

@isTest
void testApp(
  String description,
  TestAppCallback callback, {
  Widget? app,
  PatrolTesterConfig config = const PatrolTesterConfig(printLogs: true),
  bool settle = true,
  dynamic tags,
}) {
  patrolTest(description, config: config, tags: tags, ($) async {
    final root = app ?? const _PatrolHarnessApp();
    if (settle) {
      await $.pumpWidgetAndSettle(root);
    } else {
      await $.pumpWidget(root);
    }
    await callback($, Modules($), System($.platform), const ApiClients());
  });
}

final class _PatrolHarnessApp extends StatefulWidget {
  const _PatrolHarnessApp();

  @override
  State<_PatrolHarnessApp> createState() => _PatrolHarnessAppState();
}

final class _PatrolHarnessAppState extends State<_PatrolHarnessApp> {
  bool _activated = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: _activated
              ? Text(key: patrolHarnessKeys.activatedLabel, 'Patrol 已连接')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(key: patrolHarnessKeys.readyLabel, 'Patrol 准备完成'),
                    TextButton(
                      key: patrolHarnessKeys.activateButton,
                      onPressed: () => setState(() => _activated = true),
                      child: const Text('验证连接'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
