import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:golden_shamela/Controllers/PathController.dart';
import 'package:golden_shamela/core/database_initializer.dart';
import 'package:golden_shamela/core/indexed_books_loader.dart';
import 'package:golden_shamela/core/window_manager_helper.dart';
import 'package:golden_shamela/core/preferences_helper.dart';
import 'package:golden_shamela/core/startup_indexer.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:window_manager/window_manager.dart';

/// مسؤول عن تهيئة التطبيق بالكامل
class AppInitialization {
  final DatabaseInitializer _databaseInitializer = DatabaseInitializer();
  final IndexedBooksLoader _indexedBooksLoader = IndexedBooksLoader();
  final WindowManagerHelper _windowManagerHelper = WindowManagerHelper();

  SharedPreferences? _prefs;

  /// تهيئة التطبيق
  Future<InitializationResult> initialize() async {
    final windowInfo = await _windowManagerHelper.parseWindowInfo();

    // تهيئة قاعدة البيانات و SharedPreferences لجميع النوافذ
    _databaseInitializer.initialize();
    await _initializePreferences();

    if (!windowInfo.isSubWindow) {
      await _windowManagerHelper.initializeMainWindow();
      _initializePaths();
      _indexedBooksLoader.loadInBackground();

      // فهرسة الكتب الجديدة في الخلفية (لا تؤثر على بداية التطبيق)
      Future.microtask(() => StartupIndexer.runBackgroundCheck());

      await _initializeSearchEngine();
    } else {
      await windowManager.ensureInitialized();
      await windowManager.setSize(Size(1100, 900));
      await windowManager.center();

      await _initializeSearchEngine();
    }

    return InitializationResult(route: windowInfo.route, prefs: _prefs!);
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    PreferencesHelper.initialize(_prefs!);
  }

  void _initializePaths() {
    getPaths();
  }

  Future<void> _initializeSearchEngine() async {
    try {
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      await metadataDb.migrateFromSharedPreferences();
    } catch (e) {
      print("Error initializing search engine: $e");
    }
  }
}

/// نتيجة عملية التهيئة
class InitializationResult {
  final String? route;
  final SharedPreferences prefs;

  InitializationResult({required this.route, required this.prefs});
}
