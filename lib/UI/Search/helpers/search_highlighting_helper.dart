import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Helpers/ArabicMorphologicalAnalyzer.dart';

/// Helper class for text highlighting in search results
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
    final matches = await _findAllMatches(text, searchQueries, wordsToHighlight);
    
    if (matches.isEmpty) {
      final snippet = text.length > 100 ? '${text.substring(0, 100)}...' : text;
      return Text(snippet, style: smallStyle(), maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    
    matches.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    final snippetRange = _calculateSnippetRange(text, matches.first);
    final snippet = _extractSnippet(text, snippetRange);
    final adjustedMatches = _adjustMatchPositions(matches, snippetRange, snippet.length);
    
    return _buildHighlightedTextFromMatches(snippet, adjustedMatches, wordsToHighlight);
  }

  /// Collect all words that should be highlighted
  Set<String> _collectWordsToHighlight(List<String> searchQueries) {
    final wordsToHighlight = <String>{};
    for (final query in searchQueries) {
      wordsToHighlight.add(query);
      if (!query.startsWith('ال')) {
        wordsToHighlight.add('ال$query');
      }
      if (morphologicalSearch) {
        wordsToHighlight.addAll(_getMorphologicalVariations(query));
      }
    }
    return wordsToHighlight;
  }

  /// Find all matches in the text
  Future<List<Map<String, dynamic>>> _findAllMatches(
    String text,
    List<String> searchQueries,
    Set<String> wordsToHighlight,
  ) async {
    final matches = <Map<String, dynamic>>[];
    
    for (final word in wordsToHighlight) {
      int index = 0;
      while (true) {
        index = _findWordInTextFromPosition(text, word, index);
        if (index == -1) break;
        matches.add({
          'word': word,
          'index': index,
          'length': word.length,
        });
        index += word.length;
      }
    }
    
    if (morphologicalSearch) {
      matches.addAll(await _findMorphologicalMatches(text, searchQueries));
    }
    
    return matches;
  }

  /// Find morphological matches in the text
  Future<List<Map<String, dynamic>>> _findMorphologicalMatches(
    String text,
    List<String> searchQueries,
  ) async {
    final matches = <Map<String, dynamic>>[];
    
    if (searchQueries.isEmpty) return matches;
    
    final queryRoot = await ArabicMorphologicalAnalyzer.stem(searchQueries.first);
    if (queryRoot.isEmpty) return matches;
    
    final arabicWords = _extractArabicWordsWithPositions(text);
    for (final wordInfo in arabicWords) {
      final word = wordInfo['word'] as String;
      final wordRoot = await ArabicMorphologicalAnalyzer.stem(word);
      if (wordRoot == queryRoot) {
        matches.add({
          'word': word,
          'index': wordInfo['start'] as int,
          'length': word.length,
        });
      }
    }
    
    return matches;
  }

  /// Calculate the snippet range around the first match
  Map<String, int> _calculateSnippetRange(
    String text,
    Map<String, dynamic> firstMatch,
  ) {
    const contextLength = 100;
    const maxSnippetLength = 250;
    
    final firstMatchIndex = firstMatch['index'] as int;
    final firstMatchLength = firstMatch['length'] as int;
    
    int start = (firstMatchIndex - contextLength).clamp(0, text.length);
    if (firstMatchIndex < contextLength) {
      start = 0;
    }
    
    int end = (firstMatchIndex + firstMatchLength + contextLength).clamp(0, text.length);
    
    if (firstMatchIndex + firstMatchLength + contextLength > text.length) {
      final availableSpace = maxSnippetLength - (end - start);
      if (availableSpace > 0) {
        start = (start - availableSpace).clamp(0, text.length);
      }
    }
    
    if (end - start > maxSnippetLength) {
      final matchCenter = firstMatchIndex + (firstMatchLength ~/ 2);
      start = (matchCenter - maxSnippetLength ~/ 2).clamp(0, text.length);
      end = (start + maxSnippetLength).clamp(0, text.length);
    }
    
    if (firstMatchIndex < start) {
      start = firstMatchIndex;
    }
    if (firstMatchIndex + firstMatchLength > end) {
      end = firstMatchIndex + firstMatchLength;
    }
    
    return {'start': start, 'end': end};
  }

  /// Extract snippet text with ellipsis
  String _extractSnippet(String text, Map<String, int> range) {
    final start = range['start']!;
    final end = range['end']!;
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    return snippet;
  }

  /// Adjust match positions relative to snippet
  List<Map<String, dynamic>> _adjustMatchPositions(
    List<Map<String, dynamic>> matches,
    Map<String, int> snippetRange,
    int snippetLength,
  ) {
    final adjustedMatches = <Map<String, dynamic>>[];
    final start = snippetRange['start']!;
    final end = snippetRange['end']!;
    
    for (final match in matches) {
      final matchIndex = match['index'] as int;
      final matchLength = match['length'] as int;
      final matchEnd = matchIndex + matchLength;
      
      if (matchIndex < end && matchEnd > start) {
        int adjustedIndex = matchIndex - start;
        if (matchIndex < start) {
          adjustedIndex = 0;
        }
        if (start > 0) adjustedIndex += 3;
        
        int adjustedEnd = (matchEnd - start).clamp(0, snippetLength);
        if (matchIndex < start) {
          adjustedEnd = (matchLength - (start - matchIndex)).clamp(0, snippetLength);
        }
        
        adjustedMatches.add({
          'word': match['word'],
          'index': adjustedIndex.clamp(0, snippetLength),
          'length': (adjustedEnd - adjustedIndex).clamp(0, snippetLength - adjustedIndex),
        });
      }
    }
    
    return adjustedMatches;
  }

  /// Build highlighted text widget from pre-calculated matches
  Widget _buildHighlightedTextFromMatches(
    String text,
    List<Map<String, dynamic>> matches,
    Set<String> wordsToHighlight,
  ) {
    List<TextSpan> spans = [];
    matches.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    int lastEnd = 0;
    for (var match in matches) {
      int matchIndex = match['index'] as int;
      int matchLength = match['length'] as int;
      
      if (matchIndex < 0 || matchIndex >= text.length) continue;
      int actualEnd = (matchIndex + matchLength).clamp(0, text.length);
      matchIndex = matchIndex.clamp(0, text.length);
      
      if (matchIndex > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, matchIndex),
          style: smallStyle(),
        ));
      }
      
      spans.add(TextSpan(
        text: text.substring(matchIndex, actualEnd),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.red.shade700,
          backgroundColor: Colors.yellow.withOpacity(0.4),
        ),
      ));
      
      lastEnd = actualEnd;
    }
    
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: smallStyle(),
      ));
    }
    
    if (spans.isEmpty) {
      return Text(text, style: smallStyle(), maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.rtl,
    );
  }

  int _findWordInTextFromPosition(String text, String word, int fromIndex) {
    if (fromIndex >= text.length) return -1;
    
    int index = text.indexOf(word, fromIndex);
    if (index != -1) {
      if (_isWordBoundary(text, index, word.length)) {
        return index;
      }
      return _findWordInTextFromPosition(text, word, index + 1);
    }
    
    if (!word.startsWith('ال')) {
      String alWord = 'ال$word';
      int alIndex = text.indexOf(alWord, fromIndex);
      if (alIndex != -1) {
        if (_isWordBoundary(text, alIndex, alWord.length)) {
          return alIndex;
        }
        return _findWordInTextFromPosition(text, word, alIndex + 1);
      }
    }
    
    return -1;
  }

  bool _isWordBoundary(String text, int index, int length) {
    if (index > 0) {
      String before = text[index - 1];
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(before)) {
        return false;
      }
    }
    
    if (index + length < text.length) {
      String after = text[index + length];
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(after)) {
        return false;
      }
    }
    
    return true;
  }

  Set<String> _getMorphologicalVariations(String word) {
    Set<String> variations = {};
    variations.add(word);
    
    if (!word.startsWith('ال')) {
      variations.add('ال$word');
    }
    
    try {
      List<String> morphVariations = ArabicMorphologicalAnalyzer.generateMorphologicalVariations(word);
      variations.addAll(morphVariations);
      
      for (String variation in morphVariations) {
        if (!variation.startsWith('ال')) {
          variations.add('ال$variation');
        }
      }
    } catch (e) {
      // Fallback: just use the word itself
    }
    
    return variations;
  }

  List<Map<String, dynamic>> _extractArabicWordsWithPositions(String text) {
    List<Map<String, dynamic>> words = [];
    RegExp arabicWordRegex = RegExp(r'[\u0600-\u06FF]+');
    
    for (Match match in arabicWordRegex.allMatches(text)) {
      words.add({
        'word': match.group(0)!,
        'start': match.start,
        'end': match.end,
      });
    }
    
    return words;
  }
}

