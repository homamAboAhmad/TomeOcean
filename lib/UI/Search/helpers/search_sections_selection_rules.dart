class SearchSectionsSelectionRules {
  static void apply(Map<String, bool> sections, String key, bool value) {
    sections[key] = value;
    if (!value) return;
    if (key == 'title') {
      sections['main'] = false;
      sections['footnote'] = false;
      sections['comment'] = false;
      return;
    }
    if (key == 'main' || key == 'footnote' || key == 'comment') {
      sections['title'] = false;
    }
  }
}
