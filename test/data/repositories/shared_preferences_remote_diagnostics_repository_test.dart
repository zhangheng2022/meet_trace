import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/shared_preferences_remote_diagnostics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('首次安装默认开启且告知未关闭', () async {
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    expect(await repository.getEnabled(), isTrue);
    expect(await repository.getNoticeDismissed(), isFalse);
  });

  test('持久化退出选择和一次性告知状态', () async {
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    await repository.setEnabled(false);
    await repository.setNoticeDismissed();

    expect(await repository.getEnabled(), isFalse);
    expect(await repository.getNoticeDismissed(), isTrue);

    await repository.setEnabled(true);

    expect(await repository.getEnabled(), isTrue);
  });

  test('开关存在非布尔异常值时按关闭处理', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'remote_diagnostics_enabled': 'legacy-value',
    });
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    expect(await repository.getEnabled(), isFalse);
  });

  test('告知状态存在非布尔异常值时按未告知处理', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'remote_diagnostics_notice_dismissed': 'legacy-value',
    });
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    expect(await repository.getNoticeDismissed(), isFalse);
  });

  test('平台拒绝写入时两个保存入口都显式失败', () async {
    final previousStore = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previousStore;
      SharedPreferences.resetStatic();
    });
    SharedPreferencesStorePlatform.instance = _FailingPreferencesStore();
    SharedPreferences.resetStatic();
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    await expectLater(repository.setEnabled(false), throwsStateError);
    await expectLater(repository.setNoticeDismissed(), throwsStateError);
  });
}

final class _FailingPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingPreferencesStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}
