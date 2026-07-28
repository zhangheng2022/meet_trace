import '../models/data_control.dart';

abstract interface class LocalDataControlPort {
  Future<LocalStorageUsage> measure();

  Future<DiagnosticReport> buildDiagnostics();
}
