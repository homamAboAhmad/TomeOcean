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
    
    // Get all words to highlight
    Set<String> wordsToHighlight = {};
    for (String query in searchQueries) {
      wordsToHighlight.add(query);
      if (!query.startsWith('ال')) {
        wordsToHighlight.add('ال$query');
      }
      if (morphologicalSearch) {
        wordsToHighlight.addAll(_getMorphologicalVariations(query));
      }
    }
    
    // Find ALL occurrences of words to highlight
    List<Map<String, dynamic>> matches = [];
    for (String word in wordsToHighlight) {
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
    
    // Also find morphological matches if enabled
    if (morphologicalSearch) {
      String queryRoot = searchQueries.isNotEmpty 
          ? await ArabicMorphologicalAnalyzer.stem(searchQueries.first)
          : '';
      if (queryRoot.isNotEmpty) {
        List<Map<String, dynamic>> arabicWords = _extractArabicWordsWithPositions(text);
        for (var wordInfo in arabicWords) {
          String word = wordInfo['word'] as String;
          String wordRoot = await ArabicMorphologicalAnalyzer.stem(word);
          if (wordRoot == queryRoot) {
            matches.add({
              'word': word,
              'index': wordInfo['start'] as int,
              'length': word.length,
            });
          }
        }
      }
    }
    
    // If no matches found, show first 100 chars
    if (matches.isEmpty) {
      String snippet = text.length > 100 ? '${text.substring(0, 100)}...' : text;
      return Text(snippet, style: smallStyle(), maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    
    // Sort matches by position
    matches.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    // Use the first match to extract snippet
    int firstMatchIndex = matches.first['index'] as int;
    int firstMatchLength = matches.first['length'] as int;
    
    // Extract context around the first match
    const int contextLength = 100;
    int start = (firstMatchIndex - contextLength).clamp(0, text.length);
    int end = (firstMatchIndex + firstMatchLength + contextLength).clamp(0, text.length);
    
    String snippet = text.substring(start, end);
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';
    
    // Adjust match positions relative to snippet
    List<Map<String, dynamic>> adjustedMatches = [];
    for (var match in matches) {
      int matchIndex = match['index'] as int;
      if (matchIndex >= start && matchIndex < end) {
        adjustedMatches.add({
          'word': match['word'],
          'index': matchIndex - start + (start > 0 ? 3 : 0),
          'length': match['length'],
        });
      }
    }
    
    return _buildHighlightedTextFromMatches(snippet, adjustedMatches, wordsToHighlight);
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

