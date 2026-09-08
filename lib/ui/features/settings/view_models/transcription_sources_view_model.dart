import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../domain/models/transcription_profile.dart';
import '../../../../domain/ports/transcription_profiles.dart';

final class TranscriptionSourcesViewModel extends ChangeNotifier {
  TranscriptionSourcesViewModel({
    required this.profiles,
    required this.credentials,
    this.probe,
  });

  final TranscriptionProfileRepository profiles;
  final TranscriptionCredentialStore credentials;
  final Future<void> Function(TranscriptionProfile)? probe;
  List<TranscriptionProfile> items = const [];
  String defaultId = TranscriptionProfile.localProfileId;
  bool busy = false;
  bool failed = false;
  bool requiresFreshCredentials = false;
  bool probeSucceeded = false;
  bool _disposed = false;

  Future<bool> load() => _run(_refresh);

  Future<void> _refresh() async {
    items = await profiles.list();
    defaultId = await profiles.getDefaultProfileId();
  }

  Future<bool> setDefault(TranscriptionProfile profile) => _run(() async {
    await profiles.setDefaultProfileId(profile.id);
    await _refresh();
  });

  Future<bool> delete(TranscriptionProfile profile) => _run(() async {
    await profiles.delete(profile.id);
    // 历史快照还引用旧凭据；删除入口不撤销重试，Alpha 全清统一移除凭据。
    await _refresh();
  });

  Future<bool> save({
    TranscriptionProfile? previous,
    required String name,
    required TranscriptionProtocol protocol,
    required String endpoint,
    required String modelId,
    required String apiKey,
    required String headersJson,
    required String language,
    required String prompt,
    required int maxUploadBytes,
    required int requestTimeoutSeconds,
  }) => _run(() async {
    final headers = <String, String>{};
    if (headersJson.trim().isNotEmpty) {
      final decoded = jsonDecode(headersJson);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      for (final entry in decoded.entries) {
        if (entry.value is! String ||
            !RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(entry.key) ||
            RegExp(r'[\r\n\x00]').hasMatch(entry.value as String) ||
            const {
              'host',
              'content-length',
              'content-type',
              'connection',
              'transfer-encoding',
            }.contains(entry.key.toLowerCase())) {
          throw const FormatException();
        }
        headers[entry.key] = entry.value as String;
      }
    }
    if (apiKey.trim().isNotEmpty) {
      if (RegExp(r'[\r\n\x00]').hasMatch(apiKey)) throw const FormatException();
      headers.removeWhere((key, _) => key.toLowerCase() == 'authorization');
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    final replaceSecret =
        headersJson.trim().isNotEmpty || apiKey.trim().isNotEmpty;
    final target = Uri.parse(endpoint.trim());
    final previousTarget = previous?.endpoint;
    if (!replaceSecret &&
        previous?.credentialRef != null &&
        (previousTarget?.scheme != target.scheme ||
            previousTarget?.host != target.host ||
            previousTarget?.port != target.port)) {
      requiresFreshCredentials = true;
      throw const FormatException('credentials_required');
    }
    final random = Random.secure();
    final stamp = base64UrlEncode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final profile = TranscriptionProfile(
      id: previous?.id ?? 'online-$stamp',
      name: name.trim(),
      revision: (previous?.revision ?? 0) + 1,
      protocol: protocol,
      endpoint: target,
      modelId: modelId.trim(),
      credentialRef: replaceSecret
          ? 'credential-$stamp'
          : previous?.credentialRef,
      language: language.trim(),
      prompt: prompt,
      maxUploadBytes: maxUploadBytes,
      requestTimeoutSeconds: requestTimeoutSeconds,
    );
    if (replaceSecret) await credentials.write(profile.credentialRef!, headers);
    try {
      await profiles.save(profile);
    } on Object {
      if (replaceSecret) await credentials.delete(profile.credentialRef!);
      rethrow;
    }
    await _refresh();
  });

  Future<bool> testConnection(TranscriptionProfile profile) => _run(() async {
    probeSucceeded = false;
    await probe!(profile);
    probeSucceeded = true;
  });

  Future<bool> _run(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    failed = false;
    requiresFreshCredentials = false;
    _notify();
    try {
      await operation();
      return true;
    } on Object {
      // 输入、认证头、端点和服务器正文都不能进入错误信息或遥测。
      failed = true;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
