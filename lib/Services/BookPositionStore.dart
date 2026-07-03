import 'dart:convert';

import 'package:golden_shamela/UI/Settings/app_other_settings.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

class BookOpenSource {
  static const recent = 'recent';
  static const favorite = 'favorite';
  static const other = 'other';
}

class BookPositionStore {
  static final instance = BookPositionStore._();
  static const _prefsKey = 'book_positions_v1';

  BookPositionStore._();

  int? load(String bookPath, String source) {
    if (!_enabled(source)) return null;
    final positions = _positions();
    return positions[_key(bookPath, source)];
  }

  Future<void> save(String bookPath, String source, int pageIndex) async {
    if (!_enabled(source) || bookPath.isEmpty) return;
    final positions = _positions();
    positions[_key(bookPath, source)] = pageIndex;
    await PreferencesHelper.prefs.setString(_prefsKey, jsonEncode(positions));
  }

  Map<String, int> _positions() {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) {
        return MapEntry(key, value is num ? value.toInt() : 0);
      });
    } catch (_) {
      return {};
    }
  }

  bool _enabled(String source) {
    final settings = AppOtherSettings.instance.draft();
    return switch (source) {
      BookOpenSource.recent => settings.rememberRecentBookPosition,
      BookOpenSource.favorite => settings.rememberFavoriteBookPosition,
      _ => settings.rememberOtherBookPosition,
    };
  }

  String _key(String bookPath, String source) => '$source|$bookPath';
}
