import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/domain_exception.dart';
import 'package:meettrace/domain/use_cases/resolve_meeting_model_selection.dart';

void main() {
  late ResolveMeetingModelSelection resolver;

  setUp(() {
    resolver = ResolveMeetingModelSelection(registry: AsrModelRegistry.alpha);
  });

  test('只选择全局默认模型', () {
    const globalDefault = senseVoiceDefaultModelId;

    final selection = resolver(
      globalDefaultModelId: globalDefault,
      availableVersions: const {senseVoiceDefaultModelId: '2024-07-17'},
    );

    expect(globalDefault, senseVoiceDefaultModelId);
    expect(selection.requestedModelId, senseVoiceDefaultModelId);
    expect(selection.recordingModelId, senseVoiceDefaultModelId);
    expect(selection.recordingModelVersion, '2024-07-17');
    expect(selection.recordingModelLanguage, 'auto');
    expect(selection.recordingModelUseInverseTextNormalization, isTrue);
    expect(selection.fallbackReason, isNull);
  });

  test('默认模型不可用时禁止自动回退', () {
    expect(
      () => resolver(
        globalDefaultModelId: senseVoiceDefaultModelId,
        availableVersions: const {},
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
  });
}
