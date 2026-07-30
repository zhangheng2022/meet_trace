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
    const globalDefault = whisperSmallAdvancedModelId;

    final selection = resolver(
      globalDefaultModelId: globalDefault,
      availableVersions: const {
        whisperBaseStandardModelId: 'v1.9.1-q5_1',
        whisperSmallAdvancedModelId: 'v1.9.1-q5_1',
      },
    );

    expect(globalDefault, whisperSmallAdvancedModelId);
    expect(selection.requestedModelId, whisperSmallAdvancedModelId);
    expect(selection.recordingModelId, whisperSmallAdvancedModelId);
    expect(selection.recordingModelVersion, 'v1.9.1-q5_1');
    expect(selection.fallbackReason, isNull);
  });

  test('默认模型不可用时禁止自动回退', () {
    expect(
      () => resolver(
        globalDefaultModelId: whisperSmallAdvancedModelId,
        availableVersions: const {whisperBaseStandardModelId: 'v1.9.1-q5_1'},
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
  });
}
