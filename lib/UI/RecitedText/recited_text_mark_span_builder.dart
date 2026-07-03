import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const String recitedMarkFallbackFamily = 'recited_mark_fallback';

const int _roundedZeroMark = 0x06DF;

List<InlineSpan> buildRecitedTextSpans({
  required String text,
  required TextStyle style,
  required bool useMarkFallback,
  GestureRecognizer? recognizer,
}) {
  if (!useMarkFallback || !text.runes.contains(_roundedZeroMark)) {
    return [TextSpan(text: text, style: style, recognizer: recognizer)];
  }

  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune == _roundedZeroMark) {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: style, recognizer: recognizer));
        buffer.clear();
      }
      spans.add(TextSpan(
        text: String.fromCharCode(rune),
        style: style.copyWith(fontFamily: recitedMarkFallbackFamily),
        recognizer: recognizer,
      ));
    } else {
      buffer.writeCharCode(rune);
    }
  }
  if (buffer.isNotEmpty) {
    spans.add(TextSpan(text: buffer.toString(), style: style, recognizer: recognizer));
  }
  return spans;
}
