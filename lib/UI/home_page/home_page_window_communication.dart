import 'dart:async';
import 'dart:io';
import 'package:desktop_multi_window/src/window_channel.dart';

/// Window communication handler for HomePage
class HomePageWindowCommunication {
  final Function(String, int) onBookSelected;
  final Function(Map<String, dynamic>, String, List<Map<String, dynamic>>,
      Map<String, bool>, bool, bool, bool, bool, bool, bool, bool, bool,
      List<Map<String, dynamic>>) onPerformSearch;
  final Function(List<Map<String, dynamic>>, int, List<String>, bool)
      onSearchResults;
  final bool Function() isMounted;

  HomePageWindowCommunication({
    required this.onBookSelected,
    required this.onPerformSearch,
    required this.onSearchResults,
    required this.isMounted,
  });

  /// Setup window communication channel
  Future<void> setup() async {
    try {
      const channel = WindowMethodChannel(
        'golden_shamela/main_window',
        mode: ChannelMode.unidirectional,
      );

      await channel.setMethodCallHandler((call) async {
        if (call.method == 'openBook') {
          if (call.arguments is! Map) return;

          final args = Map<String, dynamic>.from(call.arguments as Map);
          final bookPath = args['bookPath'] as String;
          final pageNumber = args['pageNumber'] as int;

          if (isMounted()) {
            scheduleMicrotask(() {
              if (isMounted()) {
                onBookSelected(bookPath, pageNumber);
              }
            });
          }
        } else if (call.method == 'performSearch') {
          final args = Map<dynamic, dynamic>.from(
            call.arguments as Map<dynamic, dynamic>,
          );

          final groupControllersMap = Map<String, dynamic>.from(
            args['groupControllers'] as Map<dynamic, dynamic>,
          );

          final searchGrouping = args['searchGrouping'] as String? ?? 'all';
          final selectedBooksForSearch = (args['selectedBooksForSearch'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
                  .toList() ??
              [];
          final searchSections = Map<String, bool>.from(
            args['searchSections'] as Map? ?? {},
          );

          final morphologicalSearch = args['morphologicalSearch'] as bool? ?? false;
          final affixSearch = args['affixSearch'] as bool? ?? false;
          final considerHamzas = args['considerHamzas'] as bool? ?? false;
          final considerDiacritics = args['considerDiacritics'] as bool? ?? false;
          final considerNumbers = args['considerNumbers'] as bool? ?? true;
          final allPhrasesRequired = args['allPhrasesRequired'] as bool? ?? false;
          final ordered = args['ordered'] as bool? ?? false;
          final proximity = args['proximity'] as bool? ?? false;
          final indexedBooks = (args['indexedBooks'] as List<dynamic>?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
                  .toList() ??
              [];

          if (isMounted()) {
            onPerformSearch(
              groupControllersMap,
              searchGrouping,
              selectedBooksForSearch,
              searchSections,
              morphologicalSearch,
              affixSearch,
              considerHamzas,
              considerDiacritics,
              considerNumbers,
              allPhrasesRequired,
              ordered,
              proximity,
              indexedBooks,
            );
          }
        } else if (call.method == 'sendSearchResults') {
          if (call.arguments is! Map) return;

          final args = Map<String, dynamic>.from(call.arguments as Map);
          final results = args['results'] as List<dynamic>;
          final totalCount = args['totalCount'] as int;
          final searchQueries =
              (args['searchQueries'] as List<dynamic>?)?.cast<String>() ?? [];
          final morphologicalSearch = args['morphologicalSearch'] as bool? ?? false;

          if (isMounted()) {
            scheduleMicrotask(() {
              if (isMounted()) {
                final convertedResults = results.map((r) {
                  if (r is Map) {
                    return Map<String, dynamic>.from(r);
                  } else {
                    return Map<String, dynamic>.from(
                      r as Map<Object?, Object?>,
                    );
                  }
                }).toList();

                onSearchResults(convertedResults, totalCount, searchQueries,
                    morphologicalSearch);
              }
            });
          }
        }
      });
    } catch (e, stackTrace) {
      // Error handling for window communication setup
    }
  }
}

