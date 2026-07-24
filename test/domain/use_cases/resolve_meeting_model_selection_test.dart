import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/asr_model_registry.dart';
import 'package:meetily_ai/domain/models/domain_exception.dart';
import 'package:meetily_ai/domain/use_cases/resolve_meeting_model_selection.dart';

void main() {
  late ResolveMeetingModelSelection resolver;

  setUp(() {
    resolver = ResolveMeetingModelSelection(registry: AsrModelRegistry.alpha);
  });

  test('本场覆盖选择高级模型且不改变传入的全局默认值', () {
    const globalDefault = paraformerStandardModelId;

    final selection = resolver(
      globalDefaultModelId: globalDefault,
      meetingOverrideModelId: qwenAdvancedModelId,
      availableVersions: const {
        paraformerStandardModelId: '2024-03-09',
        qwenAdvancedModelId: '2026-03-25',
      },
    );

    expect(globalDefault, paraformerStandardModelId);
    expect(selection.requestedModelId, qwenAdvancedModelId);
    expect(selection.recordingModelId, qwenAdvancedModelId);
    expect(selection.recordingModelVersion, '2026-03-25');
    expect(selection.fallbackReason, isNull);
  });

  test('请求模型不可用时禁止自动回退', () {
    expect(
      () => resolver(
        globalDefaultModelId: qwenAdvancedModelId,
        availableVersions: const {paraformerStandardModelId: '2024-03-09'},
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );
  });

  test('只有显式提供回退模型和原因才允许开始', () {
    final selection = resolver(
      globalDefaultModelId: qwenAdvancedModelId,
      confirmedFallbackModelId: paraformerStandardModelId,
      fallbackReason: '用户确认高级模型尚未安装',
      availableVersions: const {paraformerStandardModelId: '2024-03-09'},
    );

    expect(selection.requestedModelId, qwenAdvancedModelId);
    expect(selection.recordingModelId, paraformerStandardModelId);
    expect(selection.recordingModelVersion, '2024-03-09');
    expect(selection.fallbackReason, '用户确认高级模型尚未安装');
  });
}
