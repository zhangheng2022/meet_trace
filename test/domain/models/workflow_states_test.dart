import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/domain/models/workflow_states.dart';

void main() {
  group('MeetingStateMachine', () {
    test('允许 created → recording → processing → completed', () {
      expect(
        MeetingState.created.transitionTo(MeetingState.recording),
        MeetingState.recording,
      );
      expect(
        MeetingState.recording.transitionTo(MeetingState.processing),
        MeetingState.processing,
      );
      expect(
        MeetingState.processing.transitionTo(MeetingState.completed),
        MeetingState.completed,
      );
    });

    test('拒绝 created 直接变为 completed', () {
      expect(
        () => MeetingState.created.transitionTo(MeetingState.completed),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });
  });

  group('RecordingStateMachine', () {
    test('暂停后可以继续或结束', () {
      expect(
        RecordingState.paused.canTransitionTo(RecordingState.recording),
        true,
      );
      expect(
        RecordingState.paused.canTransitionTo(RecordingState.finalizing),
        true,
      );
    });

    test('完成后不能回到录音中', () {
      expect(
        () => RecordingState.completed.transitionTo(RecordingState.recording),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });
  });

  group('ProcessingStateMachine', () {
    test('失败后只能重新排队', () {
      expect(
        ProcessingState.failed.transitionTo(ProcessingState.queued),
        ProcessingState.queued,
      );
      expect(
        () => ProcessingState.failed.transitionTo(ProcessingState.completed),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });
  });

  group('ModelInstallationStateMachine', () {
    test('覆盖下载、暂停、校验和安装路径', () {
      expect(
        ModelInstallationState.notInstalled.transitionTo(
          ModelInstallationState.checking,
        ),
        ModelInstallationState.checking,
      );
      expect(
        ModelInstallationState.downloading.transitionTo(
          ModelInstallationState.paused,
        ),
        ModelInstallationState.paused,
      );
      expect(
        ModelInstallationState.verifying.transitionTo(
          ModelInstallationState.installed,
        ),
        ModelInstallationState.installed,
      );
    });

    test('内置或已安装模型不能跳回下载中', () {
      expect(
        () => ModelInstallationState.installed.transitionTo(
          ModelInstallationState.downloading,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('已安装文件损坏后可以进入 failed 并重试校验', () {
      expect(
        ModelInstallationState.installed.transitionTo(
          ModelInstallationState.failed,
        ),
        ModelInstallationState.failed,
      );
      expect(
        ModelInstallationState.failed.transitionTo(
          ModelInstallationState.checking,
        ),
        ModelInstallationState.checking,
      );
    });
  });
}
