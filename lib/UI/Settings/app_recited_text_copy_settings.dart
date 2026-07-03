import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:golden_shamela/FontsLoaderController.dart';
import 'package:golden_shamela/core/preferences_helper.dart';
import 'app_font_settings.dart';

class RecitedTextCopyDraft {
  final AppFontChoice referenceFont;
  final double complexFontSize;
  final double amiriFontSize;

  const RecitedTextCopyDraft({
    this.referenceFont = const AppFontChoice(
      fontFamily: 'Traditional Naskh',
      styleName: 'Bold',
      fontSize: 14,
    ),
    this.complexFontSize = 16,
    this.amiriFontSize = 14,
  });

  RecitedTextCopyDraft copyWith({
    AppFontChoice? referenceFont,
    double? complexFontSize,
    double? amiriFontSize,
  }) {
    return RecitedTextCopyDraft(
      referenceFont: referenceFont ?? this.referenceFont,
      complexFontSize: complexFontSize ?? this.complexFontSize,
      amiriFontSize: amiriFontSize ?? this.amiriFontSize,
    );
  }

  Map<String, Object> toJson() => {
        'referenceFont': referenceFont.toJson(),
        'complexFontSize': complexFontSize,
        'amiriFontSize': amiriFontSize,
      };

  factory RecitedTextCopyDraft.fromJson(Map<String, dynamic> json) {
    final reference = json['referenceFont'];
    return RecitedTextCopyDraft(
      referenceFont: reference is Map<String, dynamic>
          ? AppFontChoice.fromJson(reference, AppFontRole.bookLists)
          : const RecitedTextCopyDraft().referenceFont,
      complexFontSize: (json['complexFontSize'] as num?)?.toDouble() ?? 16,
      amiriFontSize: (json['amiriFontSize'] as num?)?.toDouble() ?? 14,
    );
  }
}

class RecitedTextCopySettings extends ChangeNotifier {
  static final RecitedTextCopySettings instance = RecitedTextCopySettings._();
  static const _prefsKey = 'recited_text_copy_settings_v1';

  RecitedTextCopyDraft _draft = const RecitedTextCopyDraft();

  RecitedTextCopySettings._();

  RecitedTextCopyDraft draft() => _draft;

  Future<void> load() async {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      await _loadSelectedFamily();
      return;
    }
    try {
      _draft = RecitedTextCopyDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _draft = const RecitedTextCopyDraft();
    }
    await _loadSelectedFamily();
  }

  Future<void> save(RecitedTextCopyDraft draft) async {
    _draft = draft;
    await _loadSelectedFamily();
    await PreferencesHelper.prefs.setString(_prefsKey, jsonEncode(draft.toJson()));
    notifyListeners();
  }

  Future<void> reset() => save(const RecitedTextCopyDraft());

  Future<void> _loadSelectedFamily() {
    final family = _draft.referenceFont.fontFamily.trim();
    return family.isEmpty ? Future.value() : loadKnownSystemFontsForDocument([family]);
  }
}
