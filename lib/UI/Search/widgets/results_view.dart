import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/widgets/search_results_table.dart';
import 'package:golden_shamela/core/app_state.dart';

/// Lightweight results list for search dialog.
///
/// Tapping a result opens the book directly; page previews are intentionally not
/// loaded here because building book pages from search rows can freeze large
/// result sets.
class SearchResultsView extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final Function(String, int) onResultTapped;
  final Function(Map<String, dynamic>)? onResultPreviewed;
  final Function() onClose;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final int? selectedIndex;

  const SearchResultsView({
    super.key,
    required this.results,
    required this.totalCount,
    required this.onResultTapped,
    required this.onClose,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.onResultPreviewed,
    this.selectedIndex,
  });

  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');
  static const double _rowExtent = 32;

  @override
  Widget build(BuildContext context) {
    final visibleTotal = totalCount > results.length ? totalCount : results.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: mutedColor,
            border: Border(bottom: AppChrome.borderSide()),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('النتائج: $visibleTotal', style: mediumStyle()),
              IconButton(
                icon: const LibraryIcon(LibraryIconType.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onClose,
                tooltip: 'إغلاق',
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const ShamelaResultsTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemExtent: _rowExtent,
                  cacheExtent: _rowExtent * 18,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final bookPath = result['book_path'] as String? ?? '';
                    final pageNumber =
                        (result['page_number'] as num?)?.toInt() ?? 0;
                    return ShamelaResultsTableRow(
                      serial: index + 1,
                      result: result,
                      snippetBuilder: _plainSnippet,
                      searchQueries: searchQueries,
                      onOpen: () {
                        AppState().openCommentPanelForSearchTarget =
                            result['section_type']?.toString() == 'comment';
                        onResultTapped(bookPath, pageNumber);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _plainSnippet(String content) {
    final cleaned = content
        .replaceAll(_pgMarkerRegex, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.length > 220 ? '${cleaned.substring(0, 220)}...' : cleaned;
  }
}
