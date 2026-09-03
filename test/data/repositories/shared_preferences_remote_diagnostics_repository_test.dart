import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/shared_preferences_remote_diagnostics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('首次安装默认开启', () async {
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    expect(await repository.getEnabled(), isTrue);
  });

  test('持久化退出选择', () async {
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    await repository.setEnabled(false);

    expect(await repository.getEnabled(), isFalse);

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

  test('平台拒绝写入时保存入口显式失败', () async {
    final previousStore = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previousStore;
      SharedPreferences.resetStatic();
    });
    SharedPreferencesStorePlatform.instance = _FailingPreferencesStore();
    SharedPreferences.resetStatic();
    final repository = SharedPreferencesRemoteDiagnosticsRepository();

    await expectLater(repository.setEnabled(false), throwsStateError);
  });
}

final class _FailingPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingPreferencesStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}
