import 'package:shared_preferences/shared_preferences.dart';

/// مساعد للحصول على SharedPreferences
class PreferencesHelper {
  static SharedPreferences? _prefs;

  /// تهيئة SharedPreferences
  static Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  /// الحصول على SharedPreferences
  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'SharedPreferences not initialized. Call PreferencesHelper.initialize() first.',
      );
    }
    return _prefs!;
  }
}


