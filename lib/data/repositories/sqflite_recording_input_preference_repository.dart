import 'package:sqflite/sqflite.dart';

import '../../domain/models/recording_input.dart';
import '../../domain/ports/recording_input.dart';
import '../services/storage/app_database.dart';

final class SqfliteRecordingInputPreferenceRepository
    implements RecordingInputPreferenceRepository {
  const SqfliteRecordingInputPreferenceRepository(this._appDatabase);

  static const _deviceIdKey = 'recording_input_device_id';
  static const _deviceLabelKey = 'recording_input_device_label';
  static const _systemDefaultValue = '__system_default__';

  final AppDatabase _appDatabase;

  @override
  Future<RecordingInputPreference> getPreference() async {
    final db = await _appDatabase.open();
    final rows = await db.query(
      'app_settings',
      columns: const ['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: const [_deviceIdKey, _deviceLabelKey],
    );
    final values = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    final deviceId = values[_deviceIdKey];
    if (deviceId == null || deviceId == _systemDefaultValue) {
      return const RecordingInputPreference.systemDefault();
    }
    final label = values[_deviceLabelKey];
    if (label == null || label.trim().isEmpty) {
      throw const FormatException('录音输入偏好缺少设备名称，拒绝静默切换到系统默认麦克风');
    }
    return RecordingInputPreference.device(
      deviceId: deviceId,
      lastKnownLabel: label,
    );
  }

  @override
  Future<void> setPreference(RecordingInputPreference preference) async {
    final db = await _appDatabase.open();
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _upsert(
        txn,
        key: _deviceIdKey,
        value: preference.deviceId ?? _systemDefaultValue,
        updatedAt: now,
      );
      if (preference.usesSystemDefault) {
        await txn.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: const [_deviceLabelKey],
        );
      } else {
        await _upsert(
          txn,
          key: _deviceLabelKey,
          value: preference.lastKnownLabel!,
          updatedAt: now,
        );
      }
    });
  }
}

Future<void> _upsert(
  DatabaseExecutor executor, {
  required String key,
  required String value,
  required int updatedAt,
}) async {
  final row = <String, Object?>{'value': value, 'updated_at': updatedAt};
  final updated = await executor.update(
    'app_settings',
    row,
    where: 'key = ?',
    whereArgs: [key],
  );
  if (updated == 0) {
    await executor.insert('app_settings', {'key': key, ...row});
  }
}
