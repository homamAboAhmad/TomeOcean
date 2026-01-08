import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/Search/helpers/search_highlighting_helper.dart';
import 'package:golden_shamela/UI/Search/widgets/no_results_widget.dart';

/// Widget to display search results in a tab
class SearchResultsTabViewer extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final Function(String, int) onResultTapped;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final VoidCallback? onNewSearch;

  const SearchResultsTabViewer({
    Key? key,
    required this.results,
    required this.totalCount,
    required this.onResultTapped,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.onNewSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final highlightingHelper = SearchHighlightingHelper(
      morphologicalSearch: morphologicalSearch,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            // Header with total count
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'النتائج: $totalCount',
                    style: mediumStyle(fontSize: 18),
                  ),
                  if (searchQueries.isNotEmpty)
                    Text(
                      'البحث عن: ${searchQueries.join(" | ")}',
                      style: smallStyle(color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
            // Results list or No Results widget
            Expanded(
              child: results.isEmpty
                  ? NoResultsWidget(
                      searchQueries: searchQueries,
                      onNewSearch: onNewSearch,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        // Safely convert result to Map<String, dynamic>
                        final resultMap = Map<String, dynamic>.from(
                          results[index],
                        );
                        final content = resultMap['content'] as String? ?? '';
                        final bookName =
                            resultMap['book_name'] as String? ?? '';
                        final bookPath =
                            resultMap['book_path'] as String? ?? '';
                        final pageNumber =
                            (resultMap['page_number'] as num?)?.toInt() ?? 0;

                        return Card(
                          elevation: 1,
                          margin: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Text(
                              bookName,
                              style: normalStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: FutureBuilder<Widget>(
                                future: highlightingHelper
                                    .extractSnippetWithHighlight(
                                      content,
                                      searchQueries,
                                    ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return snapshot.data!;
                                  } else if (snapshot.hasError) {
                                    return Text(
                                      content.length > 100
                                          ? '${content.substring(0, 100)}...'
                                          : content,
                                      style: smallStyle(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  } else {
                                    return Text(
                                      content.length > 100
                                          ? '${content.substring(0, 100)}...'
                                          : content,
                                      style: smallStyle(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }
                                },
                              ),
                            ),
                            leading: Text(
                              'ص ${pageNumber + 1}',
                              style: normalStyle(color: primaryColor),
                            ),
                            onTap: () {
                              onResultTapped(bookPath, pageNumber);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
