import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class StorageHelper {
  static Future<void> saveMap(String key, Map<String, dynamic> map) async {
    String jsonString = jsonEncode(map);
    await prefs.setString(key, jsonString);
  }

  static Map<String, dynamic>? getMap(String key)  {
    String? jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  static Future<void> saveListOfMaps(String key, List<Map<String, dynamic>> list) async {
    String jsonString = jsonEncode(list);
    await prefs.setString(key, jsonString);
  }

  static List<Map<String, dynamic>>? getListOfMaps(String key)  {
    String? jsonString = prefs.getString(key);
    if (jsonString == null) return null;
    List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> removeKey(String key) async {
    await prefs.remove(key);
  }
}
