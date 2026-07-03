import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Search/widgets/no_results_widget.dart';
import 'package:golden_shamela/UI/Search/widgets/search_results_table.dart';
import 'package:golden_shamela/core/app_state.dart';

/// Lightweight widget to display search results in a tab.
class SearchResultsTabViewer extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final Function(String, int) onResultTapped;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final VoidCallback? onNewSearch;

  const SearchResultsTabViewer({
    super.key,
    required this.results,
    required this.totalCount,
    required this.onResultTapped,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.onNewSearch,
  });

  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');
  static const double _rowExtent = 32;

  @override
  Widget build(BuildContext context) {
    final visibleTotal = totalCount > results.length ? totalCount : results.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'النتائج: $visibleTotal',
                    style: mediumStyle(fontSize: 18),
                  ),
                  if (searchQueries.isNotEmpty)
                    Flexible(
                      child: Text(
                        'البحث عن: ${searchQueries.join(" | ")}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: smallStyle(color: Colors.grey.shade700),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? NoResultsWidget(searchQueries: searchQueries, onNewSearch: onNewSearch)
                  : Column(
                      children: [
                        const ShamelaResultsTableHeader(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: results.length,
                            itemExtent: _rowExtent,
                            cacheExtent: _rowExtent * 18,
                            itemBuilder: (context, index) {
                              final resultMap = results[index];
                              final bookPath =
                                  resultMap['book_path'] as String? ?? '';
                              final pageNumber =
                                  (resultMap['page_number'] as num?)?.toInt() ?? 0;
                              return ShamelaResultsTableRow(
                                serial: index + 1,
                                result: resultMap,
                                snippetBuilder: _plainSnippet,
                                searchQueries: searchQueries,
                                onOpen: () {
                                  AppState().openCommentPanelForSearchTarget =
                                      resultMap['section_type']?.toString() ==
                                          'comment';
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
        ),
      ),
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
