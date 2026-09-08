import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/transcription_profile.dart';
import 'package:meettrace/domain/ports/transcription_profiles.dart';
import 'package:meettrace/ui/features/settings/view_models/transcription_sources_view_model.dart';

void main() {
  late _Profiles profiles;
  late _Credentials credentials;
  late TranscriptionSourcesViewModel viewModel;
  setUp(() {
    profiles = _Profiles();
    credentials = _Credentials();
    viewModel = TranscriptionSourcesViewModel(
      profiles: profiles,
      credentials: credentials,
    );
  });
  tearDown(() => viewModel.dispose());

  Future<bool> save({
    TranscriptionProfile? previous,
    String headers = '',
    String apiKey = '',
    String endpoint = 'https://gateway.example/v1/audio/transcriptions',
    TranscriptionProtocol protocol = TranscriptionProtocol.audioTranscriptions,
  }) => viewModel.save(
    previous: previous,
    name: ' 公司网关 ',
    protocol: protocol,
    endpoint: endpoint,
    modelId: ' custom-model ',
    apiKey: apiKey,
    headersJson: headers,
    language: 'zh',
    prompt: '会迹',
    maxUploadBytes: 1024 * 1024,
    requestTimeoutSeconds: 60,
  );

  test('认证仅写安全存储，API key 覆盖自定义 Authorization 且配置不含秘密', () async {
    expect(
      await save(
        apiKey: ' test-token ',
        headers: '{"authorization":"obsolete","X-Tenant":"test-tenant"}',
      ),
      isTrue,
    );
    final profile = profiles.saved.single;
    expect(profile.name, '公司网关');
    expect(profile.modelId, 'custom-model');
    expect(profile.revision, 1);
    expect(credentials.values[profile.credentialRef], {
      'X-Tenant': 'test-tenant',
      'Authorization': 'Bearer test-token',
    });
    expect(profile.toJson().toString(), isNot(contains('test-token')));
    expect(profile.toJson().toString(), isNot(contains('test-tenant')));
    expect(viewModel.items, contains(profile));
  });

  test('拒绝 HTTP 头注入、受限协议头和不安全端点，不写任何凭据', () async {
    for (final headers in [
      '["not-object"]',
      '{"X-Tenant":1}',
      '{"bad header":"x"}',
      r'{"X-Tenant":"value\r\nInjected: true"}',
      '{"HOST":"other.example"}',
      '{"Content-Length":"10"}',
      '{"Content-Type":"text/plain"}',
      '{"Connection":"close"}',
      '{"Transfer-Encoding":"chunked"}',
    ]) {
      expect(await save(headers: headers), isFalse, reason: headers);
      expect(viewModel.failed, isTrue);
    }
    expect(await save(apiKey: 'token\r\ninjected'), isFalse);
    expect(
      await save(endpoint: 'http://external.example/asr', apiKey: 'token'),
      isFalse,
    );
    expect(
      await save(endpoint: 'https://user:password@example.com/asr'),
      isFalse,
    );
    expect(await save(endpoint: 'wss://example.com/asr'), isFalse);
    expect(credentials.values, isEmpty);
    expect(profiles.saved, isEmpty);
  });

  test('编辑保留旧凭据引用，替换时生成新引用且历史秘密仍可读取', () async {
    expect(await save(apiKey: 'old-token'), isTrue);
    final original = profiles.saved.last;
    expect(await save(previous: original), isTrue);
    final retained = profiles.saved.last;
    expect(retained.id, original.id);
    expect(retained.revision, original.revision + 1);
    expect(retained.credentialRef, original.credentialRef);
    expect(await save(previous: retained, apiKey: 'new-token'), isTrue);
    final replaced = profiles.saved.last;
    expect(replaced.credentialRef, isNot(original.credentialRef));
    expect(
      credentials.values[original.credentialRef]?['Authorization'],
      'Bearer old-token',
    );
    expect(
      credentials.values[replaced.credentialRef]?['Authorization'],
      'Bearer new-token',
    );
  });

  test('配置保存失败撤回新凭据，凭据写入失败不保存配置', () async {
    profiles.failSave = true;
    expect(await save(apiKey: 'new-token'), isFalse);
    expect(credentials.values, isEmpty);
    expect(credentials.deleted, hasLength(1));
    profiles.failSave = false;
    credentials.failWrite = true;
    expect(await save(apiKey: 'new-token'), isFalse);
    expect(profiles.saved, isEmpty);
    expect(viewModel.busy, isFalse);
  });

  test('跨 host、scheme 或 port 修改端点时拒绝静默沿用已有凭据', () async {
    expect(await save(apiKey: 'original-token'), isTrue);
    final original = profiles.saved.single;
    for (final target in [
      (
        endpoint: 'https://other.example/v1/audio/transcriptions',
        protocol: TranscriptionProtocol.audioTranscriptions,
      ),
      (
        endpoint: 'https://gateway.example:8443/v1/audio/transcriptions',
        protocol: TranscriptionProtocol.audioTranscriptions,
      ),
      (
        endpoint: 'wss://gateway.example/v1/audio/transcriptions',
        protocol: TranscriptionProtocol.realtimeTranscription,
      ),
    ]) {
      expect(
        await save(
          previous: original,
          endpoint: target.endpoint,
          protocol: target.protocol,
        ),
        isFalse,
      );
      expect(profiles.saved, hasLength(1));
      expect(credentials.values, hasLength(1));
      expect(profiles.values[original.id], same(original));
    }
  });

  test('同一 origin 的路径和默认端口变更可保留已有凭据', () async {
    expect(await save(apiKey: 'original-token'), isTrue);
    final original = profiles.saved.single;
    expect(
      await save(
        previous: original,
        endpoint: 'https://gateway.example:443/another/transcribe',
      ),
      isTrue,
    );
    expect(profiles.saved.last.credentialRef, original.credentialRef);
    expect(credentials.values, hasLength(1));
  });

  test('跨 origin 可显式输入新密钥或空认证头，旧凭据只供历史快照使用', () async {
    expect(await save(apiKey: 'original-token'), isTrue);
    final original = profiles.saved.single;
    expect(
      await save(
        previous: original,
        endpoint: 'https://other.example/asr',
        apiKey: 'replacement-token',
      ),
      isTrue,
    );
    final replaced = profiles.saved.last;
    expect(replaced.credentialRef, isNot(original.credentialRef));
    expect(credentials.values[replaced.credentialRef], {
      'Authorization': 'Bearer replacement-token',
    });
    expect(
      await save(
        previous: replaced,
        endpoint: 'https://anonymous.example/asr',
        headers: '{}',
      ),
      isTrue,
    );
    final cleared = profiles.saved.last;
    expect(cleared.credentialRef, isNot(replaced.credentialRef));
    expect(credentials.values[cleared.credentialRef], isEmpty);
    expect(credentials.values[original.credentialRef], {
      'Authorization': 'Bearer original-token',
    });
  });

  test('未保存任何凭据的来源修改 origin 不要求输入秘密', () async {
    expect(await save(), isTrue);
    final original = profiles.saved.single;
    expect(original.credentialRef, isNull);
    expect(
      await save(previous: original, endpoint: 'https://another.example/asr'),
      isTrue,
    );
    expect(profiles.saved.last.credentialRef, isNull);
    expect(credentials.values, isEmpty);
  });

  test('默认设置和删除刷新列表，删除来源不撤销历史凭据', () async {
    await save(apiKey: 'history-token');
    final profile = profiles.saved.single;
    expect(await viewModel.setDefault(profile), isTrue);
    expect(viewModel.defaultId, profile.id);
    expect(await viewModel.delete(profile), isTrue);
    expect(viewModel.items.any((item) => item.id == profile.id), isFalse);
    expect(viewModel.defaultId, TranscriptionProfile.localProfileId);
    expect(credentials.values[profile.credentialRef], isNotNull);
  });

  test('只有显式测试连接才执行 probe，异常只暴露通用失败状态', () async {
    var probes = 0;
    viewModel.dispose();
    viewModel = TranscriptionSourcesViewModel(
      profiles: profiles,
      credentials: credentials,
      probe: (_) async {
        probes++;
        if (probes == 2) throw StateError('sensitive-server-body');
      },
    );
    await viewModel.load();
    await save();
    expect(probes, 0);
    expect(await viewModel.testConnection(profiles.saved.single), isTrue);
    expect(viewModel.probeSucceeded, isTrue);
    expect(await viewModel.testConnection(profiles.saved.single), isFalse);
    expect(viewModel.probeSucceeded, isFalse);
    expect(viewModel.failed, isTrue);
  });

  test('运行中拒绝重复保存，disposed 后异步返回不发通知', () async {
    final gate = Completer<void>();
    profiles.listGate = gate;
    final loading = viewModel.load();
    expect(viewModel.busy, isTrue);
    expect(await save(apiKey: 'must-not-save'), isFalse);
    expect(credentials.values, isEmpty);
    viewModel.dispose();
    gate.complete();
    expect(await loading, isTrue);
    viewModel = TranscriptionSourcesViewModel(
      profiles: profiles,
      credentials: credentials,
    );
  });
}

final class _Profiles implements TranscriptionProfileRepository {
  final values = <String, TranscriptionProfile>{
    TranscriptionProfile.localProfileId: TranscriptionProfile.local(),
  };
  final saved = <TranscriptionProfile>[];
  String defaultId = TranscriptionProfile.localProfileId;
  bool failSave = false;
  Completer<void>? listGate;
  @override
  Future<List<TranscriptionProfile>> list() async {
    await listGate?.future;
    return values.values.toList();
  }

  @override
  Future<TranscriptionProfile?> getById(String id) async => values[id];
  @override
  Future<void> save(TranscriptionProfile profile) async {
    if (failSave) throw StateError('save failed');
    saved.add(profile);
    values[profile.id] = profile;
  }

  @override
  Future<void> delete(String id) async {
    values.remove(id);
    if (defaultId == id) defaultId = TranscriptionProfile.localProfileId;
  }

  @override
  Future<String> getDefaultProfileId() async => defaultId;
  @override
  Future<void> setDefaultProfileId(String id) async {
    defaultId = id;
  }
}

final class _Credentials implements TranscriptionCredentialStore {
  final values = <String, Map<String, String>>{};
  final deleted = <String>[];
  bool failWrite = false;
  @override
  Future<Map<String, String>?> read(String reference) async =>
      values[reference];
  @override
  Future<void> write(String reference, Map<String, String> headers) async {
    if (failWrite) throw StateError('storage locked');
    values[reference] = Map.of(headers);
  }

  @override
  Future<void> delete(String reference) async {
    deleted.add(reference);
    values.remove(reference);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}
