import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/HomePage.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Controllers/PathController.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late SharedPreferences prefs;

// WordDocument wordDocument = WordDocument();
List<WordDocument> openedBooks  =[WordDocument()];
Archive docArchive = Archive();

 main()async {
   WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  getPaths();
  runApp(MyApp());
  // runApp(Testapp2());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: HomePage(),
    );
  }
}

