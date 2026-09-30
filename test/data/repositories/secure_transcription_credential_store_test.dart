import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/secure_transcription_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  const credentials = SecureTranscriptionCredentialStore(storage: storage);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('认证头通过安全存储按命名空间往返并可定点移除', () async {
    await credentials.write('profile-revision-1', {
      'Authorization': 'Bearer test-secret',
      'X-Tenant': 'test',
    });
    expect(await credentials.read('profile-revision-1'), {
      'Authorization': 'Bearer test-secret',
      'X-Tenant': 'test',
    });
    expect((await storage.readAll()).keys, [
      'meettrace.asr.profile-revision-1',
    ]);
    await credentials.delete('profile-revision-1');
    expect(await credentials.read('profile-revision-1'), isNull);
  });

  test('全清只移除会迹 ASR 凭据，保留安全存储中的无关值', () async {
    FlutterSecureStorage.setMockInitialValues({
      'meettrace.asr.old': '{"Authorization":"test-old"}',
      'meettrace.asr.current': '{}',
      'unrelated.token': 'keep',
    });
    await credentials.deleteAll();
    expect(await storage.readAll(), {'unrelated.token': 'keep'});
  });

  test('损坏的凭据拒绝作为认证头返回', () async {
    FlutterSecureStorage.setMockInitialValues({
      'meettrace.asr.bad': 'not-json',
    });
    await expectLater(credentials.read('bad'), throwsFormatException);
    FlutterSecureStorage.setMockInitialValues({
      'meettrace.asr.bad': '{"Authorization":123}',
    });
    await expectLater(credentials.read('bad'), throwsA(isA<TypeError>()));
  });
}
