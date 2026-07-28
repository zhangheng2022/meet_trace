import '../../../domain/models/recording.dart';
import '../../../domain/models/workflow_states.dart';

final class ReliableRecordingException implements Exception {
  const ReliableRecordingException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ReliableRecordingException($code, $message)';
}

/// 事实音频录制会话的纯 Dart 契约。
abstract interface class RecordingSessionService {
  RecordingState get state;

  Duration get duration;

  /// 当前会话是否仍有可封存或需要清理的事实音频。
  bool get canFinalize;

  Future<void> start({required String meetingId});

  Future<void> pause();

  Future<void> resume();

  Future<RecordingArtifact> stop();
}
