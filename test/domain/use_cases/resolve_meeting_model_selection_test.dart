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
    const globalDefault = qwenAdvancedModelId;

    final selection = resolver(
      globalDefaultModelId: globalDefault,
      availableVersions: const {
        paraformerStandardModelId: '2024-03-09',
        qwenAdvancedModelId: '2026-03-25',
      },
    );

    expect(globalDefault, qwenAdvancedModelId);
    expect(selection.requestedModelId, qwenAdvancedModelId);
    expect(selection.recordingModelId, qwenAdvancedModelId);
    expect(selection.recordingModelVersion, '2026-03-25');
    expect(selection.fallbackReason, isNull);
  });

  test('默认模型不可用时禁止自动回退', () {
    expect(
      () => resolver(
        globalDefaultModelId: qwenAdvancedModelId,
        availableVersions: const {paraformerStandardModelId: '2024-03-09'},
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
  });
}
