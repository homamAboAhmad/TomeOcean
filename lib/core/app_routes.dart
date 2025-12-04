import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/HomePage.dart';
import 'package:golden_shamela/UI/Search/search_window_route.dart';
import 'package:golden_shamela/core/app_state.dart';

/// مسؤول عن إدارة التوجيه في التطبيق
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomePage(),
      search: (context) => const SearchWindowRoute(),
    };
  }
}

/// تطبيق Flutter الرئيسي
class MyApp extends StatefulWidget {
  final String? initialRoute;
  
  const MyApp({Key? key, this.initialRoute}) : super(key: key);
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final appState = AppState();
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appState.navigatorKey,
      initialRoute: widget.initialRoute ?? AppRoutes.home,
      routes: AppRoutes.getRoutes(),
    );
  }
}


