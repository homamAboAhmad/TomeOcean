import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';

class SearchHighlightSpanBuilder {
  SearchHighlightSpanBuilder._();

  static Widget build({
    required String snippet,
    required List<Map<String, dynamic>> matches,
    required Map<String, int> range,
    required int totalLen,
  }) {
    final spans = <InlineSpan>[];
    final searchWordColor = AppUiColors.color(AppColorRole.searchWords);

    if (range['start']! > 0) {
      spans.add(TextSpan(text: '... ', style: smallStyle(color: Colors.grey)));
    }

    if (snippet.isEmpty) {
      return RichText(text: TextSpan(children: spans));
    }

    matches.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    final highlightMask = List<bool>.filled(snippet.length, false);
    for (final match in matches) {
      final start = match['index'] as int;
      final length = match['length'] as int;
      for (int i = start; i < start + length && i < snippet.length; i++) {
        highlightMask[i] = true;
      }
    }

    int currentStart = 0;
    bool currentHighlight = highlightMask.isNotEmpty ? highlightMask[0] : false;

    for (int i = 1; i <= snippet.length; i++) {
      final isHighlight = i < snippet.length ? highlightMask[i] : !currentHighlight;

      if (i == snippet.length || isHighlight != currentHighlight) {
        spans.add(_span(snippet.substring(currentStart, i), currentHighlight, searchWordColor));
        currentStart = i;
        if (i < snippet.length) currentHighlight = highlightMask[i];
      }
    }

    if (range['end']! < totalLen) {
      spans.add(TextSpan(text: ' ...', style: smallStyle(color: Colors.grey)));
    }

    return RichText(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  static TextSpan _span(String text, bool highlighted, Color searchWordColor) {
    if (!highlighted) {
      return TextSpan(
        text: text,
        style: smallStyle(fontSize: 14, color: Colors.grey.shade800),
      );
    }
    return TextSpan(
      text: text,
      style: TextStyle(
        backgroundColor: const Color(0xFFFFF9C4),
        color: searchWordColor,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        fontFamily: 'jreg',
      ),
    );
  }
}
