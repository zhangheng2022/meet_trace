import 'package:patrol/patrol.dart';

import 'harness.dart';
import 'meetings.dart';

final class Modules {
  const Modules(this._$);

  final PatrolIntegrationTester _$;

  Harness get harness => Harness(_$);
  Meetings get meetings => Meetings(_$);
}
