import 'dart:math' as math;

const alphaReleaseInputSchemaVersion = 4;
const alphaProductMeetingEvidenceClass = 'product-meeting';

enum AlphaReleaseDecision { go, noGo, blocked }

enum ReleaseGateStatus { passed, failed, missing }

final class AlphaReleaseEvaluationInput {
  const AlphaReleaseEvaluationInput({
    this.schemaVersion,
    this.corpusId,
    this.corpusEvidenceClass,
    this.corpusManifestSha256,
    this.corpusSourceId,
    this.corpusLicenseId,
    this.deviceId,
    this.rawMetricsRef,
    this.corpusSampleCount,
    this.corpusDeidentified,
    this.sameCorpusForBothModels,
    this.sameDeviceForBothModels,
    this.lowEndArm64DeviceTested,
    this.iosArm64DeviceTested,
    this.iosBackgroundRecordingPassed,
    this.iosInterruptionRecoveryPassed,
    this.adaptiveNavigationAccessibilityPassed,
    this.standardModelResourceBytes,
    this.standardRtfSamples,
    this.standardSentenceLatencyMs,
    this.finalTranscriptionDurationMs,
    this.recordingCompletenessRatio,
    this.sustainedSevereOrCriticalThermal,
    this.silenceSampleCount,
    this.silenceFalsePositiveCount,
    this.noiseSampleCount,
    this.baselineNoiseHallucinationCount,
    this.vadNoiseHallucinationCount,
    this.vadChunkBoundaryConsistent,
    this.vadFailureRecordingContinues,
    this.standardEnergyWh,
    this.advancedEnergyWh,
    this.advancedRtfSamples,
    this.advancedSentenceLatencyMs,
    this.advancedFinalTranscriptionDurationMs,
    this.keyFactRecallRatio,
    this.fixedWindowBothModelsCompleted,
    this.previewSentenceLatencyMs,
    this.standardFixedWindowKeyFactRecallRatio,
    this.standardVadKeyFactRecallRatio,
    this.advancedVadKeyFactRecallRatio,
    this.speechBoundaryKeyFactRecallRatio,
    this.productBoundaryApproved,
    this.meetingModelLocked,
    this.factPcmSoleSourcePassed,
    this.emulatorLifecyclePassed,
    this.asrFailureRecordingContinues,
    this.startFailureDiagnosticsPassed,
    this.asrContextLifecyclePassed,
    this.vadContextLifecyclePassed,
    this.finalChunkBoundaryConsistent,
    this.previewDropFinalInvariant,
    this.finalTimestampsValid,
    this.snapshotAtomicityPassed,
    this.summaryFinalSnapshotOnly,
    this.acceptanceEvidence,
    this.apkAuditPassed,
    this.android16KbPassed,
    this.androidEvidenceRef,
    this.iosBuildAuditPassed,
    this.iosBuildEvidenceRef,
    this.whisperCppLicenseConfirmed,
  });

  factory AlphaReleaseEvaluationInput.fromJson(Map<String, Object?> json) {
    final corpus = _map(json['corpus']);
    final provenance = _map(corpus?['provenance']);
    final environment = _map(json['environment']);
    final standard = _map(json['standardModel']);
    final advanced = _map(json['advancedModel']);
    final energy = _map(json['energy']);
    final vad = _map(json['vad']);
    final quality = _map(json['quality']);
    final phase04 = _map(json['phase04']);
    final evidence = _map(json['evidence']);
    final release = _map(json['release']);
    return AlphaReleaseEvaluationInput(
      schemaVersion: _integer(json['schemaVersion']),
      corpusId: _string(corpus?['id']),
      corpusEvidenceClass: _string(corpus?['evidenceClass']),
      corpusManifestSha256: _string(corpus?['manifestSha256']),
      corpusSourceId: _string(provenance?['sourceId']),
      corpusLicenseId: _string(provenance?['licenseId']),
      deviceId: _string(environment?['deviceId']),
      rawMetricsRef: _string(json['rawMetricsRef']),
      corpusSampleCount: _integer(corpus?['sampleCount']),
      corpusDeidentified: _boolean(corpus?['deidentified']),
      sameCorpusForBothModels: _boolean(
        environment?['sameCorpusForBothModels'],
      ),
      sameDeviceForBothModels: _boolean(
        environment?['sameDeviceForBothModels'],
      ),
      lowEndArm64DeviceTested: _boolean(
        environment?['lowEndArm64DeviceTested'],
      ),
      iosArm64DeviceTested: _boolean(environment?['iosArm64DeviceTested']),
      iosBackgroundRecordingPassed: _boolean(
        environment?['iosBackgroundRecordingPassed'],
      ),
      iosInterruptionRecoveryPassed: _boolean(
        environment?['iosInterruptionRecoveryPassed'],
      ),
      adaptiveNavigationAccessibilityPassed: _boolean(
        environment?['adaptiveNavigationAccessibilityPassed'],
      ),
      standardModelResourceBytes: _integer(standard?['resourceBytes']),
      standardRtfSamples: _numbers(standard?['rtfSamples']),
      standardSentenceLatencyMs: _numbers(standard?['sentenceLatencyMs']),
      finalTranscriptionDurationMs: _number(
        standard?['finalTranscriptionDurationMs'],
      ),
      recordingCompletenessRatio: _number(
        standard?['recordingCompletenessRatio'],
      ),
      sustainedSevereOrCriticalThermal: _boolean(
        standard?['sustainedSevereOrCriticalThermal'],
      ),
      silenceSampleCount: _integer(vad?['silenceSampleCount']),
      silenceFalsePositiveCount: _integer(vad?['silenceFalsePositiveCount']),
      noiseSampleCount: _integer(vad?['noiseSampleCount']),
      baselineNoiseHallucinationCount: _integer(
        vad?['baselineNoiseHallucinationCount'],
      ),
      vadNoiseHallucinationCount: _integer(vad?['vadNoiseHallucinationCount']),
      vadChunkBoundaryConsistent: _boolean(vad?['chunkBoundaryConsistent']),
      vadFailureRecordingContinues: _boolean(vad?['failureRecordingContinues']),
      standardEnergyWh: _number(energy?['standardWh']),
      advancedEnergyWh: _number(energy?['advancedWh']),
      advancedRtfSamples: _numbers(advanced?['rtfSamples']),
      advancedSentenceLatencyMs: _numbers(advanced?['sentenceLatencyMs']),
      advancedFinalTranscriptionDurationMs: _number(
        advanced?['finalTranscriptionDurationMs'],
      ),
      keyFactRecallRatio: _number(standard?['keyFactRecallRatio']),
      fixedWindowBothModelsCompleted: _boolean(
        quality?['fixedWindowBothModelsCompleted'],
      ),
      previewSentenceLatencyMs: _numbers(quality?['previewSentenceLatencyMs']),
      standardFixedWindowKeyFactRecallRatio: _number(
        quality?['standardFixedWindowKeyFactRecallRatio'],
      ),
      standardVadKeyFactRecallRatio: _number(
        quality?['standardVadKeyFactRecallRatio'],
      ),
      advancedVadKeyFactRecallRatio: _number(
        quality?['advancedVadKeyFactRecallRatio'],
      ),
      speechBoundaryKeyFactRecallRatio: _number(
        quality?['speechBoundaryKeyFactRecallRatio'],
      ),
      productBoundaryApproved: _boolean(phase04?['productBoundaryApproved']),
      meetingModelLocked: _boolean(phase04?['meetingModelLocked']),
      factPcmSoleSourcePassed: _boolean(phase04?['factPcmSoleSourcePassed']),
      emulatorLifecyclePassed: _boolean(phase04?['emulatorLifecyclePassed']),
      asrFailureRecordingContinues: _boolean(
        phase04?['asrFailureRecordingContinues'],
      ),
      startFailureDiagnosticsPassed: _boolean(
        phase04?['startFailureDiagnosticsPassed'],
      ),
      asrContextLifecyclePassed: _boolean(
        phase04?['asrContextLifecyclePassed'],
      ),
      vadContextLifecyclePassed: _boolean(
        phase04?['vadContextLifecyclePassed'],
      ),
      finalChunkBoundaryConsistent: _boolean(
        phase04?['finalChunkBoundaryConsistent'],
      ),
      previewDropFinalInvariant: _boolean(
        phase04?['previewDropFinalInvariant'],
      ),
      finalTimestampsValid: _boolean(phase04?['finalTimestampsValid']),
      snapshotAtomicityPassed: _boolean(phase04?['snapshotAtomicityPassed']),
      summaryFinalSnapshotOnly: _boolean(phase04?['summaryFinalSnapshotOnly']),
      acceptanceEvidence: _strings(json['acceptanceEvidence']),
      apkAuditPassed: _boolean(release?['apkAuditPassed']),
      android16KbPassed: _boolean(release?['android16KbPassed']),
      androidEvidenceRef: _string(evidence?['android']),
      iosBuildAuditPassed: _boolean(release?['iosBuildAuditPassed']),
      iosBuildEvidenceRef: _string(evidence?['iosBuild']),
      whisperCppLicenseConfirmed: _boolean(
        release?['whisperCppLicenseConfirmed'] ??
            release?['paraformerRedistributionConfirmed'],
      ),
    );
  }

  final int? schemaVersion;
  final String? corpusId;
  final String? corpusEvidenceClass;
  final String? corpusManifestSha256;
  final String? corpusSourceId;
  final String? corpusLicenseId;
  final String? deviceId;
  final String? rawMetricsRef;
  final int? corpusSampleCount;
  final bool? corpusDeidentified;
  final bool? sameCorpusForBothModels;
  final bool? sameDeviceForBothModels;
  final bool? lowEndArm64DeviceTested;
  final bool? iosArm64DeviceTested;
  final bool? iosBackgroundRecordingPassed;
  final bool? iosInterruptionRecoveryPassed;
  final bool? adaptiveNavigationAccessibilityPassed;
  final int? standardModelResourceBytes;
  final List<double>? standardRtfSamples;
  final List<double>? standardSentenceLatencyMs;
  final double? finalTranscriptionDurationMs;
  final double? recordingCompletenessRatio;
  final bool? sustainedSevereOrCriticalThermal;
  final int? silenceSampleCount;
  final int? silenceFalsePositiveCount;
  final int? noiseSampleCount;
  final int? baselineNoiseHallucinationCount;
  final int? vadNoiseHallucinationCount;
  final bool? vadChunkBoundaryConsistent;
  final bool? vadFailureRecordingContinues;
  final double? standardEnergyWh;
  final double? advancedEnergyWh;
  final List<double>? advancedRtfSamples;
  final List<double>? advancedSentenceLatencyMs;
  final double? advancedFinalTranscriptionDurationMs;
  final double? keyFactRecallRatio;
  final bool? fixedWindowBothModelsCompleted;
  final List<double>? previewSentenceLatencyMs;
  final double? standardFixedWindowKeyFactRecallRatio;
  final double? standardVadKeyFactRecallRatio;
  final double? advancedVadKeyFactRecallRatio;
  final double? speechBoundaryKeyFactRecallRatio;
  final bool? productBoundaryApproved;
  final bool? meetingModelLocked;
  final bool? factPcmSoleSourcePassed;
  final bool? emulatorLifecyclePassed;
  final bool? asrFailureRecordingContinues;
  final bool? startFailureDiagnosticsPassed;
  final bool? asrContextLifecyclePassed;
  final bool? vadContextLifecyclePassed;
  final bool? finalChunkBoundaryConsistent;
  final bool? previewDropFinalInvariant;
  final bool? finalTimestampsValid;
  final bool? snapshotAtomicityPassed;
  final bool? summaryFinalSnapshotOnly;
  final Map<String, String>? acceptanceEvidence;
  final bool? apkAuditPassed;
  final bool? android16KbPassed;
  final String? androidEvidenceRef;
  final bool? iosBuildAuditPassed;
  final String? iosBuildEvidenceRef;
  final bool? whisperCppLicenseConfirmed;

  AlphaReleaseEvaluationInput copyWith({
    int? schemaVersion,
    String? corpusEvidenceClass,
    String? corpusManifestSha256,
    String? corpusSourceId,
    String? corpusLicenseId,
    List<double>? standardRtfSamples,
    String? rawMetricsRef,
    bool? iosArm64DeviceTested,
    bool? iosBackgroundRecordingPassed,
    bool? iosInterruptionRecoveryPassed,
    bool? adaptiveNavigationAccessibilityPassed,
    bool? iosBuildAuditPassed,
    int? silenceSampleCount,
    int? silenceFalsePositiveCount,
    int? noiseSampleCount,
    int? baselineNoiseHallucinationCount,
    int? vadNoiseHallucinationCount,
    bool? vadChunkBoundaryConsistent,
    bool? vadFailureRecordingContinues,
    bool? android16KbPassed,
    bool? fixedWindowBothModelsCompleted,
    List<double>? previewSentenceLatencyMs,
    double? standardFixedWindowKeyFactRecallRatio,
    double? standardVadKeyFactRecallRatio,
    double? advancedVadKeyFactRecallRatio,
    double? speechBoundaryKeyFactRecallRatio,
    bool? productBoundaryApproved,
    bool? meetingModelLocked,
    bool? factPcmSoleSourcePassed,
    bool? emulatorLifecyclePassed,
    bool? asrFailureRecordingContinues,
    bool? startFailureDiagnosticsPassed,
    bool? asrContextLifecyclePassed,
    bool? vadContextLifecyclePassed,
    bool? finalChunkBoundaryConsistent,
    bool? previewDropFinalInvariant,
    bool? finalTimestampsValid,
    bool? snapshotAtomicityPassed,
    bool? summaryFinalSnapshotOnly,
  }) => AlphaReleaseEvaluationInput(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    corpusId: corpusId,
    corpusEvidenceClass: corpusEvidenceClass ?? this.corpusEvidenceClass,
    corpusManifestSha256: corpusManifestSha256 ?? this.corpusManifestSha256,
    corpusSourceId: corpusSourceId ?? this.corpusSourceId,
    corpusLicenseId: corpusLicenseId ?? this.corpusLicenseId,
    deviceId: deviceId,
    rawMetricsRef: rawMetricsRef ?? this.rawMetricsRef,
    corpusSampleCount: corpusSampleCount,
    corpusDeidentified: corpusDeidentified,
    sameCorpusForBothModels: sameCorpusForBothModels,
    sameDeviceForBothModels: sameDeviceForBothModels,
    lowEndArm64DeviceTested: lowEndArm64DeviceTested,
    iosArm64DeviceTested: iosArm64DeviceTested ?? this.iosArm64DeviceTested,
    iosBackgroundRecordingPassed:
        iosBackgroundRecordingPassed ?? this.iosBackgroundRecordingPassed,
    iosInterruptionRecoveryPassed:
        iosInterruptionRecoveryPassed ?? this.iosInterruptionRecoveryPassed,
    adaptiveNavigationAccessibilityPassed:
        adaptiveNavigationAccessibilityPassed ??
        this.adaptiveNavigationAccessibilityPassed,
    standardModelResourceBytes: standardModelResourceBytes,
    standardRtfSamples: standardRtfSamples ?? this.standardRtfSamples,
    standardSentenceLatencyMs: standardSentenceLatencyMs,
    finalTranscriptionDurationMs: finalTranscriptionDurationMs,
    recordingCompletenessRatio: recordingCompletenessRatio,
    sustainedSevereOrCriticalThermal: sustainedSevereOrCriticalThermal,
    silenceSampleCount: silenceSampleCount ?? this.silenceSampleCount,
    silenceFalsePositiveCount:
        silenceFalsePositiveCount ?? this.silenceFalsePositiveCount,
    noiseSampleCount: noiseSampleCount ?? this.noiseSampleCount,
    baselineNoiseHallucinationCount:
        baselineNoiseHallucinationCount ?? this.baselineNoiseHallucinationCount,
    vadNoiseHallucinationCount:
        vadNoiseHallucinationCount ?? this.vadNoiseHallucinationCount,
    vadChunkBoundaryConsistent:
        vadChunkBoundaryConsistent ?? this.vadChunkBoundaryConsistent,
    vadFailureRecordingContinues:
        vadFailureRecordingContinues ?? this.vadFailureRecordingContinues,
    standardEnergyWh: standardEnergyWh,
    advancedEnergyWh: advancedEnergyWh,
    advancedRtfSamples: advancedRtfSamples,
    advancedSentenceLatencyMs: advancedSentenceLatencyMs,
    advancedFinalTranscriptionDurationMs: advancedFinalTranscriptionDurationMs,
    keyFactRecallRatio: keyFactRecallRatio,
    fixedWindowBothModelsCompleted:
        fixedWindowBothModelsCompleted ?? this.fixedWindowBothModelsCompleted,
    previewSentenceLatencyMs:
        previewSentenceLatencyMs ?? this.previewSentenceLatencyMs,
    standardFixedWindowKeyFactRecallRatio:
        standardFixedWindowKeyFactRecallRatio ??
        this.standardFixedWindowKeyFactRecallRatio,
    standardVadKeyFactRecallRatio:
        standardVadKeyFactRecallRatio ?? this.standardVadKeyFactRecallRatio,
    advancedVadKeyFactRecallRatio:
        advancedVadKeyFactRecallRatio ?? this.advancedVadKeyFactRecallRatio,
    speechBoundaryKeyFactRecallRatio:
        speechBoundaryKeyFactRecallRatio ??
        this.speechBoundaryKeyFactRecallRatio,
    productBoundaryApproved:
        productBoundaryApproved ?? this.productBoundaryApproved,
    meetingModelLocked: meetingModelLocked ?? this.meetingModelLocked,
    factPcmSoleSourcePassed:
        factPcmSoleSourcePassed ?? this.factPcmSoleSourcePassed,
    emulatorLifecyclePassed:
        emulatorLifecyclePassed ?? this.emulatorLifecyclePassed,
    asrFailureRecordingContinues:
        asrFailureRecordingContinues ?? this.asrFailureRecordingContinues,
    startFailureDiagnosticsPassed:
        startFailureDiagnosticsPassed ?? this.startFailureDiagnosticsPassed,
    asrContextLifecyclePassed:
        asrContextLifecyclePassed ?? this.asrContextLifecyclePassed,
    vadContextLifecyclePassed:
        vadContextLifecyclePassed ?? this.vadContextLifecyclePassed,
    finalChunkBoundaryConsistent:
        finalChunkBoundaryConsistent ?? this.finalChunkBoundaryConsistent,
    previewDropFinalInvariant:
        previewDropFinalInvariant ?? this.previewDropFinalInvariant,
    finalTimestampsValid: finalTimestampsValid ?? this.finalTimestampsValid,
    snapshotAtomicityPassed:
        snapshotAtomicityPassed ?? this.snapshotAtomicityPassed,
    summaryFinalSnapshotOnly:
        summaryFinalSnapshotOnly ?? this.summaryFinalSnapshotOnly,
    acceptanceEvidence: acceptanceEvidence,
    apkAuditPassed: apkAuditPassed,
    android16KbPassed: android16KbPassed ?? this.android16KbPassed,
    androidEvidenceRef: androidEvidenceRef,
    iosBuildAuditPassed: iosBuildAuditPassed ?? this.iosBuildAuditPassed,
    iosBuildEvidenceRef: iosBuildEvidenceRef,
    whisperCppLicenseConfirmed: whisperCppLicenseConfirmed,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion ?? alphaReleaseInputSchemaVersion,
    'rawMetricsRef': rawMetricsRef,
    'corpus': {
      'id': corpusId,
      'sampleCount': corpusSampleCount,
      'deidentified': corpusDeidentified,
      'evidenceClass': corpusEvidenceClass,
      'manifestSha256': corpusManifestSha256,
      'provenance': {'sourceId': corpusSourceId, 'licenseId': corpusLicenseId},
    },
    'environment': {
      'deviceId': deviceId,
      'sameCorpusForBothModels': sameCorpusForBothModels,
      'sameDeviceForBothModels': sameDeviceForBothModels,
      'lowEndArm64DeviceTested': lowEndArm64DeviceTested,
      'iosArm64DeviceTested': iosArm64DeviceTested,
      'iosBackgroundRecordingPassed': iosBackgroundRecordingPassed,
      'iosInterruptionRecoveryPassed': iosInterruptionRecoveryPassed,
      'adaptiveNavigationAccessibilityPassed':
          adaptiveNavigationAccessibilityPassed,
    },
    'standardModel': {
      'resourceBytes': standardModelResourceBytes,
      'rtfSamples': standardRtfSamples,
      'sentenceLatencyMs': standardSentenceLatencyMs,
      'finalTranscriptionDurationMs': finalTranscriptionDurationMs,
      'recordingCompletenessRatio': recordingCompletenessRatio,
      'sustainedSevereOrCriticalThermal': sustainedSevereOrCriticalThermal,
      'keyFactRecallRatio': keyFactRecallRatio,
    },
    'energy': {'standardWh': standardEnergyWh, 'advancedWh': advancedEnergyWh},
    'vad': {
      'silenceSampleCount': silenceSampleCount,
      'silenceFalsePositiveCount': silenceFalsePositiveCount,
      'noiseSampleCount': noiseSampleCount,
      'baselineNoiseHallucinationCount': baselineNoiseHallucinationCount,
      'vadNoiseHallucinationCount': vadNoiseHallucinationCount,
      'chunkBoundaryConsistent': vadChunkBoundaryConsistent,
      'failureRecordingContinues': vadFailureRecordingContinues,
    },
    'advancedModel': {
      'rtfSamples': advancedRtfSamples,
      'sentenceLatencyMs': advancedSentenceLatencyMs,
      'finalTranscriptionDurationMs': advancedFinalTranscriptionDurationMs,
    },
    'quality': {
      'fixedWindowBothModelsCompleted': fixedWindowBothModelsCompleted,
      'previewSentenceLatencyMs': previewSentenceLatencyMs,
      'standardFixedWindowKeyFactRecallRatio':
          standardFixedWindowKeyFactRecallRatio,
      'standardVadKeyFactRecallRatio': standardVadKeyFactRecallRatio,
      'advancedVadKeyFactRecallRatio': advancedVadKeyFactRecallRatio,
      'speechBoundaryKeyFactRecallRatio': speechBoundaryKeyFactRecallRatio,
    },
    'phase04': {
      'productBoundaryApproved': productBoundaryApproved,
      'meetingModelLocked': meetingModelLocked,
      'factPcmSoleSourcePassed': factPcmSoleSourcePassed,
      'emulatorLifecyclePassed': emulatorLifecyclePassed,
      'asrFailureRecordingContinues': asrFailureRecordingContinues,
      'startFailureDiagnosticsPassed': startFailureDiagnosticsPassed,
      'asrContextLifecyclePassed': asrContextLifecyclePassed,
      'vadContextLifecyclePassed': vadContextLifecyclePassed,
      'finalChunkBoundaryConsistent': finalChunkBoundaryConsistent,
      'previewDropFinalInvariant': previewDropFinalInvariant,
      'finalTimestampsValid': finalTimestampsValid,
      'snapshotAtomicityPassed': snapshotAtomicityPassed,
      'summaryFinalSnapshotOnly': summaryFinalSnapshotOnly,
    },
    'evidence': {
      'android': androidEvidenceRef,
      'iosBuild': iosBuildEvidenceRef,
    },
    'acceptanceEvidence': acceptanceEvidence,
    'release': {
      'apkAuditPassed': apkAuditPassed,
      'android16KbPassed': android16KbPassed,
      'iosBuildAuditPassed': iosBuildAuditPassed,
      'whisperCppLicenseConfirmed': whisperCppLicenseConfirmed,
    },
  };
}

final class ReleaseGateResult {
  const ReleaseGateResult({
    required this.id,
    required this.requirement,
    required this.status,
    this.value,
  });

  final String id;
  final String requirement;
  final ReleaseGateStatus status;
  final Object? value;

  Map<String, Object?> toJson() => {
    'id': id,
    'requirement': requirement,
    'status': status.name,
    'value': value,
  };
}

final class AlphaReleaseEvaluationReport {
  const AlphaReleaseEvaluationReport({
    required this.decision,
    required this.corpusId,
    required this.corpusEvidenceClass,
    required this.corpusManifestSha256,
    required this.deviceId,
    required this.rawMetricsRef,
    required this.comparison,
    required this.gates,
  });

  final AlphaReleaseDecision decision;
  final String? corpusId;
  final String? corpusEvidenceClass;
  final String? corpusManifestSha256;
  final String? deviceId;
  final String? rawMetricsRef;
  final Map<String, Object?> comparison;
  final List<ReleaseGateResult> gates;

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'decision': decision.name,
    'corpusId': corpusId,
    'corpusEvidenceClass': corpusEvidenceClass,
    'corpusManifestSha256': corpusManifestSha256,
    'deviceId': deviceId,
    'rawMetricsRef': rawMetricsRef,
    'comparison': comparison,
    'summary': {
      'passed': gates
          .where((gate) => gate.status == ReleaseGateStatus.passed)
          .length,
      'failed': gates
          .where((gate) => gate.status == ReleaseGateStatus.failed)
          .length,
      'missing': gates
          .where((gate) => gate.status == ReleaseGateStatus.missing)
          .length,
    },
    'gates': gates.map((gate) => gate.toJson()).toList(growable: false),
  };
}

final class EvaluateAlphaReleaseUseCase {
  const EvaluateAlphaReleaseUseCase();

  AlphaReleaseEvaluationReport execute(AlphaReleaseEvaluationInput input) {
    final rtfP95 = _p95(input.standardRtfSamples, minimumSamples: 20);
    final latencyP95 = _p95(
      input.standardSentenceLatencyMs,
      minimumSamples: 20,
    );
    final advancedRtfP95 = _p95(input.advancedRtfSamples, minimumSamples: 20);
    final advancedLatencyP95 = _p95(
      input.advancedSentenceLatencyMs,
      minimumSamples: 20,
    );
    final previewLatencyP95 = _p95(
      input.previewSentenceLatencyMs,
      minimumSamples: 20,
    );
    final relativeEnergy = _ratio(
      input.standardEnergyWh,
      input.advancedEnergyWh,
    );
    final noiseReduction = _noiseReductionRatio(
      input.baselineNoiseHallucinationCount,
      input.vadNoiseHallucinationCount,
    );
    final acceptanceCount = _acceptanceEvidenceCount(input.acceptanceEvidence);
    final gates = <ReleaseGateResult>[
      _schemaGate(input.schemaVersion),
      _referenceGate('corpus.id', '评测语料必须具有不含音频路径的可追溯标识', input.corpusId),
      _exactTextGate(
        'corpus.evidenceClass',
        '正式发布质量门槛只接受 product-meeting 证据',
        input.corpusEvidenceClass,
        alphaProductMeetingEvidenceClass,
      ),
      _sha256Gate(
        'corpus.manifestSha256',
        '评测语料必须绑定 64 位十六进制 manifest SHA-256',
        input.corpusManifestSha256,
      ),
      _textGate(
        'corpus.provenance.sourceId',
        '评测语料必须具有来源标识',
        input.corpusSourceId,
      ),
      _textGate(
        'corpus.provenance.licenseId',
        '评测语料必须具有授权或许可标识',
        input.corpusLicenseId,
      ),
      _thresholdGate(
        'corpus.sampleCount',
        '去敏会议语料不少于 20 段',
        input.corpusSampleCount,
        (value) => value >= 20,
      ),
      _boolGate('corpus.deidentified', '评测语料已去敏', input.corpusDeidentified),
      _boolGate(
        'environment.sameCorpus',
        '双模型使用相同语料',
        input.sameCorpusForBothModels,
      ),
      _boolGate(
        'environment.sameDevice',
        '双模型使用相同设备和环境',
        input.sameDeviceForBothModels,
      ),
      _textGate('environment.deviceId', '评测设备必须具有可追溯标识', input.deviceId),
      _boolGate(
        'environment.lowEndArm64',
        '已在最低目标 Android arm64 实体设备验证',
        input.lowEndArm64DeviceTested,
      ),
      _boolGate(
        'environment.adaptiveNavigationAccessibility',
        'Android/iOS 原生返回、字体缩放和辅助技术验收通过',
        input.adaptiveNavigationAccessibilityPassed,
      ),
      _referenceGate(
        'evidence.rawMetrics',
        '双模型原始指标具有可追溯引用',
        input.rawMetricsRef,
      ),
      _referenceGate(
        'evidence.android',
        'Android 构建、模拟器与真机证据具有可追溯引用',
        input.androidEvidenceRef,
      ),
      _referenceGate(
        'evidence.iosBuild',
        'iOS 无真机构建与产物审计具有可追溯引用',
        input.iosBuildEvidenceRef,
      ),
      _boolGate(
        'quality.fixedWindowBothModels',
        'Base 和 Small 已在同语料完成固定窗口对照',
        input.fixedWindowBothModelsCompleted,
      ),
      _thresholdGate(
        'quality.previewLatencyP95Ms',
        'Preview 句后出字 P95 不超过 3000 ms',
        previewLatencyP95,
        (value) => value <= 3000,
      ),
      _ratioNoRegressionGate(
        'quality.standardVadRecallNoRegression',
        'Base 的 VAD 关键事实召回不得低于固定窗口基线',
        baseline: input.standardFixedWindowKeyFactRecallRatio,
        candidate: input.standardVadKeyFactRecallRatio,
      ),
      _ratioNoRegressionGate(
        'quality.advancedVadRecallNoRegression',
        'Small 的 VAD 关键事实召回不得低于 Base',
        baseline: input.standardVadKeyFactRecallRatio,
        candidate: input.advancedVadKeyFactRecallRatio,
      ),
      _boundedRatioThresholdGate(
        'quality.speechBoundaryRecall',
        '语音首尾已标注关键事实必须全部保留',
        input.speechBoundaryKeyFactRecallRatio,
        (value) => value == 1,
      ),
      _thresholdGate(
        'standard.resourceBytes',
        '标准模型资源不超过 100 MiB',
        input.standardModelResourceBytes,
        (value) => value <= 100 * 1024 * 1024,
      ),
      _thresholdGate(
        'standard.rtfP95',
        '最低目标设备 RTF P95 严格小于 0.5',
        rtfP95,
        (value) => value < 0.5,
      ),
      _thresholdGate(
        'standard.sentenceLatencyP95Ms',
        '句后出字 P95 不超过 3000 ms',
        latencyP95,
        (value) => value <= 3000,
      ),
      _thresholdGate(
        'standard.finalTranscriptionDurationMs',
        '30 分钟最终转录不超过 300000 ms',
        input.finalTranscriptionDurationMs,
        (value) => value <= 300000,
      ),
      _thresholdGate(
        'standard.recordingCompletenessRatio',
        '30 分钟录音完整率为 100%',
        input.recordingCompletenessRatio,
        (value) => value >= 1,
      ),
      _inverseBoolGate(
        'standard.thermal',
        '30 分钟内不持续进入 Severe/Critical',
        input.sustainedSevereOrCriticalThermal,
      ),
      _thresholdGate(
        'standard.relativeEnergy',
        '标准模型能耗不高于高级模型的 70%',
        relativeEnergy,
        (value) => value <= 0.7,
      ),
      _thresholdGate(
        'standard.keyFactRecallRatio',
        '20 段评测关键事实召回率不低于 85%',
        input.keyFactRecallRatio,
        (value) => value >= 0.85,
      ),
      _thresholdGate(
        'vad.silenceSampleCount',
        '纯静音评测样本不少于 20 段',
        input.silenceSampleCount,
        (value) => value >= 20,
      ),
      _thresholdGate(
        'vad.silenceFalsePositiveCount',
        '纯静音不得产生语音区间或文本',
        input.silenceFalsePositiveCount,
        (value) => value == 0,
      ),
      _thresholdGate(
        'vad.noiseSampleCount',
        '噪声评测样本不少于 20 段',
        input.noiseSampleCount,
        (value) => value >= 20,
      ),
      _thresholdGate(
        'vad.noiseReductionRatio',
        'VAD 相对固定窗口基线降低至少 80% 噪声幻觉',
        noiseReduction,
        (value) => value >= 0.8,
      ),
      _boolGate(
        'vad.chunkBoundaryConsistent',
        '相同 PCM 的不同 chunk 边界产生相同最终 VAD 区间',
        input.vadChunkBoundaryConsistent,
      ),
      _boolGate(
        'vad.failureRecordingContinues',
        'VAD 失败只降级预览且事实录音继续',
        input.vadFailureRecordingContinues,
      ),
      _boolGate(
        'phase04.productBoundaryApproved',
        '阶段 0 产品边界和质量门槛已批准',
        input.productBoundaryApproved,
      ),
      _boolGate(
        'phase04.meetingModelLocked',
        '会议开始后模型身份和版本保持锁定',
        input.meetingModelLocked,
      ),
      _boolGate(
        'phase04.factPcmSoleSource',
        '事实 PCM 是最终转录唯一事实源且写盘不依赖推理',
        input.factPcmSoleSourcePassed,
      ),
      _boolGate(
        'phase04.emulatorLifecycle',
        'Android 模拟器连续会议生命周期无资源残留',
        input.emulatorLifecyclePassed,
      ),
      _boolGate(
        'phase04.asrFailureRecordingContinues',
        'ASR 故障和预览积压不影响事实录音',
        input.asrFailureRecordingContinues,
      ),
      _boolGate(
        'phase04.startFailureDiagnostics',
        '会议启动失败具有稳定错误码和用户动作',
        input.startFailureDiagnosticsPassed,
      ),
      _boolGate(
        'phase04.asrContextLifecycle',
        'ASR context 百次生命周期无崩溃或持续泄漏',
        input.asrContextLifecyclePassed,
      ),
      _boolGate(
        'phase04.vadContextLifecycle',
        'VAD context 百次生命周期无崩溃或持续泄漏',
        input.vadContextLifecyclePassed,
      ),
      _boolGate(
        'phase04.finalChunkBoundaryConsistent',
        '相同 PCM 的不同 chunk 方式得到相同最终片段和排序',
        input.finalChunkBoundaryConsistent,
      ),
      _boolGate(
        'phase04.previewDropFinalInvariant',
        '丢弃预览任务不改变最终转录',
        input.previewDropFinalInvariant,
      ),
      _boolGate(
        'phase04.finalTimestampsValid',
        '最终时间戳无负值、越界、交叉或倒退',
        input.finalTimestampsValid,
      ),
      _boolGate(
        'phase04.snapshotAtomicity',
        '最终快照失败时旧活动快照保持激活',
        input.snapshotAtomicityPassed,
      ),
      _boolGate(
        'phase04.summaryFinalSnapshotOnly',
        'AI 总结只读取已激活完整最终快照',
        input.summaryFinalSnapshotOnly,
      ),
      _thresholdGate(
        'advanced.rtfSampleCount',
        '高级模型使用相同语料记录不少于 20 个 RTF 样本',
        _sampleCount(input.advancedRtfSamples),
        (value) => value >= 20,
      ),
      _thresholdGate(
        'advanced.sentenceLatencySampleCount',
        '高级模型使用相同语料记录不少于 20 个句后延迟样本',
        _sampleCount(input.advancedSentenceLatencyMs),
        (value) => value >= 20,
      ),
      _thresholdGate(
        'advanced.finalTranscriptionDurationMs',
        '高级模型记录 30 分钟最终转录耗时供支持分级',
        input.advancedFinalTranscriptionDurationMs,
        (value) => value >= 0,
      ),
      _thresholdGate(
        'acceptance.AT01-AT24',
        'AT-01 至 AT-24 均有非空证据引用',
        acceptanceCount,
        (value) => value == 24,
      ),
      _boolGate(
        'release.apkAudit',
        'Android APK 的 ABI、模型、密钥、许可和体积审计通过',
        input.apkAuditPassed,
      ),
      _boolGate(
        'release.android16Kb',
        'Android Release 全部原生库通过 16 KB LOAD alignment',
        input.android16KbPassed,
      ),
      _boolGate(
        'release.iosBuildAudit',
        'iOS 构建的 arm64、模型、密钥、许可和体积审计通过',
        input.iosBuildAuditPassed,
      ),
      _boolGate(
        'license.whisperCpp',
        'whisper.cpp 与模型权重 MIT 许可及 NOTICE 已确认',
        input.whisperCppLicenseConfirmed,
      ),
    ];
    final hasFailure = gates.any(
      (gate) => gate.status == ReleaseGateStatus.failed,
    );
    final hasMissing = gates.any(
      (gate) => gate.status == ReleaseGateStatus.missing,
    );
    return AlphaReleaseEvaluationReport(
      decision: hasFailure
          ? AlphaReleaseDecision.noGo
          : hasMissing
          ? AlphaReleaseDecision.blocked
          : AlphaReleaseDecision.go,
      corpusId: input.corpusId,
      corpusEvidenceClass: input.corpusEvidenceClass,
      corpusManifestSha256: input.corpusManifestSha256,
      deviceId: input.deviceId,
      rawMetricsRef: input.rawMetricsRef,
      comparison: {
        'standardModel': {
          'rtfP50': _percentile(
            input.standardRtfSamples,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'rtfP95': rtfP95,
          'sentenceLatencyP50Ms': _percentile(
            input.standardSentenceLatencyMs,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'sentenceLatencyP95Ms': latencyP95,
          'finalTranscriptionDurationMs': input.finalTranscriptionDurationMs,
        },
        'advancedModel': {
          'rtfP50': _percentile(
            input.advancedRtfSamples,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'rtfP95': advancedRtfP95,
          'sentenceLatencyP50Ms': _percentile(
            input.advancedSentenceLatencyMs,
            percentile: 0.5,
            minimumSamples: 20,
          ),
          'sentenceLatencyP95Ms': advancedLatencyP95,
          'finalTranscriptionDurationMs':
              input.advancedFinalTranscriptionDurationMs,
        },
        'quality': {
          'previewSentenceLatencyP95Ms': previewLatencyP95,
          'standardFixedWindowKeyFactRecallRatio': _finiteOrNull(
            input.standardFixedWindowKeyFactRecallRatio,
          ),
          'standardVadKeyFactRecallRatio': _finiteOrNull(
            input.standardVadKeyFactRecallRatio,
          ),
          'advancedVadKeyFactRecallRatio': _finiteOrNull(
            input.advancedVadKeyFactRecallRatio,
          ),
          'speechBoundaryKeyFactRecallRatio': _finiteOrNull(
            input.speechBoundaryKeyFactRecallRatio,
          ),
        },
        'standardToAdvancedEnergyRatio': relativeEnergy,
      },
      gates: List.unmodifiable(gates),
    );
  }
}

ReleaseGateResult _schemaGate(int? value) => ReleaseGateResult(
  id: 'input.schemaVersion',
  requirement: '发布评估输入必须使用当前 schema 4',
  status: value == alphaReleaseInputSchemaVersion
      ? ReleaseGateStatus.passed
      : ReleaseGateStatus.missing,
  value: value,
);

ReleaseGateResult _textGate(String id, String requirement, String? value) {
  final normalized = value?.trim();
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: normalized == null || normalized.isEmpty
        ? ReleaseGateStatus.missing
        : ReleaseGateStatus.passed,
    value: normalized,
  );
}

ReleaseGateResult _exactTextGate(
  String id,
  String requirement,
  String? value,
  String expected,
) {
  final normalized = value?.trim();
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: normalized == null || normalized.isEmpty
        ? ReleaseGateStatus.missing
        : normalized == expected
        ? ReleaseGateStatus.passed
        : ReleaseGateStatus.failed,
    value: normalized,
  );
}

ReleaseGateResult _sha256Gate(String id, String requirement, String? value) {
  final normalized = value?.trim();
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: normalized == null || normalized.isEmpty
        ? ReleaseGateStatus.missing
        : RegExp(r'^[0-9a-f]{64}$', caseSensitive: false).hasMatch(normalized)
        ? ReleaseGateStatus.passed
        : ReleaseGateStatus.failed,
    value: normalized,
  );
}

ReleaseGateResult _referenceGate(String id, String requirement, String? value) {
  final normalized = value?.trim();
  final containsAudioPath =
      normalized != null &&
      RegExp(
        r'\.(wav|pcm|m4a|aac|mp3|ogg|flac)(?:$|[?#])',
        caseSensitive: false,
      ).hasMatch(normalized);
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: normalized == null || normalized.isEmpty
        ? ReleaseGateStatus.missing
        : containsAudioPath
        ? ReleaseGateStatus.failed
        : ReleaseGateStatus.passed,
    value: normalized,
  );
}

ReleaseGateResult _boolGate(String id, String requirement, bool? value) =>
    ReleaseGateResult(
      id: id,
      requirement: requirement,
      status: value == null
          ? ReleaseGateStatus.missing
          : value
          ? ReleaseGateStatus.passed
          : ReleaseGateStatus.failed,
      value: value,
    );

ReleaseGateResult _inverseBoolGate(
  String id,
  String requirement,
  bool? value,
) => ReleaseGateResult(
  id: id,
  requirement: requirement,
  status: value == null
      ? ReleaseGateStatus.missing
      : value
      ? ReleaseGateStatus.failed
      : ReleaseGateStatus.passed,
  value: value,
);

ReleaseGateResult _thresholdGate<T extends num>(
  String id,
  String requirement,
  T? value,
  bool Function(T value) passes,
) => ReleaseGateResult(
  id: id,
  requirement: requirement,
  status: value == null
      ? ReleaseGateStatus.missing
      : passes(value)
      ? ReleaseGateStatus.passed
      : ReleaseGateStatus.failed,
  value: value,
);

ReleaseGateResult _boundedRatioThresholdGate(
  String id,
  String requirement,
  double? value,
  bool Function(double value) passes,
) => ReleaseGateResult(
  id: id,
  requirement: requirement,
  status: value == null
      ? ReleaseGateStatus.missing
      : !value.isFinite || value < 0 || value > 1
      ? ReleaseGateStatus.failed
      : passes(value)
      ? ReleaseGateStatus.passed
      : ReleaseGateStatus.failed,
  value: _finiteOrNull(value),
);

ReleaseGateResult _ratioNoRegressionGate(
  String id,
  String requirement, {
  required double? baseline,
  required double? candidate,
}) {
  final safeBaseline = _finiteOrNull(baseline);
  final safeCandidate = _finiteOrNull(candidate);
  final value = <String, double?>{
    'baseline': safeBaseline,
    'candidate': safeCandidate,
    'delta': safeBaseline == null || safeCandidate == null
        ? null
        : safeCandidate - safeBaseline,
  };
  if (baseline == null || candidate == null) {
    return ReleaseGateResult(
      id: id,
      requirement: requirement,
      status: ReleaseGateStatus.missing,
      value: value,
    );
  }
  final valid =
      baseline.isFinite &&
      candidate.isFinite &&
      baseline >= 0 &&
      baseline <= 1 &&
      candidate >= 0 &&
      candidate <= 1;
  return ReleaseGateResult(
    id: id,
    requirement: requirement,
    status: valid && candidate >= baseline
        ? ReleaseGateStatus.passed
        : ReleaseGateStatus.failed,
    value: value,
  );
}

double? _finiteOrNull(double? value) =>
    value != null && value.isFinite ? value : null;

double? _p95(List<double>? samples, {required int minimumSamples}) {
  return _percentile(samples, percentile: 0.95, minimumSamples: minimumSamples);
}

double? _percentile(
  List<double>? samples, {
  required double percentile,
  required int minimumSamples,
}) {
  if (samples == null || samples.length < minimumSamples) {
    return null;
  }
  if (samples.any((sample) => !sample.isFinite || sample < 0)) {
    return null;
  }
  final sorted = [...samples]..sort();
  final rank = math.max(1, (sorted.length * percentile).ceil());
  return sorted[rank - 1];
}

int? _sampleCount(List<double>? samples) {
  if (samples == null ||
      samples.any((sample) => !sample.isFinite || sample < 0)) {
    return null;
  }
  return samples.length;
}

double? _ratio(double? numerator, double? denominator) {
  if (numerator == null ||
      denominator == null ||
      !numerator.isFinite ||
      !denominator.isFinite ||
      numerator < 0 ||
      denominator <= 0) {
    return null;
  }
  return numerator / denominator;
}

int? _acceptanceEvidenceCount(Map<String, String>? evidence) {
  if (evidence == null) {
    return null;
  }
  return [
    for (var index = 1; index <= 24; index++)
      'AT-${index.toString().padLeft(2, '0')}',
  ].where((id) => evidence[id]?.trim().isNotEmpty == true).length;
}

double? _noiseReductionRatio(int? baselineCount, int? vadCount) {
  if (baselineCount == null ||
      vadCount == null ||
      baselineCount < 0 ||
      vadCount < 0) {
    return null;
  }
  if (baselineCount == 0) {
    return null;
  }
  return (baselineCount - vadCount) / baselineCount;
}

Map<String, Object?>? _map(Object? value) =>
    value is Map<String, Object?> ? value : null;

String? _string(Object? value) => value is String ? value : null;

bool? _boolean(Object? value) => value is bool ? value : null;

int? _integer(Object? value) => value is int ? value : null;

double? _number(Object? value) => value is num ? value.toDouble() : null;

List<double>? _numbers(Object? value) {
  if (value is! List<Object?>) {
    return null;
  }
  final numbers = value.whereType<num>().map((number) => number.toDouble());
  if (numbers.length != value.length) {
    return null;
  }
  return List.unmodifiable(numbers);
}

Map<String, String>? _strings(Object? value) {
  if (value is! Map<String, Object?>) {
    return null;
  }
  if (value.values.any((item) => item is! String)) {
    return null;
  }
  return Map.unmodifiable(
    value.map((key, item) => MapEntry(key, item! as String)),
  );
}
