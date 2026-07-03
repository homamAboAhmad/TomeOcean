import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';

class SearchResultHighlightText extends StatelessWidget {
  final String text;
  final List<String> queries;
  final TextStyle baseStyle;

  const SearchResultHighlightText({
    super.key,
    required this.text,
    required this.queries,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final terms = queries.map((q) => q.trim()).where((q) => q.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (terms.isEmpty || text.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: baseStyle,
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      text: TextSpan(children: _spans(terms)),
    );
  }

  List<InlineSpan> _spans(List<String> terms) {
    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    int index = 0;

    while (index < text.length) {
      final match = _nextMatch(lowerText, terms, index);
      if (match == null) {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: baseStyle.copyWith(
          color: AppUiColors.color(AppColorRole.searchWords),
          backgroundColor: AppUiColors.color(AppColorRole.searchHighlight),
          fontWeight: FontWeight.bold,
        ),
      ));
      index = match.end;
    }
    return spans;
  }

  _SearchMatch? _nextMatch(String lowerText, List<String> terms, int start) {
    _SearchMatch? best;
    for (final term in terms) {
      final index = lowerText.indexOf(term.toLowerCase(), start);
      if (index < 0) continue;
      final match = _SearchMatch(index, index + term.length);
      if (best == null || match.start < best.start) best = match;
    }
    return best;
  }
}

class _SearchMatch {
  final int start;
  final int end;

  const _SearchMatch(this.start, this.end);
}
