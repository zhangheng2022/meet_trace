import 'dart:convert';

final class Phase04ReleaseInputBuilder {
  const Phase04ReleaseInputBuilder();

  Map<String, Object?> build({
    required Map<String, Object?> template,
    required Map<String, Object?> androidEvidence,
    required String androidEvidenceRef,
    required String androidEvidenceSha256,
  }) {
    _require(
      androidEvidence['schemaVersion'] == 1,
      'Android 模拟器证据 schemaVersion 必须为 1',
    );
    _require(androidEvidence['status'] == 'passed', 'Android 模拟器证据必须为 passed');
    _require(
      androidEvidence['platform'] == 'android-emulator',
      '证据平台必须为 android-emulator',
    );
    _require(androidEvidence['abi'] == 'x86_64', '阶段 1 模拟器证据 ABI 必须为 x86_64');
    _require(
      RegExp(r'^[0-9a-f]{64}$').hasMatch(androidEvidenceSha256),
      'Android 模拟器证据 SHA-256 无效',
    );

    final apiLevel = _integer(androidEvidence, 'apiLevel');
    final measurements = _map(androidEvidence, 'measurements');
    final recording = _map(measurements, 'recording');
    final meetingFlow = _map(measurements, 'meetingFlow');
    final asrLifecycle = _map(measurements, 'asrLifecycle');
    final vadLifecycle = _map(measurements, 'vadLifecycle');
    final recordingLifecycle = _map(measurements, 'recordingLifecycle');
    final meetingLifecycle = _map(measurements, 'meetingLifecycle');

    final input = jsonDecode(jsonEncode(template)) as Map<String, Object?>;
    input['evaluationScope'] = 'phase-0-4';

    final environment = _mutableMap(input, 'environment');
    final rawMetricsRef = input['rawMetricsRef'];
    final hasQualityEvidence =
        rawMetricsRef is String && rawMetricsRef.trim().isNotEmpty;
    if (!hasQualityEvidence) {
      environment['deviceId'] = 'android-emulator-x86_64-api-$apiLevel';
    } else {
      _require(
        environment['deviceId'] is String &&
            (environment['deviceId']! as String).trim().isNotEmpty,
        '已有质量证据时必须保留其评测设备标识',
      );
    }

    final phase04 = _mutableMap(input, 'phase04');
    phase04['meetingModelLocked'] = _isTrue(meetingFlow, 'meetingModelLocked');
    phase04['factPcmSoleSourcePassed'] = _isTrue(
      meetingFlow,
      'factPcmSoleSourcePassed',
    );
    phase04['emulatorLifecyclePassed'] =
        _integer(meetingLifecycle, 'cycles') >= 10 &&
        _integer(meetingLifecycle, 'sealedMeetings') ==
            _integer(meetingLifecycle, 'cycles') &&
        _isTrue(meetingLifecycle, 'allCaptureStreamsClosed') &&
        _isTrue(meetingLifecycle, 'allPreviewSessionsDisposed') &&
        _isTrue(meetingLifecycle, 'allModelLeasesReleased') &&
        _integer(recordingLifecycle, 'cycles') >= 10 &&
        _isTrue(recordingLifecycle, 'allCaptureStreamsClosed');
    phase04['asrFailureRecordingContinues'] =
        _isTrue(meetingFlow, 'previewDegradedWithoutRecordingLoss') &&
        _integer(meetingFlow, 'audioBytes') > 0 &&
        _number(recording, 'persistenceRatio') >= 0.98;
    phase04['asrContextLifecyclePassed'] =
        _integer(asrLifecycle, 'cycles') >= 100 &&
        _isTrue(asrLifecycle, 'disposeIdempotent') &&
        _integer(asrLifecycle, 'steadyStateGrowthBytes') <
            _integer(asrLifecycle, 'steadyStateGrowthLimitBytes');
    phase04['vadContextLifecyclePassed'] =
        _integer(vadLifecycle, 'cycles') >= 100 &&
        _isTrue(vadLifecycle, 'cancelResetVerified') &&
        _isTrue(vadLifecycle, 'workerIsolateVerified') &&
        _isTrue(vadLifecycle, 'disposeIdempotent') &&
        _integer(vadLifecycle, 'steadyStateGrowthBytes') < 32 * 1024 * 1024;

    final vad = _mutableMap(input, 'vad');
    vad['failureRecordingContinues'] = phase04['asrFailureRecordingContinues'];

    final evidence = _mutableMap(input, 'evidence');
    evidence['android'] = androidEvidenceRef;
    evidence['androidSha256'] = androidEvidenceSha256;
    return input;
  }
}

Map<String, Object?> _mutableMap(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  final created = <String, Object?>{};
  parent[key] = created;
  return created;
}

Map<String, Object?> _map(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! Map<String, Object?>) {
    throw FormatException('缺少 JSON 对象：$key');
  }
  return value;
}

int _integer(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! int) {
    throw FormatException('$key 必须为整数');
  }
  return value;
}

double _number(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('$key 必须为有限数值');
  }
  return value.toDouble();
}

bool _isTrue(Map<String, Object?> parent, String key) => parent[key] == true;

void _require(bool condition, String message) {
  if (!condition) {
    throw FormatException(message);
  }
}
