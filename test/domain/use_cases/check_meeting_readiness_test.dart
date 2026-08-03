import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/asr_model_registry.dart';
import 'package:meettrace/domain/models/meeting_readiness.dart';
import 'package:meettrace/domain/use_cases/check_meeting_readiness.dart';

import '../../support/model_selection_fakes.dart';

void main() {
  group('CheckMeetingReadinessUseCase', () {
    late TestModelPreferences preferences;
    late TestActiveInstallations installations;
    late _DeviceProbe device;

    setUp(() {
      preferences = TestModelPreferences(senseVoiceDefaultModelId);
      installations = TestActiveInstallations();
      device = _DeviceProbe();
    });

    tearDown(() => installations.dispose());

    test('权限、空间和已校验默认模型全部可用时允许开始', () async {
      final standard = AsrModelRegistry.alpha.defaultModel;
      installations.install(installations.installed(standard), active: true);
      final useCase = CheckMeetingReadinessUseCase(
        device: device,
        preferences: preferences,
        installations: installations,
      );

      final result = await useCase.check();

      expect(result.canStart, isTrue);
      expect(result.issues, isEmpty);
      expect(result.defaultModelName, standard.displayName);
      expect(device.permissionRequests, [false]);
    });

    test('同时返回权限、空间和默认模型三项真实阻塞', () async {
      device = _DeviceProbe(
        microphonePermissionGranted: false,
        freeBytes: minimumRecordingFreeBytes - 1,
      );
      final useCase = CheckMeetingReadinessUseCase(
        device: device,
        preferences: preferences,
        installations: installations,
      );

      final result = await useCase.check(requestMicrophonePermission: true);

      expect(result.canStart, isFalse);
      expect(result.issues, [
        MeetingReadinessIssue.microphonePermission,
        MeetingReadinessIssue.insufficientStorage,
        MeetingReadinessIssue.defaultModelUnavailable,
      ]);
      expect(device.permissionRequests, [true]);
    });
  });
}

final class _DeviceProbe implements RecordingDeviceReadinessProbe {
  _DeviceProbe({
    this.microphonePermissionGranted = true,
    this.freeBytes = minimumRecordingFreeBytes,
  });

  final bool microphonePermissionGranted;
  final int freeBytes;
  final List<bool> permissionRequests = [];

  @override
  Future<RecordingDeviceReadiness> check({
    required bool requestMicrophonePermission,
  }) async {
    permissionRequests.add(requestMicrophonePermission);
    return RecordingDeviceReadiness(
      microphonePermissionGranted: microphonePermissionGranted,
      freeBytes: freeBytes,
    );
  }
}
