import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/repository_contracts.dart';
import '../../../../domain/models/meeting.dart';
import '../../../core/view_state.dart';

final class MeetingListViewModel extends ChangeNotifier {
  MeetingListViewModel({required this.meetings});

  final MeetingRepository meetings;

  ViewState<List<Meeting>> _state = const ViewLoading();
  StreamSubscription<List<Meeting>>? _subscription;
  bool _disposed = false;

  ViewState<List<Meeting>> get state => _state;

  void load() {
    if (_subscription != null) {
      return;
    }
    _state = const ViewLoading();
    notifyListeners();
    _subscription = meetings.watchAll().listen(
      (items) {
        _state = ViewData(value: List.unmodifiable(items));
        _notify();
      },
      onError: (Object error) {
        _state = ViewError(error: error, retry: retry);
        _notify();
      },
    );
  }

  void retry() {
    final previous = _subscription;
    _subscription = null;
    _state = const ViewLoading();
    notifyListeners();
    if (previous == null) {
      load();
      return;
    }
    unawaited(previous.cancel().whenComplete(load));
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
