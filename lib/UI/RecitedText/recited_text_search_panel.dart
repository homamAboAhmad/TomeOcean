import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/LibraryCommon/grouped_search_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_repository.dart';

class RecitedTextSearchPanel extends StatelessWidget {
  final GroupedSearchController? controller;
  final RecitedTextRepository repository;
  final RecitedTextSnapshot snapshot;
  final ValueChanged<RecitedTextSearchResult> onResultSelected;

  const RecitedTextSearchPanel({
    super.key,
    this.controller,
    required this.repository,
    required this.snapshot,
    required this.onResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GroupedSearchPanel<RecitedTextSearchResult>(
      controller: controller,
      onSearch: (request) {
        return repository.search(snapshot: snapshot, request: request);
      },
      onResultSelected: onResultSelected,
      resultsBuilder: _resultsPane,
    );
  }

  Widget _resultsPane(
    List<RecitedTextSearchResult> results,
    int? selectedIndex,
    ValueChanged<int> onSelected,
  ) {
    return Column(
      children: [
        _header(),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemExtent: LibraryDesignTokens.rowHeight,
            itemBuilder: (context, index) {
              return _row(results[index], index, selectedIndex == index, onSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      height: LibraryDesignTokens.headerHeight,
      color: LibraryDesignTokens.header,
      child: Row(
        textDirection: TextDirection.rtl,
        children: const [
          SearchResultCell('مسلسل', width: 70, center: true),
          SearchResultCell('السورة', width: 150, center: true),
          SearchResultCell('الآية', width: 70, center: true),
          SearchResultCell('الصفحة', width: 80, center: true),
          SearchResultCell('النص', flex: 1, center: true),
        ],
      ),
    );
  }

  Widget _row(
    RecitedTextSearchResult result,
    int index,
    bool selected,
    ValueChanged<int> onSelected,
  ) {
    return InkWell(
      onTap: () => onSelected(index),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? LibraryDesignTokens.selected
              : index.isEven
                  ? Colors.white
                  : LibraryDesignTokens.alternateRow,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            SearchResultCell('${index + 1}', width: 70, center: true),
            SearchResultCell(result.chapter.name, width: 150),
            SearchResultCell('${result.passage.passageNumber}', width: 70),
            SearchResultCell('${result.passage.pageNumber}', width: 80),
            SearchResultCell(result.snippet, flex: 1),
          ],
        ),
      ),
    );
  }
}
