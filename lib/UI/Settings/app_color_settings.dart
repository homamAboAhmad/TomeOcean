import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

enum AppColorRole {
  titles('titles', 'لون العناوين', Color(0xFF0891B2)),
  searchWords('searchWords', 'لون كلمات البحث', Color(0xFFDC2626)),
  searchHighlight('searchHighlight', 'لون تمييز كلمات البحث', Color(0xFFD7FAF4)),
  comments('comments', 'لون التعليقات', Color(0xFF164E63)),
  commentBackground('commentBackground', 'لون خلفية التعليق', Color(0xFFE8F1F6));

  final String id;
  final String label;
  final Color defaultColor;

  const AppColorRole(this.id, this.label, this.defaultColor);
}

class AppColorDraft {
  final Map<AppColorRole, Color> colors;
  final List<Color> customColors;

  const AppColorDraft({
    required this.colors,
    required this.customColors,
  });

  factory AppColorDraft.defaults({List<Color> customColors = const []}) {
    return AppColorDraft(
      colors: {
        for (final role in AppColorRole.values) role: role.defaultColor,
      },
      customColors: List<Color>.of(customColors),
    );
  }

  AppColorDraft copyWith({
    Map<AppColorRole, Color>? colors,
    List<Color>? customColors,
  }) {
    return AppColorDraft(
      colors: colors ?? this.colors,
      customColors: customColors ?? this.customColors,
    );
  }
}

class AppColorSettings extends ChangeNotifier {
  static final AppColorSettings instance = AppColorSettings._();
  static const _prefsKey = 'app_ui_color_settings_v1';
  static const _legacyDefaultColors = {
    AppColorRole.titles: 0xFF72AA71,
    AppColorRole.searchWords: 0xFFE00000,
    AppColorRole.searchHighlight: 0xFFFFE082,
    AppColorRole.comments: 0xFF000000,
    AppColorRole.commentBackground: 0xFFE8E5D5,
  };

  Map<AppColorRole, Color> _colors = {
    for (final role in AppColorRole.values) role: role.defaultColor,
  };
  List<Color> _customColors = [];

  AppColorSettings._();

  Color color(AppColorRole role) => _colors[role] ?? role.defaultColor;

  AppColorDraft draft() {
    return AppColorDraft(
      colors: Map<AppColorRole, Color>.of(_colors),
      customColors: List<Color>.of(_customColors),
    );
  }

  Future<void> load() async {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final colors = Map<AppColorRole, Color>.of(_colors);
      final savedColors = decoded['colors'];
      if (savedColors is Map<String, dynamic>) {
        for (final role in AppColorRole.values) {
          final value = savedColors[role.id];
          if (value is int) {
            colors[role] = value == _legacyDefaultColors[role]
                ? role.defaultColor
                : Color(value);
          }
        }
      }

      final savedCustomColors = decoded['customColors'];
      _colors = colors;
      _customColors = savedCustomColors is List
          ? savedCustomColors.whereType<int>().map((value) => Color(value)).toList()
          : [];
    } catch (_) {
      _colors = {
        for (final role in AppColorRole.values) role: role.defaultColor,
      };
      _customColors = [];
    }
  }

  Future<void> save(AppColorDraft draft) async {
    _colors = Map<AppColorRole, Color>.of(draft.colors);
    _customColors = List<Color>.of(draft.customColors);

    final encoded = jsonEncode({
      'colors': {
        for (final entry in _colors.entries) entry.key.id: entry.value.value,
      },
      'customColors': [
        for (final color in _customColors) color.value,
      ],
    });
    await PreferencesHelper.prefs.setString(_prefsKey, encoded);
    notifyListeners();
  }

  Future<void> resetAll() async {
    await save(AppColorDraft.defaults(customColors: _customColors));
  }
}

class AppUiColors {
  AppUiColors._();

  static Color color(AppColorRole role) {
    return AppColorSettings.instance.color(role);
  }
}
