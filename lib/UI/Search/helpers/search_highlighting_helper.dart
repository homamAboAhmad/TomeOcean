import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Helpers/ArabicMorphologicalAnalyzer.dart';
import 'package:golden_shamela/Helpers/search_engine/text_normalization.dart';
import 'search_highlight_span_builder.dart';

/// Helper class for text highlighting in search results
///
/// Implements "Smart Context Cropping" and "Premium Highlighting"
class SearchHighlightingHelper {
  final bool morphologicalSearch;

  SearchHighlightingHelper({required this.morphologicalSearch});

  /// Extract a snippet around the search term with highlighting
  Future<Widget> extractSnippetWithHighlight(
    String text,
    List<String> searchQueries,
  ) async {
    if (text.isEmpty) return Text('', style: smallStyle());

    final wordsToHighlight = _collectWordsToHighlight(searchQueries);
    final matches = await _findAllMatches(text, wordsToHighlight);

    if (matches.isEmpty) {
      return _buildFallbackSnippet(text);
    }

    // Sort matches: Exact matches first, then by index
    matches.sort((a, b) {
      final aType = a['type'] as String? ?? 'root';
      final bType = b['type'] as String? ?? 'root';

      // Prioritize literal/exact matches over root matches for snippet selection
      if (aType == 'exact' && bType != 'exact') return -1;
      if (bType == 'exact' && aType != 'exact') return 1;

      // Then sort by position
      return (a['index'] as int).compareTo(b['index'] as int);
    });

    // Focus on the best match (first after sorting) for the snippet center
    final snippetRange = _calculateSmartSnippetRange(text, matches.first);
    final snippetText = text.substring(
      snippetRange['start']!,
      snippetRange['end']!,
    );

    // Re-sort matches purely by index for correct rendering order in RichText
    // We need a copy or re-sort because RichText expects sequential spans
    matches.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    // Adjust matches to be relative to the snippet
    final adjustedMatches = _adjustMatchPositions(
      matches,
      snippetRange,
      snippetText.length,
    );

    return _buildHighlightedRichText(
      snippetText,
      adjustedMatches,
      snippetRange,
      text.length,
    );
  }

  Set<String> _collectWordsToHighlight(List<String> searchQueries) {
    final wordsToHighlight = <String>{};
    for (final query in searchQueries) {
      if (query.trim().isEmpty) continue;
      wordsToHighlight.add(query.trim());
    }
    return wordsToHighlight;
  }

  Future<List<Map<String, dynamic>>> _findAllMatches(
    String text,
    Set<String> words,
  ) async {
    final matches = <Map<String, dynamic>>[];

    if (morphologicalSearch) {
      // For morphological search, stem the search queries first
      final searchRoots = <String, String>{}; // word -> root
      for (final word in words) {
        final root = await ArabicMorphologicalAnalyzer.stem(word);
        searchRoots[word] = root;
      }

      // Split text into words and find those with matching roots
      final wordPattern = RegExp(r'[\u0600-\u06FF]+');
      for (final match in wordPattern.allMatches(text)) {
        final textWord = match.group(0)!;
        final textWordRoot = await ArabicMorphologicalAnalyzer.stem(textWord);

        // Debug: specific check for things looking like 'غير'
        if (textWord.contains('غير')) {
          final entryKey = searchRoots.keys.firstWhere(
            (k) => k.contains('غير') || 'غير'.contains(k),
            orElse: () => 'unknown',
          );
          if (entryKey != 'unknown') {
            final normalizedWord = TextNormalization.normalizeText(textWord);
            print('DEBUG MATCH CHECK:');
            print('  Word: "$textWord"');
            print('  Normalized: "$normalizedWord"');
            print('  Root: "$textWordRoot"');
            print('  Target Root: "${searchRoots[entryKey]}"');
            print('  Contains "${entryKey}"? ${textWord.contains(entryKey)}');
            print(
              '  Normalized contains "${entryKey}"? ${normalizedWord.contains(entryKey)}',
            );
          }
        }

        // Check if any search query shares the same root
        // Also check fallback: if word contains the search query literally (for stemmer edge cases like "وغيرهما")
        for (final entry in searchRoots.entries) {
          final rootMatches = textWordRoot == entry.value;

          // Normalize textWord before contains check to handle diacritics
          // We normalize BOTH just to be safe, though entry.key (query) is likely already normalized
          final normalizedWord = TextNormalization.normalizeText(textWord);
          final wordContainsQuery = normalizedWord.contains(entry.key);

          if (rootMatches || wordContainsQuery) {
            matches.add({
              'word': entry.key,
              'index': match.start,
              'length': match.end - match.start,
              'type': 'root', // Morphological match
            });
            break; // Only add once per word
          }
        }
      }
    } else {
      // Standard matching: use regex pattern matching
      final sortedWords = words.toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      for (final word in sortedWords) {
        try {
          final pattern = _buildSmartArabicPattern(word);
          final regex = RegExp(pattern, caseSensitive: false);
          final regexMatches = regex.allMatches(text).toList();

          for (final match in regexMatches) {
            // Expand highlighting to the full word for better UX
            int start = match.start;
            int end = match.end;

            while (start > 0 && !_isWordBoundary(text, start - 1)) {
              start--;
            }
            while (end < text.length && !_isWordBoundary(text, end)) {
              end++;
            }

            matches.add({
              'word': word,
              'index': start,
              'length': end - start,
              'type': 'exact', // Standard/Exact match
            });
          }
        } catch (e) {
          // Silently handle regex errors
        }
      }
    }

    // Safe Fallback: Perform a literal regex search for ALL words to catch any missed matches
    // This addresses issues where the stemmer might miss a word, or normalization differences
    final existingIndices = matches.map((m) => m['index'] as int).toSet();

    for (final word in words) {
      if (word.length < 2) continue; // Skip very short words to avoid noise

      try {
        // Build a pattern that allows for some Arabic flexibility (hamzas, etc) but is mostly literal
        final pattern = _buildSmartArabicPattern(word);
        final regex = RegExp(
          pattern,
          caseSensitive: false,
        ); // 'u' flag not needed in Dart for Arabic usually

        for (final match in regex.allMatches(text)) {
          // If this range is not already covered by a morphological match
          bool alreadyCovered = false;
          for (int i = match.start; i < match.end; i++) {
            if (existingIndices.contains(i)) {
              alreadyCovered = true;
              break;
            }
          }

          if (!alreadyCovered) {
            // Expand highligh word boundaries for better UX
            int start = match.start;
            int end = match.end;

            while (start > 0 && !_isWordBoundary(text, start - 1)) {
              start--;
            }
            while (end < text.length && !_isWordBoundary(text, end)) {
              end++;
            }

            matches.add({
              'word': word,
              'index': start,
              'length': end - start,
              'type':
                  'exact', // Literal/Fallback match (Higher priority for snippet)
            });

            // Mark these indices as covered to prevent overlap
            for (int i = start; i < end; i++) existingIndices.add(i);
          }
        }
      } catch (e) {
        // Ignore regex errors
      }
    }

    return matches;
  }

  // Builds a regex that matches the word with optional diacritics/tatweel
  String _buildSmartArabicPattern(String term) {
    // Normalize to get base chars: Remove diacritics, Unify Hamzas
    final normalized = TextNormalization.normalizeText(
      term,
      removeDiacritics: true,
      unifyHamzas: true,
      removeNumbers: false,
    );

    final buffer = StringBuffer();
    for (int i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      // Handle permissive matching for unstable characters
      if ('اأإآ'.contains(char)) {
        buffer.write(r'[اأإآ]');
      } else if ('هة'.contains(char)) {
        buffer.write(r'[هة]');
      } else if ('يى'.contains(char)) {
        buffer.write(r'[يى]');
      } else {
        buffer.write(RegExp.escape(char));
      }
      // Allow optional diacritics/tatweel after each char
      buffer.write(r'[\u064B-\u065F\u0640]*');
    }
    return buffer.toString();
  }

  Map<String, int> _calculateSmartSnippetRange(
    String text,
    Map<String, dynamic> mainMatch,
  ) {
    const contextPadding = 70; // Characters before/after

    final matchIndex = mainMatch['index'] as int;
    final matchEnd = matchIndex + (mainMatch['length'] as int);

    int start = (matchIndex - contextPadding).clamp(0, text.length);
    int end = (matchEnd + contextPadding).clamp(0, text.length);

    // Expand to word boundaries
    while (start > 0 && !_isWordBoundary(text, start - 1)) {
      start--;
    }
    // Safety clamp (don't go back too far)
    if (matchIndex - start > contextPadding + 20)
      start = (matchIndex - contextPadding);

    while (end < text.length && !_isWordBoundary(text, end)) {
      end++;
    }
    // Safety clamp
    if (end - matchEnd > contextPadding + 20) end = (matchEnd + contextPadding);

    return {'start': start, 'end': end};
  }

  bool _isWordBoundary(String text, int index) {
    final char = text[index];
    return char == ' ' || char == '\n' || char == '\t' || _isPunctuation(char);
  }

  bool _isPunctuation(String char) {
    return RegExp(r'[.,;:"!?)(\[\]{}«»\-\—]').hasMatch(char);
  }

  List<Map<String, dynamic>> _adjustMatchPositions(
    List<Map<String, dynamic>> matches,
    Map<String, int> snippetRange,
    int snippetLength,
  ) {
    final adjusted = <Map<String, dynamic>>[];
    final startOffset = snippetRange['start']!;
    final endOffset = snippetRange['end']!;

    for (final match in matches) {
      final mIndex = match['index'] as int;
      final mLen = match['length'] as int;
      final mEnd = mIndex + mLen;

      // Check intersection
      if (mEnd > startOffset && mIndex < endOffset) {
        // Calculate relative positions
        final relStart = (mIndex - startOffset).clamp(0, snippetLength);
        final relEnd = (mEnd - startOffset).clamp(0, snippetLength);

        adjusted.add({'index': relStart, 'length': relEnd - relStart});
      }
    }
    return adjusted;
  }

  Widget _buildHighlightedRichText(
    String snippet,
    List<Map<String, dynamic>> matches,
    Map<String, int> range,
    int totalLen,
  ) {
    return SearchHighlightSpanBuilder.build(
      snippet: snippet,
      matches: matches,
      range: range,
      totalLen: totalLen,
    );
  }

  Widget _buildFallbackSnippet(String text) {
    final snippet = text.length > 150 ? '${text.substring(0, 150)}...' : text;
    return Text(snippet, style: smallStyle(color: Colors.grey.shade700));
  }
}
