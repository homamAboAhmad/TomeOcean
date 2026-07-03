import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

class AppOtherDraft {
  final bool showSearchAutocomplete;
  final bool openSearchResultOnKeyboardSelection;
  final bool showSearchBookIndexByDefault;
  final bool showSearchFieldNumbers;
  final int searchFieldCount;
  final bool rememberRecentBookPosition;
  final bool rememberFavoriteBookPosition;
  final bool rememberOtherBookPosition;
  final bool createDesktopShortcut;
  final bool createStartMenuShortcut;
  final bool restoreTabsOnStartup;
  final bool switchKeyboardToArabicOnStartup;
  final int maxTabTitleWords;

  const AppOtherDraft({
    this.showSearchAutocomplete = true,
    this.openSearchResultOnKeyboardSelection = false,
    this.showSearchBookIndexByDefault = true,
    this.showSearchFieldNumbers = true,
    this.searchFieldCount = 5,
    this.rememberRecentBookPosition = true,
    this.rememberFavoriteBookPosition = true,
    this.rememberOtherBookPosition = false,
    this.createDesktopShortcut = true,
    this.createStartMenuShortcut = true,
    this.restoreTabsOnStartup = true,
    this.switchKeyboardToArabicOnStartup = true,
    this.maxTabTitleWords = 5,
  });

  factory AppOtherDraft.defaults() => const AppOtherDraft();

  factory AppOtherDraft.fromJson(Map<String, dynamic> json) {
    return AppOtherDraft(
      showSearchAutocomplete: json['showSearchAutocomplete'] as bool? ?? true,
      openSearchResultOnKeyboardSelection:
          json['openSearchResultOnKeyboardSelection'] as bool? ?? false,
      showSearchBookIndexByDefault:
          json['showSearchBookIndexByDefault'] as bool? ?? true,
      showSearchFieldNumbers: json['showSearchFieldNumbers'] as bool? ?? true,
      searchFieldCount: _boundedInt(json['searchFieldCount'], 1, 20, 5),
      rememberRecentBookPosition:
          json['rememberRecentBookPosition'] as bool? ?? true,
      rememberFavoriteBookPosition:
          json['rememberFavoriteBookPosition'] as bool? ?? true,
      rememberOtherBookPosition:
          json['rememberOtherBookPosition'] as bool? ?? false,
      createDesktopShortcut: json['createDesktopShortcut'] as bool? ?? true,
      createStartMenuShortcut:
          json['createStartMenuShortcut'] as bool? ?? true,
      restoreTabsOnStartup: json['restoreTabsOnStartup'] as bool? ?? true,
      switchKeyboardToArabicOnStartup:
          json['switchKeyboardToArabicOnStartup'] as bool? ?? true,
      maxTabTitleWords: _boundedInt(json['maxTabTitleWords'], 1, 20, 5),
    );
  }

  AppOtherDraft copyWith({
    bool? showSearchAutocomplete,
    bool? openSearchResultOnKeyboardSelection,
    bool? showSearchBookIndexByDefault,
    bool? showSearchFieldNumbers,
    int? searchFieldCount,
    bool? rememberRecentBookPosition,
    bool? rememberFavoriteBookPosition,
    bool? rememberOtherBookPosition,
    bool? createDesktopShortcut,
    bool? createStartMenuShortcut,
    bool? restoreTabsOnStartup,
    bool? switchKeyboardToArabicOnStartup,
    int? maxTabTitleWords,
  }) {
    return AppOtherDraft(
      showSearchAutocomplete:
          showSearchAutocomplete ?? this.showSearchAutocomplete,
      openSearchResultOnKeyboardSelection:
          openSearchResultOnKeyboardSelection ??
              this.openSearchResultOnKeyboardSelection,
      showSearchBookIndexByDefault:
          showSearchBookIndexByDefault ?? this.showSearchBookIndexByDefault,
      showSearchFieldNumbers:
          showSearchFieldNumbers ?? this.showSearchFieldNumbers,
      searchFieldCount:
          (searchFieldCount ?? this.searchFieldCount).clamp(1, 20).toInt(),
      rememberRecentBookPosition:
          rememberRecentBookPosition ?? this.rememberRecentBookPosition,
      rememberFavoriteBookPosition:
          rememberFavoriteBookPosition ?? this.rememberFavoriteBookPosition,
      rememberOtherBookPosition:
          rememberOtherBookPosition ?? this.rememberOtherBookPosition,
      createDesktopShortcut:
          createDesktopShortcut ?? this.createDesktopShortcut,
      createStartMenuShortcut:
          createStartMenuShortcut ?? this.createStartMenuShortcut,
      restoreTabsOnStartup: restoreTabsOnStartup ?? this.restoreTabsOnStartup,
      switchKeyboardToArabicOnStartup:
          switchKeyboardToArabicOnStartup ??
              this.switchKeyboardToArabicOnStartup,
      maxTabTitleWords:
          (maxTabTitleWords ?? this.maxTabTitleWords).clamp(1, 20).toInt(),
    );
  }

  Map<String, Object> toJson() => {
        'showSearchAutocomplete': showSearchAutocomplete,
        'openSearchResultOnKeyboardSelection':
            openSearchResultOnKeyboardSelection,
        'showSearchBookIndexByDefault': showSearchBookIndexByDefault,
        'showSearchFieldNumbers': showSearchFieldNumbers,
        'searchFieldCount': searchFieldCount,
        'rememberRecentBookPosition': rememberRecentBookPosition,
        'rememberFavoriteBookPosition': rememberFavoriteBookPosition,
        'rememberOtherBookPosition': rememberOtherBookPosition,
        'createDesktopShortcut': createDesktopShortcut,
        'createStartMenuShortcut': createStartMenuShortcut,
        'restoreTabsOnStartup': restoreTabsOnStartup,
        'switchKeyboardToArabicOnStartup': switchKeyboardToArabicOnStartup,
        'maxTabTitleWords': maxTabTitleWords,
      };

  static int _boundedInt(dynamic value, int min, int max, int fallback) {
    final number = value is num ? value.toInt() : fallback;
    return number.clamp(min, max).toInt();
  }
}

class AppOtherSettings extends ChangeNotifier {
  static final AppOtherSettings instance = AppOtherSettings._();
  static const _prefsKey = 'app_other_settings_v1';

  AppOtherDraft _settings = AppOtherDraft.defaults();

  AppOtherSettings._();

  AppOtherDraft draft() => _settings;

  Future<void> load() async {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      _settings = AppOtherDraft.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _settings = AppOtherDraft.defaults();
    }
  }

  Future<void> save(AppOtherDraft settings) async {
    _settings = settings;
    await PreferencesHelper.prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
    notifyListeners();
  }
}
