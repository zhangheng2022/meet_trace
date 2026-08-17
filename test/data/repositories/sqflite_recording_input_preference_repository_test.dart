import 'package:flutter_test/flutter_test.dart';
import 'package:meettrace/data/repositories/sqflite_recording_input_preference_repository.dart';
import 'package:meettrace/data/services/storage/app_database.dart';
import 'package:meettrace/domain/models/recording_input.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqfliteRecordingInputPreferenceRepository repository;

  setUp(() {
    database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqfliteRecordingInputPreferenceRepository(database);
  });

  tearDown(() => database.close());

  test('没有设置时使用系统默认麦克风', () async {
    expect(
      await repository.getPreference(),
      const RecordingInputPreference.systemDefault(),
    );
  });

  test('保存并读取稳定设备 ID 与名称', () async {
    const preference = RecordingInputPreference.device(
      deviceId: 'mic-usb-1',
      lastKnownLabel: 'USB 麦克风',
    );

    await repository.setPreference(preference);

    expect(await repository.getPreference(), preference);
  });

  test('切回系统默认时删除旧设备名称', () async {
    await repository.setPreference(
      const RecordingInputPreference.device(
        deviceId: 'mic-usb-1',
        lastKnownLabel: 'USB 麦克风',
      ),
    );

    await repository.setPreference(
      const RecordingInputPreference.systemDefault(),
    );

    expect(
      await repository.getPreference(),
      const RecordingInputPreference.systemDefault(),
    );
  });

  test('显式设备偏好损坏时拒绝静默切换到系统默认', () async {
    final db = await database.open();
    await db.insert('app_settings', {
      'key': 'recording_input_device_id',
      'value': 'mic-usb-1',
      'updated_at': 1,
    });

    await expectLater(repository.getPreference(), throwsFormatException);
  });
}
