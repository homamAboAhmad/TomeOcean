import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/Search/helpers/search_highlighting_helper.dart';

/// Results view widget for search dialog
class SearchResultsView extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final Function(String, int) onResultTapped;
  final Function() onClose;
  final List<String> searchQueries;
  final bool morphologicalSearch;

  const SearchResultsView({
    Key? key,
    required this.results,
    required this.totalCount,
    required this.onResultTapped,
    required this.onClose,
    required this.searchQueries,
    required this.morphologicalSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final highlightingHelper = SearchHighlightingHelper(
      morphologicalSearch: morphologicalSearch,
    );

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('النتائج: $totalCount', style: mediumStyle()),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'إغلاق',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final content = result['content'] as String? ?? '';
              final morphContent =
                  result['morphological_content'] as String? ?? '';

              // Debug: Log result keys and morphological content for first 3 results
              if (index < 3) {
                print('===== [ResultsView] Result #$index =====');
                print('  Keys: ${result.keys.toList()}');
                print(
                  '  morphological_content is null: ${result['morphological_content'] == null}',
                );
                if (morphContent.isNotEmpty) {
                  final morphPreview = morphContent.length > 200
                      ? morphContent.substring(0, 200)
                      : morphContent;
                  print('  morphological_content: "$morphPreview..."');
                } else {
                  print('  morphological_content is EMPTY');
                }
              }

              return Card(
                elevation: 1,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    result['book_name'] as String,
                    style: normalStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: FutureBuilder<Widget>(
                      future: highlightingHelper.extractSnippetWithHighlight(
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
                    'ص ${(result['page_number'] as int? ?? 0) + 1}',
                    style: normalStyle(color: primaryColor),
                  ),
                  onTap: () {
                    onResultTapped(
                      result['book_path'] as String,
                      result['page_number'] as int,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
