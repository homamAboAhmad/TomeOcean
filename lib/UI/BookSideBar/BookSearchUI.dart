import 'dart:async';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/InBookSearchHelper.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/core/app_state.dart';

class BookSearchUI extends StatefulWidget {
  final WordDocument wordDocument;
  final Function(int pageIndex) onNavigateToPage;
  final FocusNode? searchFocusNode;

  const BookSearchUI({
    super.key,
    required this.wordDocument,
    required this.onNavigateToPage,
    this.searchFocusNode,
  });

  @override
  State<BookSearchUI> createState() => _BookSearchUIState();
}

class _BookSearchUIState extends State<BookSearchUI> {
  final TextEditingController _searchController = TextEditingController();
  late InBookSearchHelper _searchHelper;

  List<InBookSearchResult> _results = [];
  int _selectedIndex = -1;
  bool _isSearching = false;
  bool _searchCompleted = false;
  bool _ignoreDiacritics = true;
  bool _ignoreHamzas = true;
  StreamSubscription? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _searchHelper = InBookSearchHelper(widget.wordDocument);
  }

  @override
  void didUpdateWidget(covariant BookSearchUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wordDocument != widget.wordDocument) {
      _searchHelper = InBookSearchHelper(widget.wordDocument);
      _clearResults();
    }
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    _searchSubscription?.cancel();
    setState(() {
      _results = [];
      _selectedIndex = -1;
      _isSearching = true;
      _searchCompleted = false;
    });

    AppState().setSearchHighlight([query]);

    _searchSubscription = _searchHelper
        .searchStream(
          query: query,
          ignoreDiacritics: _ignoreDiacritics,
          ignoreHamzas: _ignoreHamzas,
        )
        .listen(
          (result) {
            if (!mounted) return;
            setState(() {
              _results.add(result);
              if (_results.length == 1) {
                _selectedIndex = 0;
                AppState().setSearchTarget(
                  result.pageIndex,
                  result.paragraphIndex,
                );
                widget.onNavigateToPage(result.pageIndex);
              }
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _isSearching = false;
              _searchCompleted = true;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _isSearching = false);
          },
        );
  }

  void _stopSearch() {
    _searchSubscription?.cancel();
    setState(() {
      _isSearching = false;
      _searchCompleted = true;
    });
  }

  void _clearResults() {
    _searchSubscription?.cancel();
    setState(() {
      _results = [];
      _selectedIndex = -1;
      _isSearching = false;
      _searchCompleted = false;
    });
    AppState().clearSearchHighlight();
  }

  void _selectResult(int index) {
    if (index < 0 || index >= _results.length) return;
    setState(() => _selectedIndex = index);
    final result = _results[index];
    AppState().setSearchTarget(result.pageIndex, result.paragraphIndex);
    widget.onNavigateToPage(result.pageIndex);
  }

  void _goToNextResult() {
    if (_results.isEmpty) return;
    _selectResult((_selectedIndex + 1) % _results.length);
  }

  void _goToPreviousResult() {
    if (_results.isEmpty) return;
    _selectResult((_selectedIndex - 1 + _results.length) % _results.length);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildSearchField(),
            _buildSearchOptions(),
            _buildNavigationBar(),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: widget.searchFocusNode,
              textDirection: TextDirection.rtl,
              style: normalStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'البحث في الكتاب...',
                hintStyle: normalStyle(fontSize: 14, color: Colors.grey),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: primaryColor),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _searchController.clear();
                          _clearResults();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: _isSearching ? _stopSearch : _performSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSearching ? Colors.red.shade600 : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                _isSearching ? 'إيقاف' : 'بحث',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildOptionChip('بدون تشكيل', _ignoreDiacritics, (v) {
            setState(() => _ignoreDiacritics = v);
          }),
          const SizedBox(width: 6),
          _buildOptionChip('بدون همزات', _ignoreHamzas, (v) {
            setState(() => _ignoreHamzas = v);
          }),
        ],
      ),
    );
  }

  Widget _buildOptionChip(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: value ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? primaryColor : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: value ? primaryColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    if (_results.isEmpty && !_isSearching && !_searchCompleted) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_isSearching) ...[
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _results.isEmpty
                ? (_isSearching ? 'جارٍ البحث...' : 'لا توجد نتائج')
                : _selectedIndex >= 0
                    ? '${_selectedIndex + 1} من ${_results.length}'
                    : '${_results.length} نتيجة',
            style: smallStyle(
              color: _results.isEmpty && _searchCompleted
                  ? Colors.red.shade600
                  : primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_searchCompleted && _results.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
          ],
          const Spacer(),
          if (_results.isNotEmpty) ...[
            _navButton(Icons.arrow_upward, 'السابق', _goToPreviousResult),
            const SizedBox(width: 4),
            _navButton(Icons.arrow_downward, 'التالي', _goToNextResult),
          ],
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, size: 16, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      if (_searchCompleted) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'لا توجد نتائج',
                  style: normalStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'ابحث في الكتاب',
                style: normalStyle(color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final result = _results[index];
        final isSelected = index == _selectedIndex;

        return Material(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          child: InkWell(
            onTap: () => _selectResult(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${result.pageIndex + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.snippet,
                      style: smallStyle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (result.occurrences > 1)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '×${result.occurrences}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
