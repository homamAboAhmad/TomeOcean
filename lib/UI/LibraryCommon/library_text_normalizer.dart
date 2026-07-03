class LibraryTextNormalizer {
  static final RegExp _tashkeel = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );
  static final RegExp _alefVariants = RegExp(r'[إأآٱ]');

  static String normalize(String value) {
    return value
        .trim()
        .replaceAll(_tashkeel, '')
        .replaceAll('\u0640', '')
        .replaceAll(_alefVariants, 'ا')
        .replaceAll('ى', 'ي')
        .toLowerCase();
  }

  static bool contains(String source, String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return true;
    return normalize(source).contains(normalizedQuery);
  }
}
