import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// مسؤول عن تهيئة قاعدة البيانات
class DatabaseInitializer {
  /// تهيئة قاعدة البيانات حسب المنصة
  void initialize() {
    if (Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print("Database factory initialized for Windows");
    }
  }
}


