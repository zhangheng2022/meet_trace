final class DomainInvariantViolation implements Exception {
  const DomainInvariantViolation(this.message);

  final String message;

  @override
  String toString() => 'DomainInvariantViolation: $message';
}
