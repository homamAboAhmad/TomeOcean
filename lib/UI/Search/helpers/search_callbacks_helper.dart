import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/Search/widgets/search_options_panel.dart';

/// Helper to create callbacks for search options panel
class SearchCallbacksHelper {
  static Function(String, bool) createAdvancedCallback({
    required Function(bool) setMorphological,
    required Function(bool) setAffix,
    required Function(bool) setHamzas,
    required Function(bool) setDiacritics,
    required Function(bool) setNumbers,
  }) {
    return (key, value) {
      switch (key) {
        case 'morphological': setMorphological(value); break;
        case 'affix': setAffix(value); break;
        case 'hamzas': setHamzas(value); break;
        case 'diacritics': setDiacritics(value); break;
        case 'numbers': setNumbers(value); break;
      }
    };
  }

  static Function(String, bool) createPhraseCallback({
    required Function(bool) setAllPhrases,
    required Function(bool) setOrdered,
    required Function(bool) setProximity,
  }) {
    return (key, value) {
      switch (key) {
        case 'allPhrasesRequired': setAllPhrases(value); break;
        case 'ordered': setOrdered(value); break;
        case 'proximity': setProximity(value); break;
      }
    };
  }
}

