import '../models/transcription_profile.dart';

abstract interface class TranscriptionProfileRepository {
  Future<List<TranscriptionProfile>> list();
  Future<TranscriptionProfile?> getById(String id);
  Future<void> save(TranscriptionProfile profile);
  Future<void> delete(String id);
  Future<String> getDefaultProfileId();
  Future<void> setDefaultProfileId(String id);
}

/// 认证头值仅允许可打印 ASCII / HTAB，头名不得覆盖 HTTP / WebSocket 传输字段。
bool areValidTranscriptionHeaders(Map<String, String> headers) {
  const reserved = {
    'host',
    'content-length',
    'content-type',
    'transfer-encoding',
    'connection',
    'upgrade',
  };
  final invalidName = RegExp(r"[^!#$%&'*+.^_`|~0-9A-Za-z-]");
  final invalidValue = RegExp(r'[^\t\x20-\x7e]');
  return headers.entries.every((entry) {
    final name = entry.key.toLowerCase();
    return name.isNotEmpty &&
        !invalidName.hasMatch(entry.key) &&
        !reserved.contains(name) &&
        !name.startsWith('sec-websocket-') &&
        !invalidValue.hasMatch(entry.value);
  });
}

/// 完整认证头仅由系统安全存储保存，不得进入配置 JSON、日志或遥测。
abstract interface class TranscriptionCredentialStore {
  Future<Map<String, String>?> read(String reference);
  Future<void> write(String reference, Map<String, String> headers);
  Future<void> delete(String reference);
  Future<void> deleteAll();
}
