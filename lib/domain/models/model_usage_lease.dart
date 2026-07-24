final class ModelUsageLease {
  ModelUsageLease({
    required this.leaseId,
    required this.modelId,
    required this.version,
    required this.ownerId,
    required this.acquiredAt,
    required this.expiresAt,
  }) {
    for (final entry in {
      'leaseId': leaseId,
      'modelId': modelId,
      'version': version,
      'ownerId': ownerId,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        throw ArgumentError.value(entry.value, entry.key, '不能为空');
      }
    }
    if (!expiresAt.isAfter(acquiredAt)) {
      throw ArgumentError('expiresAt 必须晚于 acquiredAt');
    }
  }

  final String leaseId;
  final String modelId;
  final String version;
  final String ownerId;
  final DateTime acquiredAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) => expiresAt.isAfter(now);

  ModelUsageLease renew({
    required DateTime renewedAt,
    required DateTime expiresAt,
  }) {
    return ModelUsageLease(
      leaseId: leaseId,
      modelId: modelId,
      version: version,
      ownerId: ownerId,
      acquiredAt: renewedAt,
      expiresAt: expiresAt,
    );
  }
}
