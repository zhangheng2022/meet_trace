import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:meettrace/domain/ports/recording_input.dart';
import 'package:meettrace/domain/use_cases/lock_recording_input.dart';

void main() {
  group('LockRecordingInputUseCase', () {
    test('系统默认在确认存在可用输入后保持延迟解析', () async {
      final devices = _DeviceCatalog(const [
        RecordingInputDevice(id: 'mic-1', label: 'USB 麦克风'),
      ]);
      final useCase = LockRecordingInputUseCase(
        preferences: _PreferenceRepository(
          const RecordingInputPreference.systemDefault(),
        ),
        devices: devices,
      );

      final locked = await useCase.execute();

      expect(locked.usesSystemDefault, isTrue);
      expect(devices.listCalls, 1);
    });

    test('系统默认但没有任何输入设备时阻止开始', () async {
      final useCase = LockRecordingInputUseCase(
        preferences: _PreferenceRepository(
          const RecordingInputPreference.systemDefault(),
        ),
        devices: _DeviceCatalog(const []),
      );

      await expectLater(
        useCase.execute(),
        throwsA(
          isA<RecordingInputUnavailableException>().having(
            (error) => error.reason,
            'reason',
            RecordingInputUnavailableReason.noAvailableDevice,
          ),
        ),
      );
    });

    test('显式偏好按稳定 ID 锁定当次枚举的设备身份', () async {
      final useCase = LockRecordingInputUseCase(
        preferences: _PreferenceRepository(
          const RecordingInputPreference.device(
            deviceId: 'mic-2',
            lastKnownLabel: '旧名称',
          ),
        ),
        devices: _DeviceCatalog(const [
          RecordingInputDevice(id: 'mic-2', label: '会议室麦克风'),
        ]),
      );

      final locked = await useCase.execute();

      expect(
        locked.device,
        const RecordingInputDevice(id: 'mic-2', label: '会议室麦克风'),
      );
    });

    test('已选设备缺失时阻止开始，不静默切换', () async {
      final useCase = LockRecordingInputUseCase(
        preferences: _PreferenceRepository(
          const RecordingInputPreference.device(
            deviceId: 'missing',
            lastKnownLabel: '拔出的 USB 麦克风',
          ),
        ),
        devices: _DeviceCatalog(const [
          RecordingInputDevice(id: 'mic-other', label: '内置麦克风'),
        ]),
      );

      await expectLater(
        useCase.execute(),
        throwsA(
          isA<RecordingInputUnavailableException>()
              .having((error) => error.deviceId, 'deviceId', 'missing')
              .having(
                (error) => error.reason,
                'reason',
                RecordingInputUnavailableReason.preferredDeviceUnavailable,
              )
              .having(
                (error) => error.lastKnownLabel,
                'lastKnownLabel',
                '拔出的 USB 麦克风',
              ),
        ),
      );
    });
  });

  test('设备中断只规划一次系统默认回退，第二次进入中断', () {
    const useCase = PlanRecordingInputRecoveryUseCase();

    final first = useCase.execute(const RecordingInputRecoveryState());
    final second = useCase.execute(first.nextState);

    expect(first.action, RecordingInputRecoveryAction.switchToSystemDefault);
    expect(first.nextState.systemDefaultAttempted, isTrue);
    expect(second.action, RecordingInputRecoveryAction.interrupt);
    expect(second.nextState, same(first.nextState));
  });
}

final class _PreferenceRepository
    implements RecordingInputPreferenceRepository {
  _PreferenceRepository(this.preference);

  RecordingInputPreference preference;

  @override
  Future<RecordingInputPreference> getPreference() async => preference;

  @override
  Future<void> setPreference(RecordingInputPreference preference) async {
    this.preference = preference;
  }
}

final class _DeviceCatalog implements RecordingInputDeviceCatalog {
  _DeviceCatalog(this.devices);

  final List<RecordingInputDevice> devices;
  int listCalls = 0;

  @override
  Future<List<RecordingInputDevice>> listAvailable() async {
    listCalls++;
    return devices;
  }
}
