/// Provides functions for processing Arabic text for searching.
class TextProcessor {
  /// Normalizes Arabic text by removing diacritics and unifying characters.
  static String normalize(String text) {
    // Remove Tatweel and Fathatan, Kasratan, Dammatan, etc.
    text = text.replaceAll(RegExp(r'[\u0640\u064B-\u0652]'), '');
    // Replace Shadda with nothing
    text = text.replaceAll('\u0651', '');
    // Unify Hamzas and Alefs
    text = text.replaceAll(RegExp(r'[\u0622\u0623\u0625]'), '\u0627');
    // Unify Teh Marbuta with Heh
    text = text.replaceAll('\u0629', '\u0647');
    // Unify Yaa and Alef Maqsura
    text = text.replaceAll('\u0649', '\u064A');
    // Remove punctuation
    text = text.replaceAll(RegExp(r'[^\u0621-\u064A\s\d]'), '');
    // Replace multiple spaces with a single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  /// Performs light stemming on Arabic text.
  /// This is a basic implementation and can be expanded.
  static String stem(String text) {
    // First, normalize the text
    String normalized = normalize(text);
    List<String> words = normalized.split(' ');

    // Common prefixes to remove: "ال", "وال", "بال", "كال", "فال"
    final prefixes = ['ال', 'وال', 'بال', 'كال', 'فال'];
    // Common suffixes to remove: "ها", "هم", "ون", "ين", "ات", "ان"
    final suffixes = ['ها', 'هم', 'ون', 'ين', 'ات', 'ان'];

    List<String> stemmedWords = [];
    for (String word in words) {
      String currentWord = word;

      // Simple rule: only stem words longer than 3 characters
      if (currentWord.length > 3) {
        // Remove one prefix
        for (String p in prefixes) {
          if (currentWord.startsWith(p)) {
            currentWord = currentWord.substring(p.length);
            break; // Remove only one prefix
          }
        }
        // Remove one suffix
        for (String s in suffixes) {
          if (currentWord.endsWith(s)) {
            currentWord = currentWord.substring(0, currentWord.length - s.length);
            break; // Remove only one suffix
          }
        }
      }
      stemmedWords.add(currentWord);
    }

    return stemmedWords.join(' ');
  }
}
