import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/ports/transcription_profiles.dart';

final class SecureTranscriptionCredentialStore
    implements TranscriptionCredentialStore {
  const SecureTranscriptionCredentialStore({
    this.storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  });

  final FlutterSecureStorage storage;
  static const _prefix = 'meettrace.asr.';

  @override
  Future<Map<String, String>?> read(String reference) async {
    final value = await storage.read(key: '$_prefix$reference');
    if (value == null) return null;
    return Map<String, String>.from(jsonDecode(value) as Map);
  }

  @override
  Future<void> write(String reference, Map<String, String> headers) =>
      storage.write(key: '$_prefix$reference', value: jsonEncode(headers));

  @override
  Future<void> delete(String reference) =>
      storage.delete(key: '$_prefix$reference');

  @override
  Future<void> deleteAll() async {
    for (final key in (await storage.readAll()).keys.toList()) {
      if (key.startsWith(_prefix)) await storage.delete(key: key);
    }
  }
}
