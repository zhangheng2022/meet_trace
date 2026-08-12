// 模块直接调用 Patrol API；显式导入便于 API 归属和后续升级检查。
// ignore: unused_import
import 'package:patrol/patrol.dart';

import '../keys.dart';
import 'module.dart';

final class Harness extends Module {
  const Harness(super.$);

  Future<void> activate() async {
    await $(patrolHarnessKeys.activateButton).tap();
  }

  Future<void> expectActivated() async {
    await $(patrolHarnessKeys.activatedLabel).waitUntilVisible();
  }
}
