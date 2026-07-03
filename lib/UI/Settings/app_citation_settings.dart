import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:golden_shamela/core/preferences_helper.dart';

class AppCitationDraft {
  final bool quoteSource;
  final bool wrapPageRef;
  final bool wrapFullCitation;
  final bool placeBeforeText;
  final bool citationOnSeparateLine;
  final bool quoteCopiedText;
  final bool removeDiacritics;
  final bool removeFootnoteNumbers;

  const AppCitationDraft({
    this.quoteSource = true,
    this.wrapPageRef = true,
    this.wrapFullCitation = false,
    this.placeBeforeText = true,
    this.citationOnSeparateLine = true,
    this.quoteCopiedText = true,
    this.removeDiacritics = false,
    this.removeFootnoteNumbers = true,
  });

  AppCitationDraft copyWith({
    bool? quoteSource,
    bool? wrapPageRef,
    bool? wrapFullCitation,
    bool? placeBeforeText,
    bool? citationOnSeparateLine,
    bool? quoteCopiedText,
    bool? removeDiacritics,
    bool? removeFootnoteNumbers,
  }) {
    return AppCitationDraft(
      quoteSource: quoteSource ?? this.quoteSource,
      wrapPageRef: wrapPageRef ?? this.wrapPageRef,
      wrapFullCitation: wrapFullCitation ?? this.wrapFullCitation,
      placeBeforeText: placeBeforeText ?? this.placeBeforeText,
      citationOnSeparateLine:
          citationOnSeparateLine ?? this.citationOnSeparateLine,
      quoteCopiedText: quoteCopiedText ?? this.quoteCopiedText,
      removeDiacritics: removeDiacritics ?? this.removeDiacritics,
      removeFootnoteNumbers:
          removeFootnoteNumbers ?? this.removeFootnoteNumbers,
    );
  }

  Map<String, Object> toJson() => {
        'quoteSource': quoteSource,
        'wrapPageRef': wrapPageRef,
        'wrapFullCitation': wrapFullCitation,
        'placeBeforeText': placeBeforeText,
        'citationOnSeparateLine': citationOnSeparateLine,
        'quoteCopiedText': quoteCopiedText,
        'removeDiacritics': removeDiacritics,
        'removeFootnoteNumbers': removeFootnoteNumbers,
      };

  factory AppCitationDraft.fromJson(Map<String, dynamic> json) {
    return AppCitationDraft(
      quoteSource: json['quoteSource'] as bool? ?? true,
      wrapPageRef: json['wrapPageRef'] as bool? ?? true,
      wrapFullCitation: json['wrapFullCitation'] as bool? ?? false,
      placeBeforeText: json['placeBeforeText'] as bool? ?? true,
      citationOnSeparateLine:
          json['citationOnSeparateLine'] as bool? ?? true,
      quoteCopiedText: json['quoteCopiedText'] as bool? ?? true,
      removeDiacritics: json['removeDiacritics'] as bool? ?? false,
      removeFootnoteNumbers:
          json['removeFootnoteNumbers'] as bool? ?? true,
    );
  }
}

class AppCitationSettings extends ChangeNotifier {
  static final AppCitationSettings instance = AppCitationSettings._();
  static const _prefsKey = 'app_citation_settings_v1';

  AppCitationDraft _draft = const AppCitationDraft();

  AppCitationSettings._();

  AppCitationDraft draft() => _draft;

  Future<void> load() async {
    final raw = PreferencesHelper.prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      _draft = AppCitationDraft.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _draft = const AppCitationDraft();
    }
  }

  Future<void> save(AppCitationDraft draft) async {
    _draft = draft;
    await PreferencesHelper.prefs.setString(_prefsKey, jsonEncode(draft));
    notifyListeners();
  }

  Future<void> reset() => save(const AppCitationDraft());
}

class CitationFormatter {
  CitationFormatter._();

  static String format({
    required String text,
    required String bookTitle,
    required int pageNumber,
    AppCitationDraft? settings,
  }) {
    final options = settings ?? AppCitationSettings.instance.draft();
    final copiedText = formatCopiedText(text, settings: options);
    final citation = _formatCitation(bookTitle, pageNumber, options);
    final separator = options.citationOnSeparateLine ? '\n' : ' ';

    if (options.placeBeforeText) {
      return '$citation$separator$copiedText';
    }
    return '$copiedText$separator$citation';
  }

  static String formatCopiedText(String text, {AppCitationDraft? settings}) {
    final options = settings ?? AppCitationSettings.instance.draft();
    var result = text.trim();
    if (options.removeDiacritics) {
      result = result.replaceAll(
        RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
        '',
      );
    }
    if (options.removeFootnoteNumbers) {
      result = result
          .replaceAll(RegExp(r'[\u00B9\u00B2\u00B3\u2070-\u2079]'), '')
          .replaceAll(RegExp(r'[\(\[]\s*[\d\u0660-\u0669]+\s*[\)\]]'), '');
    }
    return options.quoteCopiedText ? '«$result»' : result;
  }

  static String _formatCitation(
    String bookTitle,
    int pageNumber,
    AppCitationDraft options,
  ) {
    final source = options.quoteSource ? '«$bookTitle»' : bookTitle;
    final page = options.wrapPageRef ? '(ص $pageNumber)' : 'ص $pageNumber';
    final citation = '$source $page';
    return options.wrapFullCitation ? '[$citation]' : citation;
  }
}
