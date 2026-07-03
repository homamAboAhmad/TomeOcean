part of 'shamela_search_view.dart';

extension _ShamelaSearchViewResults on _ShamelaSearchViewState {
  Widget _buildResultsPanel() {
    return Column(
      children: [
        const ShamelaResultsTableHeader(),
        Expanded(child: _buildResultsArea()),
        ShamelaResultsFooter(
          count: widget.results.length,
          totalCount: widget.totalCount,
          isSearching: widget.isSearching,
          trailing: SaveSearchResultsBar(
            results: widget.results,
            totalCount: widget.totalCount,
            searchQueries: widget.searchQueries,
            morphologicalSearch: widget.morphologicalSearch,
            enabled: widget.results.isNotEmpty && !widget.isSearching,
            searchSnapshot: widget.searchSnapshot,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsArea() {
    if (widget.results.isEmpty && !widget.isSearching) {
      return NoResultsWidget(
        searchQueries: widget.searchQueries.isNotEmpty
            ? widget.searchQueries
            : [if (widget.searchQuery.trim().isNotEmpty) widget.searchQuery.trim()],
        onNewSearch: _newSearchFromNoResults,
      );
    }

    if (widget.results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return ListView.builder(
      controller: _resultsController,
      padding: EdgeInsets.zero,
      itemCount: widget.results.length,
      itemExtent: _ShamelaSearchViewState._rowExtent,
      cacheExtent: _ShamelaSearchViewState._rowExtent * 18,
      itemBuilder: (context, index) {
        final result = widget.results[index];
        final pathKey = result['bookPath'] ?? result['book_path'] ?? '';
        final pageKey = result['pageNumber'] ?? result['page_number'] ?? '';
        return ShamelaResultsTableRow(
          key: ValueKey('$pathKey|$pageKey|$index'),
          serial: index + 1,
          result: result,
          selected: _selectedIndex == index,
          snippetBuilder: SearchResultRowHelpers.cleanSnippet,
          searchQueries: widget.searchQueries.isNotEmpty
              ? widget.searchQueries
              : [if (widget.searchQuery.trim().isNotEmpty) widget.searchQuery.trim()],
          onOpen: () => _showResult(index),
          onDoubleOpen: () => _openResultInFullTab(index),
        );
      },
    );
  }
}
