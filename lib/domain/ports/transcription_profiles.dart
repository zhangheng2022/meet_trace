import '../models/transcription_profile.dart';

abstract interface class TranscriptionProfileRepository {
  Future<List<TranscriptionProfile>> list();
  Future<TranscriptionProfile?> getById(String id);
  Future<void> save(TranscriptionProfile profile);
  Future<void> delete(String id);
  Future<String> getDefaultProfileId();
  Future<void> setDefaultProfileId(String id);
}

/// 完整认证头仅由系统安全存储保存，不得进入配置 JSON、日志或遥测。
abstract interface class TranscriptionCredentialStore {
  Future<Map<String, String>?> read(String reference);
  Future<void> write(String reference, Map<String, String> headers);
  Future<void> delete(String reference);
  Future<void> deleteAll();
}
