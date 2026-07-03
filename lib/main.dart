import 'dart:async';

import 'package:flutter/material.dart';
import 'package:golden_shamela/FontsLoaderController.dart';
import 'package:golden_shamela/core/app_initialization.dart';
import 'package:golden_shamela/core/app_routes.dart';

/// نقطة دخول التطبيق الرئيسية
main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialization = AppInitialization();
  final result = await initialization.initialize();

  runApp(MyApp(initialRoute: result.route));
  if (result.shouldPreloadFonts) {
    _preloadFontsAfterFirstFrame();
  }
}

void _preloadFontsAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 800),
      preloadAppAndCommonFonts,
    ));
  });
}
