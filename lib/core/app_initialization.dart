import 'dart:async';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:golden_shamela/Controllers/PathController.dart';
import 'package:golden_shamela/core/database_initializer.dart';
import 'package:golden_shamela/core/indexed_books_loader.dart';
import 'package:golden_shamela/core/window_manager_helper.dart';
import 'package:golden_shamela/core/preferences_helper.dart';
import 'package:golden_shamela/core/startup_indexer.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Helpers/BookFilesHelper.dart'
    as book_files_helper;
import 'package:golden_shamela/Services/WindowsStartupActions.dart';
import 'package:golden_shamela/Services/WindowsFontCatalog.dart';
import 'package:golden_shamela/Services/BookSourceChangeMonitor.dart';
import 'package:golden_shamela/UI/Settings/app_citation_settings.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/UI/Settings/app_recited_text_copy_settings.dart';
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

    await _initializePreferences();

    if (!windowInfo.isSubWindow) {
      await _windowManagerHelper.initializeMainWindow();
      await _initializePaths();
      unawaited(WindowsFontCatalog.refreshCacheInBackground());
      _databaseInitializer.initialize();
      _indexedBooksLoader.loadInBackground();

      // فهرسة الكتب الجديدة في الخلفية (لا تؤثر على بداية التطبيق)
      Future.microtask(() => StartupIndexer.runBackgroundCheck());

      await _initializeSearchEngine();
      unawaited(BookSourceChangeMonitor.runBackgroundCheck());
      await WindowsStartupActions.applyAtStartup();
    } else {
      _databaseInitializer.initialize();
      await windowManager.ensureInitialized();
      await windowManager.setSize(Size(1100, 900));
      await windowManager.center();

      await _initializeSearchEngine();
    }

    return InitializationResult(
      route: windowInfo.route,
      prefs: _prefs!,
      shouldPreloadFonts: !windowInfo.isSubWindow,
    );
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    PreferencesHelper.initialize(_prefs!);
    await AppFontSettings.instance.load();
    await AppColorSettings.instance.load();
    await AppCitationSettings.instance.load();
    await RecitedTextCopySettings.instance.load();
    await AppOtherSettings.instance.load();
  }

  Future<void> _initializePaths() async {
    await getPaths();
    // تنظيف الملفات المؤقتة المتبقية من أي عمليات فاشلة سابقة
    await book_files_helper.cleanTempBooks();
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
  final bool shouldPreloadFonts;

  InitializationResult({
    required this.route,
    required this.prefs,
    required this.shouldPreloadFonts,
  });
}
