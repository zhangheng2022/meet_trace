import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/model_usage_lease.dart';

void main() {
  test('租约只在 expiresAt 之前有效', () {
    final lease = ModelUsageLease(
      leaseId: 'lease-1',
      modelId: 'qwen',
      version: '1',
      ownerId: 'meeting-1',
      acquiredAt: DateTime.utc(2026, 7, 24, 12),
      expiresAt: DateTime.utc(2026, 7, 24, 12, 5),
    );

    expect(lease.isActiveAt(DateTime.utc(2026, 7, 24, 12, 4)), isTrue);
    expect(lease.isActiveAt(DateTime.utc(2026, 7, 24, 12, 5)), isFalse);
  });

  test('拒绝空占用者和非递增租约时间', () {
    expect(
      () => ModelUsageLease(
        leaseId: 'lease-1',
        modelId: 'qwen',
        version: '1',
        ownerId: '',
        acquiredAt: DateTime.utc(2026, 7, 24, 12),
        expiresAt: DateTime.utc(2026, 7, 24, 12, 5),
      ),
      throwsArgumentError,
    );
    expect(
      () => ModelUsageLease(
        leaseId: 'lease-1',
        modelId: 'qwen',
        version: '1',
        ownerId: 'meeting-1',
        acquiredAt: DateTime.utc(2026, 7, 24, 12),
        expiresAt: DateTime.utc(2026, 7, 24, 12),
      ),
      throwsArgumentError,
    );
  });
}
