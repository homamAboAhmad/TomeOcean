import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:golden_shamela/core/app_state.dart';

/// معلومات النافذة بعد التحليل
class WindowInfo {
  final String? route;
  final bool isSubWindow;

  WindowInfo({required this.route, required this.isSubWindow});
}

/// مسؤول عن إدارة النوافذ
class WindowManagerHelper {
  final AppState _appState = AppState();

  /// تحليل معلومات النافذة الحالية
  Future<WindowInfo> parseWindowInfo() async {
    try {
      final windowController = await WindowController.fromCurrentEngine();
      final windowArgs = windowController.arguments;

      if (windowArgs.isEmpty) {
        return WindowInfo(route: null, isSubWindow: false);
      }

      try {
        final argsMap = jsonDecode(windowArgs) as Map<String, dynamic>;
        if (argsMap['windowType'] == 'search') {
          return WindowInfo(route: '/search', isSubWindow: true);
        }
      } catch (_) {
        if (windowArgs.startsWith('/')) {
          return WindowInfo(route: windowArgs, isSubWindow: true);
        }
      }
    } catch (_) {
      // Main window - WindowController.fromCurrentEngine() throws if not a sub-window
    }

    return WindowInfo(route: null, isSubWindow: false);
  }

  /// تهيئة النافذة الرئيسية
  Future<void> initializeMainWindow() async {
    if (!Platform.isWindows) return;

    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1400, 820),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    _saveMainWindowId();
  }

  void _saveMainWindowId() {
    WindowController.fromCurrentEngine()
        .then((controller) {
          _appState.mainWindowId = controller.windowId;
        })
        .catchError((_) {
          // Main window might not have WindowController, use window_manager instead
        });
  }
}
