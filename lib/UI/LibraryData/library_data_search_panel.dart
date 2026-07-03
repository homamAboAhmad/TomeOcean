import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/LibraryCommon/grouped_search_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_models.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_repository.dart';

class LibraryDataSearchPanel extends StatelessWidget {
  final LibraryDataRepository repository;
  final ValueChanged<LibraryDataSearchResult> onResultSelected;

  const LibraryDataSearchPanel({
    super.key,
    required this.repository,
    required this.onResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GroupedSearchPanel<LibraryDataSearchResult>(
      onSearch: (request) {
        return repository.searchWithGroups(
          groups: request.groups,
          searchGrouping: request.searchGrouping,
          morphologicalSearch: request.morphologicalSearch,
          considerDiacritics: request.considerDiacritics,
          considerHamzas: request.considerHamzas,
          considerNumbers: request.considerNumbers,
          ordered: request.ordered,
          proximity: request.proximity,
          affixSearch: request.affixSearch,
        );
      },
      onResultSelected: onResultSelected,
      resultsBuilder: _resultsPane,
    );
  }

  Widget _resultsPane(
    List<LibraryDataSearchResult> results,
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
              return _resultRow(
                results[index],
                index,
                selectedIndex == index,
                onSelected,
              );
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
          SearchResultCell('العنصر', width: 270, center: true),
          SearchResultCell('النص', flex: 1, center: true),
        ],
      ),
    );
  }

  Widget _resultRow(
    LibraryDataSearchResult result,
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
            SizedBox(
              width: 270,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const SizedBox(width: 8),
                  LibraryIcon.fromIcon(
                    result.type.icon,
                    size: 17,
                    color: LibraryDesignTokens.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.title,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            SearchResultCell(result.snippet, flex: 1),
          ],
        ),
      ),
    );
  }
}
