import 'dart:convert';

import 'asr_model_registry.dart';
import 'asr_model.dart';

enum TranscriptionProtocol {
  local,
  audioTranscriptions,
  chatAudio,
  realtimeTranscription,
}

/// 可直接冻结到会议和任务中的非秘密配置；凭据只保留安全存储引用。
final class TranscriptionProfile {
  TranscriptionProfile({
    required this.id,
    required this.name,
    required this.revision,
    required this.protocol,
    required this.modelId,
    this.modelVersion,
    this.endpoint,
    this.credentialRef,
    this.language = 'auto',
    this.useInverseTextNormalization = true,
    this.prompt = '',
    this.maxUploadBytes = 24 * 1024 * 1024,
    this.requestTimeoutSeconds = 120,
    this.diarizationEnabled = false,
  }) {
    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        modelId.trim().isEmpty ||
        language.trim().isEmpty ||
        revision < 1 ||
        maxUploadBytes < 1024 ||
        requestTimeoutSeconds < 1 ||
        requestTimeoutSeconds > 3600 ||
        modelVersion?.trim().isEmpty == true ||
        credentialRef?.trim().isEmpty == true) {
      throw ArgumentError('转录配置不完整或超出支持范围');
    }
    if (isLocal) {
      if (modelVersion == null || endpoint != null || credentialRef != null) {
        throw ArgumentError('本地配置必须提供模型版本，不能包含在线端点或凭据');
      }
    } else {
      final uri = endpoint;
      final realtime = protocol == TranscriptionProtocol.realtimeTranscription;
      final secureScheme = realtime ? 'wss' : 'https';
      final localScheme = realtime ? 'ws' : 'http';
      final loopback =
          uri != null &&
          const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          (uri.scheme != secureScheme &&
              !(loopback && uri.scheme == localScheme))) {
        throw ArgumentError('在线配置需要完整安全端点；明文连接仅允许本机网关');
      }
    }
  }

  factory TranscriptionProfile.local({bool diarizationEnabled = true}) {
    final model = AsrModelRegistry.alpha.defaultModel;
    return TranscriptionProfile(
      id: localProfileId,
      name: model.displayName,
      revision: 1,
      protocol: TranscriptionProtocol.local,
      modelId: model.modelId,
      modelVersion: model.version,
      language: model.language,
      useInverseTextNormalization: model.useInverseTextNormalization,
      diarizationEnabled: diarizationEnabled,
    );
  }

  static const localProfileId = 'local-sensevoice';
  static const unreportedModelVersion = 'unreported';

  final String id;
  final String name;
  final int revision;
  final TranscriptionProtocol protocol;
  final String modelId;
  final String? modelVersion;
  final Uri? endpoint;
  final String? credentialRef;
  final String language;
  final bool useInverseTextNormalization;
  final String prompt;
  final int maxUploadBytes;
  final int requestTimeoutSeconds;
  final bool diarizationEnabled;

  bool get isLocal => protocol == TranscriptionProtocol.local;

  /// 旧 Engine 合同中的显式未知标记，绝不代表在线服务的实际权重版本。
  String get identityVersion => modelVersion ?? unreportedModelVersion;

  AsrModelDescriptor get descriptor => isLocal
      ? AsrModelRegistry.alpha.requireById(modelId)
      : AsrModelDescriptor(
          modelId: modelId,
          displayName: name,
          version: identityVersion,
          supportedLanguages: [language],
          installationType: AsrInstallationType.remote,
          requiredBytes: 0,
          capabilities: {
            'remote',
            'final-transcript',
            if (protocol == TranscriptionProtocol.realtimeTranscription)
              'meeting-preview',
          },
          language: language,
          useInverseTextNormalization: useInverseTextNormalization,
        );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'revision': revision,
    'protocol': protocol.name,
    'modelId': modelId,
    'modelVersion': modelVersion,
    'endpoint': endpoint?.toString(),
    'credentialRef': credentialRef,
    'language': language,
    'useInverseTextNormalization': useInverseTextNormalization,
    'prompt': prompt,
    'maxUploadBytes': maxUploadBytes,
    'requestTimeoutSeconds': requestTimeoutSeconds,
    'diarizationEnabled': diarizationEnabled,
  };

  factory TranscriptionProfile.fromJson(Map<String, Object?> json) =>
      TranscriptionProfile(
        id: json['id']! as String,
        name: json['name']! as String,
        revision: json['revision']! as int,
        protocol: TranscriptionProtocol.values.byName(
          json['protocol']! as String,
        ),
        modelId: json['modelId']! as String,
        modelVersion: json['modelVersion'] as String?,
        endpoint: json['endpoint'] == null
            ? null
            : Uri.parse(json['endpoint']! as String),
        credentialRef: json['credentialRef'] as String?,
        language: json['language'] as String? ?? 'auto',
        useInverseTextNormalization:
            json['useInverseTextNormalization'] as bool? ?? true,
        prompt: json['prompt'] as String? ?? '',
        maxUploadBytes: json['maxUploadBytes'] as int? ?? 24 * 1024 * 1024,
        requestTimeoutSeconds: json['requestTimeoutSeconds'] as int? ?? 120,
        diarizationEnabled: json['diarizationEnabled'] as bool? ?? false,
      );

  /// 比较完整冻结配置，包括身份、名称与修订号；用于同一修订的幂等保存。
  bool hasSameConfiguration(TranscriptionProfile other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());
}
