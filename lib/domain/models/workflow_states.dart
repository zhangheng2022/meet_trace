enum MeetingState { created, recording, processing, completed, failed }

enum RecordingState {
  idle,
  starting,
  recording,
  paused,
  finalizing,
  completed,
  failed,
}

enum ProcessingState { idle, queued, running, completed, failed, canceled }

enum ModelInstallationState {
  notInstalled,
  checking,
  downloading,
  paused,
  verifying,
  installed,
  updateAvailable,
  deleting,
  failed,
}

final class InvalidStateTransitionException implements Exception {
  const InvalidStateTransitionException({
    required this.machine,
    required this.from,
    required this.to,
  });

  final String machine;
  final Enum from;
  final Enum to;

  @override
  String toString() {
    return 'InvalidStateTransitionException: '
        '$machine 不允许 ${from.name} → ${to.name}';
  }
}

extension MeetingStateTransition on MeetingState {
  bool canTransitionTo(MeetingState next) {
    return switch (this) {
      MeetingState.created => {
        MeetingState.recording,
        MeetingState.failed,
      }.contains(next),
      MeetingState.recording => {
        MeetingState.processing,
        MeetingState.failed,
      }.contains(next),
      MeetingState.processing => {
        MeetingState.completed,
        MeetingState.failed,
      }.contains(next),
      MeetingState.completed => next == MeetingState.processing,
      MeetingState.failed => {
        MeetingState.recording,
        MeetingState.processing,
      }.contains(next),
    };
  }

  MeetingState transitionTo(MeetingState next) {
    if (!canTransitionTo(next)) {
      throw InvalidStateTransitionException(
        machine: 'meeting',
        from: this,
        to: next,
      );
    }
    return next;
  }
}

extension RecordingStateTransition on RecordingState {
  bool canTransitionTo(RecordingState next) {
    return switch (this) {
      RecordingState.idle => next == RecordingState.starting,
      RecordingState.starting => {
        RecordingState.recording,
        RecordingState.failed,
      }.contains(next),
      RecordingState.recording => {
        RecordingState.paused,
        RecordingState.finalizing,
        RecordingState.failed,
      }.contains(next),
      RecordingState.paused => {
        RecordingState.recording,
        RecordingState.finalizing,
        RecordingState.failed,
      }.contains(next),
      RecordingState.finalizing => {
        RecordingState.completed,
        RecordingState.failed,
      }.contains(next),
      RecordingState.completed => false,
      RecordingState.failed => next == RecordingState.starting,
    };
  }

  RecordingState transitionTo(RecordingState next) {
    if (!canTransitionTo(next)) {
      throw InvalidStateTransitionException(
        machine: 'recording',
        from: this,
        to: next,
      );
    }
    return next;
  }
}

extension ProcessingStateTransition on ProcessingState {
  bool canTransitionTo(ProcessingState next) {
    return switch (this) {
      ProcessingState.idle => next == ProcessingState.queued,
      ProcessingState.queued => {
        ProcessingState.running,
        ProcessingState.canceled,
      }.contains(next),
      ProcessingState.running => {
        ProcessingState.completed,
        ProcessingState.failed,
        ProcessingState.canceled,
      }.contains(next),
      ProcessingState.completed ||
      ProcessingState.failed ||
      ProcessingState.canceled => next == ProcessingState.queued,
    };
  }

  ProcessingState transitionTo(ProcessingState next) {
    if (!canTransitionTo(next)) {
      throw InvalidStateTransitionException(
        machine: 'processing',
        from: this,
        to: next,
      );
    }
    return next;
  }
}

extension ModelInstallationStateTransition on ModelInstallationState {
  bool canTransitionTo(ModelInstallationState next) {
    return switch (this) {
      ModelInstallationState.notInstalled =>
        next == ModelInstallationState.checking,
      ModelInstallationState.checking => {
        ModelInstallationState.downloading,
        ModelInstallationState.failed,
      }.contains(next),
      ModelInstallationState.downloading => {
        ModelInstallationState.paused,
        ModelInstallationState.verifying,
        ModelInstallationState.failed,
      }.contains(next),
      ModelInstallationState.paused => {
        ModelInstallationState.downloading,
        ModelInstallationState.failed,
      }.contains(next),
      ModelInstallationState.verifying => {
        ModelInstallationState.installed,
        ModelInstallationState.failed,
      }.contains(next),
      ModelInstallationState.installed => {
        ModelInstallationState.updateAvailable,
        ModelInstallationState.deleting,
      }.contains(next),
      ModelInstallationState.updateAvailable => {
        ModelInstallationState.checking,
        ModelInstallationState.downloading,
        ModelInstallationState.deleting,
      }.contains(next),
      ModelInstallationState.deleting => {
        ModelInstallationState.notInstalled,
        ModelInstallationState.failed,
      }.contains(next),
      ModelInstallationState.failed => {
        ModelInstallationState.checking,
        ModelInstallationState.notInstalled,
      }.contains(next),
    };
  }

  ModelInstallationState transitionTo(ModelInstallationState next) {
    if (!canTransitionTo(next)) {
      throw InvalidStateTransitionException(
        machine: 'modelInstallation',
        from: this,
        to: next,
      );
    }
    return next;
  }
}
