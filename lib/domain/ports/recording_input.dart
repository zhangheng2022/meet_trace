import '../models/recording_input.dart';

abstract interface class RecordingInputDeviceCatalog {
  Future<List<RecordingInputDevice>> listAvailable();
}

abstract interface class RecordingInputPreferenceRepository {
  Future<RecordingInputPreference> getPreference();

  Future<void> setPreference(RecordingInputPreference preference);
}
