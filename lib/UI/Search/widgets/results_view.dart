import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/Search/helpers/search_highlighting_helper.dart';

/// Results view widget for search dialog — with optional preview callback
class SearchResultsView extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final Function(String, int) onResultTapped;
  final Function(Map<String, dynamic>)? onResultPreviewed;
  final Function() onClose;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final int? selectedIndex;

  const SearchResultsView({
    Key? key,
    required this.results,
    required this.totalCount,
    required this.onResultTapped,
    required this.onClose,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.onResultPreviewed,
    this.selectedIndex,
  }) : super(key: key);

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
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
  void didUpdateWidget(SearchResultsView oldWidget) {
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
      cleaned.length > 100 ? '${cleaned.substring(0, 100)}...' : cleaned,
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
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('النتائج: ${widget.results.length}', style: mediumStyle()),
              IconButton(
                icon: Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: widget.onClose,
                tooltip: 'إغلاق',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.results.length,
            itemBuilder: (context, index) {
              final result = widget.results[index];
              final content = result['content'] as String? ?? '';
              final bookName = result['book_name'] as String? ?? '';
              final bookPath = result['book_path'] as String? ?? '';
              final pageNumber = (result['page_number'] as num?)?.toInt() ?? 0;
              final isSelected = widget.selectedIndex == index;

              return Card(
                elevation: isSelected ? 2 : 1,
                color: isSelected ? primaryColor.withOpacity(0.08) : null,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: ListTile(
                  dense: true,
                  title: Text(
                    bookName,
                    style: normalStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: _buildSnippet(index, content),
                  ),
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ص ${pageNumber + 1}',
                        style: smallStyle(color: primaryColor),
                      ),
                    ],
                  ),
                  trailing: widget.onResultPreviewed != null
                      ? IconButton(
                          icon: Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: primaryColor,
                          ),
                          tooltip: 'فتح في تبويب',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () => widget.onResultTapped(
                            bookPath,
                            pageNumber,
                          ),
                        )
                      : null,
                  onTap: () {
                    if (widget.onResultPreviewed != null) {
                      widget.onResultPreviewed!(result);
                    } else {
                      widget.onResultTapped(bookPath, pageNumber);
                    }
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
