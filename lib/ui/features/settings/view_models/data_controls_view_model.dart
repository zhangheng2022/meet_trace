import 'package:flutter/foundation.dart';

import '../../../../domain/models/data_control.dart';
import '../../../../domain/ports/local_data_control.dart';
import '../../../../domain/ports/text_share.dart';
import '../../../../domain/use_cases/build_meeting_share.dart';

final class DataControlsViewModel extends ChangeNotifier {
  DataControlsViewModel({required this.dataControl, required this.sharing});

  final LocalDataControlPort dataControl;
  final TextShareService sharing;

  LocalStorageUsage? _usage;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _message;
  bool _disposed = false;

  LocalStorageUsage? get usage => _usage;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get message => _message;

  Future<void> load() async {
    _isLoading = true;
    _notify();
    try {
      _usage = await dataControl.measure();
      _message = null;
    } on Object {
      _message = '存储用量读取失败';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> exportDiagnostics() async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _message = null;
    _notify();
    try {
      final report = await dataControl.buildDiagnostics();
      await sharing.share(
        MeetingShareDocument(
          subject: '会迹诊断信息',
          text: report.toJsonText(),
          fileName: 'meettrace-diagnostics.json',
        ),
      );
      _message = '已打开系统分享面板；诊断信息不含标题、转录、音频或本地路径';
    } on Object {
      _message = '诊断信息导出失败，请重试';
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
