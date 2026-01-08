/// Text normalization utilities for Arabic text processing
class TextNormalization {
  /// Extract Arabic words from text
  static List<String> extractArabicWords(String text) {
    RegExp arabicWordRegex = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]+',
    );
    return arabicWordRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Check if a string contains Arabic diacritics
  static bool hasDiacritics(String text) {
    return RegExp(r'[\u064B-\u0652]').hasMatch(text);
  }

  /// Normalize text based on options
  static String normalizeText(
    String text, {
    bool removeDiacritics = true,
    bool unifyHamzas = true,
    bool removeNumbers = false,
  }) {
    String normalized = text;

    if (removeDiacritics) {
      normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    }

    if (unifyHamzas) {
      normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
      normalized = normalized.replaceAll('ؤ', 'و');
      normalized = normalized.replaceAll('ئ', 'ي');
    }

    if (removeNumbers) {
      // Remove Arabic and Western digits
      normalized = normalized.replaceAll(RegExp(r'[0-9\u0660-\u0669]'), ' ');
      // Clean up extra spaces resulting from removal
      normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    }

    return normalized;
  }
}
