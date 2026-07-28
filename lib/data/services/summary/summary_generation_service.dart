import '../../../domain/ports/summary_generation.dart';

export '../../../domain/ports/summary_generation.dart';

/// 当前 Alpha 未配置安全网关，生产环境显式关闭云端总结。
final class UnavailableSummaryGenerationService
    implements SummaryGenerationService {
  const UnavailableSummaryGenerationService();

  @override
  SummaryGenerationCapability get capability =>
      const SummaryGenerationCapability.unavailable(
        reasonCode: 'summary.gateway_unavailable',
      );

  @override
  Future<GeneratedSummaryDraft> generate(SummaryGenerationRequest request) {
    throw const SummaryGenerationServiceException(
      'summary.gateway_unavailable',
    );
  }
}
