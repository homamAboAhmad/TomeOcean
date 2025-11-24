import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/HomePage.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'Controllers/PathController.dart';
import 'Helpers/BooksMetadataDatabase.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late SharedPreferences prefs;

// WordDocument wordDocument = WordDocument();
List<WordDocument> openedBooks  =[WordDocument()];
Archive docArchive = Archive();
//
 main()async {
   WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite for Windows (required for desktop platforms)
  // This must be called before any database operations
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print("Database factory initialized for Windows");
  }
  
  prefs = await SharedPreferences.getInstance();
  getPaths();
  runApp(MyApp());
  // runApp(Testapp2());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize Shamela search engine
    _initializeSearchEngine();
  }

  Future<void> _initializeSearchEngine() async {
    try {
      // Initialize metadata database and run migration if needed
      final metadataDb = BooksMetadataDatabase();
      await metadataDb.initialize();
      
      // Run migration from SharedPreferences to SQLite (one-time)
      final migrated = await metadataDb.migrateFromSharedPreferences();
      if (migrated) {
        print("BooksMetadataDatabase: Migration from SharedPreferences completed");
      }
      
      // The database is initialized on first use, no need to initialize here
      print("Shamela search engine ready");
    } catch (e) {
      print("Error initializing search engine: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: HomePage(),
    );
  }
}

