import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final DatabaseFactory _windowsDatabaseFactory = _createWindowsFactory();

DatabaseFactory createPlatformDatabaseFactory({String? operatingSystem}) {
  if ((operatingSystem ?? Platform.operatingSystem) == 'windows') {
    return _windowsDatabaseFactory;
  }
  return databaseFactory;
}

DatabaseFactory _createWindowsFactory() {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
