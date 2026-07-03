import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:golden_shamela/FontsLoaderController.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

enum AppFontRole {
  bookCard('bookCard', 'خط بطاقة الكتاب', 15),
  comments('comments', 'خط التعليقات', 15),
  headingTree('headingTree', 'خط شجرة العناوين', 13),
  searchResults('searchResults', 'خط جدول نتائج البحث', 12),
  bookLists('bookLists', 'خط قوائم الكتب ونحوها', 14);

  final String id;
  final String label;
  final double defaultSize;

  const AppFontRole(this.id, this.label, this.defaultSize);
}

class AppFontScript {
  final String id;
  final String label;
  final String sample;
  final int codePoint;

  const AppFontScript(this.id, this.label, this.sample, this.codePoint);
}

const appFontScripts = [
  AppFontScript('Arabic', 'Arabic', 'قل هو الله أحد\nالحمد لله رب العالمين', 0x0642),
  AppFontScript('Latin', 'Latin', 'The quick brown fox\njumps over the lazy dog', 0x0041),
  AppFontScript('Syriac', 'Syriac', 'ܐܒܓܕܗ\nܫܠܡܐ', 0x0710),
  AppFontScript('Thaana', 'Thaana', 'ދިވެހި\nބަސް', 0x0780),
  AppFontScript('Devanagari', 'Devanagari', 'कखगघ\nअआइई', 0x0915),
  AppFontScript('Bengali', 'Bengali', 'কখগঘ\nঅআইঈ', 0x0995),
  AppFontScript('Gurmukhi', 'Gurmukhi', 'ਕਖਗਘ\nਅਆਇਈ', 0x0A15),
  AppFontScript('Gujarati', 'Gujarati', 'કખગઘ\nઅઆઇઈ', 0x0A95),
  AppFontScript('Oriya', 'Oriya', 'କଖଗଘ\nଅଆଇଈ', 0x0B15),
  AppFontScript('Tamil', 'Tamil', 'கஙசஞ\nஅஆஇஈ', 0x0B95),
  AppFontScript('Telugu', 'Telugu', 'కఖగఘ\nఅఆఇఈ', 0x0C15),
];

class AppFontChoice {
  final String fontFamily;
  final String styleName;
  final double fontSize;
  final double lineSpacing;
  final String script;

  const AppFontChoice({
    this.fontFamily = '',
    this.styleName = 'Regular',
    required this.fontSize,
    this.lineSpacing = 1.0,
    this.script = 'Arabic',
  });

  AppFontChoice copyWith({
    String? fontFamily,
    String? styleName,
    double? fontSize,
    double? lineSpacing,
    String? script,
  }) {
    return AppFontChoice(
      fontFamily: fontFamily ?? this.fontFamily,
      styleName: styleName ?? this.styleName,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      script: script ?? this.script,
    );
  }

  Map<String, Object> toJson() => {
        'fontFamily': fontFamily,
        'styleName': styleName,
        'fontSize': fontSize,
        'lineSpacing': lineSpacing,
        'script': script,
      };

  static AppFontChoice fromJson(Map<String, dynamic> json, AppFontRole role) {
    return AppFontChoice(
      fontFamily: json['fontFamily'] as String? ?? '',
      styleName: json['styleName'] as String? ?? 'Regular',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? role.defaultSize,
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.0,
      script: json['script'] as String? ?? 'Arabic',
    );
  }
}

class AppFontSettings extends ChangeNotifier {
  static final AppFontSettings instance = AppFontSettings._();
  static const _prefsKey = 'app_ui_font_settings_v1';

  final Map<AppFontRole, AppFontChoice> _choices = {
    for (final role in AppFontRole.values)
      role: AppFontChoice(fontSize: role.defaultSize),
  };

  AppFontSettings._();

  AppFontChoice choice(AppFontRole role) => _choices[role]!;

  Map<AppFontRole, AppFontChoice> draft() => Map.of(_choices);

  Future<void> load() async {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final role in AppFontRole.values) {
        final value = decoded[role.id];
        if (value is Map<String, dynamic>) {
          _choices[role] = AppFontChoice.fromJson(value, role);
        }
      }
    }
    await _loadSelectedFamilies();
  }

  Future<void> save(Map<AppFontRole, AppFontChoice> choices) async {
    _choices
      ..clear()
      ..addAll(choices);
    await _loadSelectedFamilies();
    final encoded = jsonEncode({
      for (final entry in _choices.entries) entry.key.id: entry.value.toJson(),
    });
    await PreferencesHelper.prefs.setString(_prefsKey, encoded);
    notifyListeners();
  }

  Future<void> resetAll() async {
    await save({
      for (final role in AppFontRole.values)
        role: AppFontChoice(fontSize: role.defaultSize),
    });
  }

  Future<void> _loadSelectedFamilies() {
    final families = _choices.values
        .map((choice) => choice.fontFamily)
        .where((family) => family.trim().isNotEmpty)
        .toSet();
    return loadKnownSystemFontsForDocument(families);
  }
}

class AppUiFonts {
  AppUiFonts._();

  static TextStyle style(
    AppFontRole role,
    TextStyle base, {
    double sizeOffset = 0,
    FontWeight? fontWeight,
  }) {
    final choice = AppFontSettings.instance.choice(role);
    return base.copyWith(
      fontFamily: choice.fontFamily.isEmpty ? base.fontFamily : choice.fontFamily,
      fontSize: (choice.fontSize + sizeOffset).clamp(6.0, 48.0).toDouble(),
      fontWeight: fontWeight ?? weightFor(choice.styleName) ?? base.fontWeight,
      fontStyle: fontStyleFor(choice.styleName) ?? base.fontStyle,
      height: choice.lineSpacing,
    );
  }

  static FontWeight? weightFor(String styleName) {
    final style = styleName.toLowerCase();
    if (style.contains('semi') || style.contains('light')) return FontWeight.w300;
    if (style.contains('bold')) return FontWeight.bold;
    if (style.contains('medium')) return FontWeight.w500;
    return FontWeight.normal;
  }

  static FontStyle? fontStyleFor(String styleName) {
    return styleName.toLowerCase().contains('italic') ? FontStyle.italic : null;
  }
}
