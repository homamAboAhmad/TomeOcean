import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/Search/helpers/search_highlighting_helper.dart';
import 'package:golden_shamela/UI/Search/widgets/no_results_widget.dart';

/// Widget to display search results in a tab
class SearchResultsTabViewer extends StatefulWidget {
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
  State<SearchResultsTabViewer> createState() => _SearchResultsTabViewerState();
}

class _SearchResultsTabViewerState extends State<SearchResultsTabViewer> {
  late SearchHighlightingHelper _highlightingHelper;
  final Map<int, Widget> _snippetCache = {};

  @override
  void initState() {
    super.initState();
    _highlightingHelper = SearchHighlightingHelper(
      morphologicalSearch: widget.morphologicalSearch,
    );
  }

  @override
  void didUpdateWidget(SearchResultsTabViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQueries != widget.searchQueries ||
        oldWidget.morphologicalSearch != widget.morphologicalSearch) {
      _snippetCache.clear();
      _highlightingHelper = SearchHighlightingHelper(
        morphologicalSearch: widget.morphologicalSearch,
      );
    }
  }

  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');

  Widget _buildSnippet(int index, String content) {
    if (_snippetCache.containsKey(index)) return _snippetCache[index]!;

    final cleaned = content.replaceAll(_pgMarkerRegex, '');
    final fallback = Text(
      cleaned.length > 120 ? '${cleaned.substring(0, 120)}...' : cleaned,
      style: smallStyle(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return FutureBuilder<Widget>(
      future: _highlightingHelper.extractSnippetWithHighlight(
        cleaned,
        widget.searchQueries,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _snippetCache[index] = snapshot.data!;
          return snapshot.data!;
        }
        return fallback;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
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
                    'النتائج: ${widget.results.length}',
                    style: mediumStyle(fontSize: 18),
                  ),
                  if (widget.searchQueries.isNotEmpty)
                    Text(
                      'البحث عن: ${widget.searchQueries.join(" | ")}',
                      style: smallStyle(color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
            Expanded(
              child: widget.results.isEmpty
                  ? NoResultsWidget(
                      searchQueries: widget.searchQueries,
                      onNewSearch: widget.onNewSearch,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: widget.results.length,
                      itemBuilder: (context, index) {
                        final resultMap = Map<String, dynamic>.from(
                          widget.results[index],
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
                              child: _buildSnippet(index, content),
                            ),
                            leading: Text(
                              'ص ${pageNumber + 1}',
                              style: normalStyle(color: primaryColor),
                            ),
                            onTap: () {
                              widget.onResultTapped(bookPath, pageNumber);
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
