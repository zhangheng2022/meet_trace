enum DownloadableModelPhase {
  checking,
  downloading,
  verifying,
  committing,
  ready,
  deleting,
}

final class DownloadableModelProgress {
  const DownloadableModelProgress({
    required this.phase,
    required this.completedBytes,
    required this.totalBytes,
  });

  final DownloadableModelPhase phase;
  final int completedBytes;
  final int totalBytes;
}

final class DownloadableModelResult {
  const DownloadableModelResult({
    required this.installedPath,
    required this.alreadyInstalled,
    required this.resumed,
  });

  final String installedPath;
  final bool alreadyInstalled;
  final bool resumed;
}

final class ModelDownloadCanceledException implements Exception {
  const ModelDownloadCanceledException();
}

typedef DownloadableModelProgressCallback = void Function(
  DownloadableModelProgress progress,
);

final class ModelDownloadCancellationToken {
  bool _isCanceled = false;
  final Set<void Function()> _listeners = {};

  bool get isCanceled => _isCanceled;

  void cancel() {
    if (_isCanceled) {
      return;
    }
    _isCanceled = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void throwIfCanceled() {
    if (_isCanceled) {
      throw const ModelDownloadCanceledException();
    }
  }

  void addCancelListener(void Function() listener) {
    if (_isCanceled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeCancelListener(void Function() listener) {
    _listeners.remove(listener);
  }
}
