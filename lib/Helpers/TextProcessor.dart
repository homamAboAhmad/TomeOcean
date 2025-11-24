import 'package:characters/characters.dart';

class TextProcessor {
  /// Normalizes Arabic text by removing diacritics and unifying Hamza forms.
  ///
  /// Converts:
  /// - Hamza variations (أ, إ, آ) to Alif (ا)
  /// - Waw with Hamza (ؤ) to Waw (و)
  /// - Ya with Hamza (ئ) to Ya (ي)
  /// - Ta Marbuta (ة) to Ha (ه)
  /// - Alif Maksura (ى) to Ya (ي)
  /// - Removes all diacritics (tashkeel)
  static String normalizeArabic(String text) {
    String normalized = text;

    // Unify Hamza forms
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ؤ', 'و');
    normalized = normalized.replaceAll('ئ', 'ي');

    // Unify Ta Marbuta and Alif Maksura
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');

    // Remove diacritics (tashkeel)
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');

    return normalized;
  }

  /// Performs light Arabic stemming by removing common prefixes and suffixes.
  /// This is a very basic stemmer and might not cover all morphological variations.
  static String lightStemArabic(String text) {
    String stemmed = text;

    // Remove common prefixes
    final prefixes = ['ال', 'و', 'ف', 'ب', 'ك', 'ل'];
    for (var prefix in prefixes) {
      if (stemmed.startsWith(prefix) && stemmed.length > prefix.length) {
        stemmed = stemmed.substring(prefix.length);
        break; // Remove only the first matching prefix
      }
    }

    // Remove common suffixes
    final suffixes = ['ون', 'ين', 'ات', 'ان', 'ة', 'ي', 'ك', 'ه', 'ها', 'هم', 'هن', 'نا'];
    for (var suffix in suffixes) {
      if (stemmed.endsWith(suffix) && stemmed.length > suffix.length) {
        stemmed = stemmed.substring(0, stemmed.length - suffix.length);
        break; // Remove only the first matching suffix
      }
    }

    return stemmed;
  }

  /// Removes diacritics (tashkeel) from Arabic text.
  static String removeDiacritics(String text) {
    return text.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
  }

  /// Unifies Hamza forms in Arabic text.
  /// Converts:
  /// - Hamza variations (أ, إ, آ) to Alif (ا)
  /// - Waw with Hamza (ؤ) to Waw (و)
  /// - Ya with Hamza (ئ) to Ya (ي)
  static String unifyHamzas(String text) {
    String unified = text;
    unified = unified.replaceAll(RegExp(r'[أإآ]'), 'ا');
    unified = unified.replaceAll('ؤ', 'و');
    unified = unified.replaceAll('ئ', 'ي');
    return unified;
  }
}
