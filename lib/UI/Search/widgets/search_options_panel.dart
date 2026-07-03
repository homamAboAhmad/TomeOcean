import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/widgets/search_phrase_options_panel.dart';

/// Widget for the left panel containing search options
class SearchOptionsPanel extends StatelessWidget {
  final Map<String, bool> searchSections;
  final Function(String, bool) onSearchSectionChanged;
  final bool morphologicalSearch;
  final bool affixSearch;
  final bool considerHamzas;
  final bool considerDiacritics;
  final bool considerNumbers;
  final Function(String, bool) onAdvancedOptionChanged;
  final bool allPhrasesRequired;
  final bool ordered;
  final bool proximity;
  final Function(String, bool) onPhraseOptionChanged;
  final Map<String, List<TextEditingController>> groupControllers;
  final Function(String, int) onAddQueryField;
  final Function(String, int) onRemoveQueryField;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final bool isLoading;
  final String? errorMessage;
  final int totalCount;
  final List<Map<String, dynamic>>? selectedBooksForSearch;
  final Function(List<int>)? onRemoveFromSelectedList;
  final Function()? onClearSelectedList;
  final TextEditingController? selectedBooksSearchController;
  final String? searchGrouping;
  final Function(String)? onSearchGroupingChanged;

  const SearchOptionsPanel({
    Key? key,
    required this.searchSections,
    required this.onSearchSectionChanged,
    required this.morphologicalSearch,
    required this.affixSearch,
    required this.considerHamzas,
    required this.considerDiacritics,
    required this.considerNumbers,
    required this.onAdvancedOptionChanged,
    required this.allPhrasesRequired,
    required this.ordered,
    required this.proximity,
    required this.onPhraseOptionChanged,
    required this.groupControllers,
    required this.onAddQueryField,
    required this.onRemoveQueryField,
    required this.onSearch,
    required this.onClear,
    required this.isLoading,
    this.errorMessage,
    required this.totalCount,
    this.selectedBooksForSearch,
    this.onRemoveFromSelectedList,
    this.onClearSelectedList,
    this.selectedBooksSearchController,
    this.searchGrouping,
    this.onSearchGroupingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Fixed height section for search scope and options
          _buildSearchScope(),
          SizedBox(height: 16),
          Expanded(
            child: SearchPhraseOptionsPanel(
              morphologicalSearch: morphologicalSearch,
              affixSearch: affixSearch,
              considerHamzas: considerHamzas,
              considerDiacritics: considerDiacritics,
              considerNumbers: considerNumbers,
              onAdvancedOptionChanged: onAdvancedOptionChanged,
              ordered: ordered,
              proximity: proximity,
              onPhraseOptionChanged: onPhraseOptionChanged,
              groupControllers: groupControllers,
              onAddQueryField: onAddQueryField,
              onRemoveQueryField: onRemoveQueryField,
              onSearch: onSearch,
              onClear: onClear,
              isLoading: isLoading,
              errorMessage: errorMessage,
              totalCount: totalCount,
              searchGrouping: searchGrouping,
              onSearchGroupingChanged: onSearchGroupingChanged,
              trailingContent: Column(
                children: [
                  _buildSelectedBooksSearchField(),
                  SizedBox(height: 4),
                  SizedBox(height: 120, child: _buildSelectedBooksList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScope() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: organicHighlightColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LibraryIcon.fromIcon(Icons.search, size: 16, color: primaryColor),
              SizedBox(width: 4),
              Text(
                'نطاق البحث:',
                style: normalStyle(fontSize: 13, color: primaryColor),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // المتن (Body Text) - Main content
              Tooltip(
                message: 'البحث في المتن الرئيسي للكتاب',
                child: _buildScopeCheckbox(
                  'المتن',
                  Icons.article_outlined,
                  searchSections['main'] ?? true,
                  (v) => onSearchSectionChanged('main', v),
                ),
              ),
              // الحواشي (Footnotes) - References and marginal notes
              Tooltip(
                message: 'البحث في الحواشي والمراجع الهامشية',
                child: _buildScopeCheckbox(
                  'الحواشي',
                  Icons.format_quote,
                  searchSections['footnote'] ?? true,
                  (v) => onSearchSectionChanged('footnote', v),
                ),
              ),
              Tooltip(
                message: 'البحث في تعليقات الصفحات',
                child: _buildScopeCheckbox(
                  'التعليقات',
                  Icons.comment_outlined,
                  searchSections['comment'] ?? false,
                  (v) => onSearchSectionChanged('comment', v),
                ),
              ),
              // العناوين (Headings) - Titles and sub-headings
              Tooltip(
                message: 'البحث في العناوين الرئيسية والفرعية',
                child: _buildScopeCheckbox(
                  'العناوين',
                  Icons.title,
                  searchSections['title'] ?? false,
                  (v) => onSearchSectionChanged('title', v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a styled checkbox for search scope with icon
  Widget _buildScopeCheckbox(
    String label,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: value ? organicHighlightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
          border: Border.all(
            color: value ? actionColor : accentColor.withOpacity(0.38),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LibraryIcon.fromIcon(
              icon,
              size: 12,
              color: value ? primaryColor : accentColor.withOpacity(0.70),
            ),
            SizedBox(width: 3),
            Text(
              label,
              style: normalStyle(
                fontSize: 10,
                color: value ? primaryColor : accentColor,
              ),
            ),
            SizedBox(width: 3),
            LibraryIcon.fromIcon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 12,
              color: value ? actionColor : accentColor.withOpacity(0.38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v!),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: primaryColor,
            checkColor: Colors.white,
            fillColor: value ? MaterialStateProperty.all(primaryColor) : null,
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: normalStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSearchTypeOptions() {
    return Row(
      children: [
        Flexible(
          child: _buildCheckbox('بحث صرفي', morphologicalSearch, (v) {
            onAdvancedOptionChanged('morphological', v);
          }),
        ),
        SizedBox(width: 24),
        Flexible(
          child: _buildCheckbox('بحث باللواصق', affixSearch, (v) {
            onAdvancedOptionChanged('affix', v);
          }),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Wrap(
      spacing: 12.0,
      runSpacing: 4.0,
      children: [
        _buildCheckbox('مراعاة الهمزات', considerHamzas, (v) {
          onAdvancedOptionChanged('hamzas', v);
        }),
        _buildCheckbox('مراعاة التشكيل', considerDiacritics, (v) {
          onAdvancedOptionChanged('diacritics', v);
        }),
        _buildCheckbox('مراعاة الأرقام', considerNumbers, (v) {
          onAdvancedOptionChanged('numbers', v);
        }),
      ],
    );
  }

  Widget _buildSearchGrouping() {
    if (onSearchGroupingChanged == null) return SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'البحث بكل المجموعات',
              style: normalStyle(fontSize: 12),
            ),
            value: 'all',
            groupValue: searchGrouping ?? 'all',
            onChanged: (value) => onSearchGroupingChanged!(value!),
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'البحث بواحدة أو أكثر',
              style: normalStyle(fontSize: 12),
            ),
            value: 'one_or_more',
            groupValue: searchGrouping ?? 'all',
            onChanged: (value) => onSearchGroupingChanged!(value!),
          ),
        ),
      ],
    );
  }

  Widget _buildAndGroupOptions() {
    return Row(
      children: [
        Text(
          'يلزم وجود العبارات',
          style: normalStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        SizedBox(width: 12),
        _buildCheckbox('مرتبة', ordered, (v) {
          onPhraseOptionChanged('ordered', v);
        }),
        SizedBox(width: 8),
        _buildCheckbox('متقاربة', proximity, (v) {
          onPhraseOptionChanged('proximity', v);
        }),
      ],
    );
  }

  Widget _buildPhraseOptions() {
    return Wrap(
      spacing: 6.0,
      runSpacing: 2.0,
      children: [
        _buildCheckbox('مرتبة', ordered, (v) {
          onPhraseOptionChanged('ordered', v);
        }),
        _buildCheckbox('متقاربة', proximity, (v) {
          onPhraseOptionChanged('proximity', v);
        }),
      ],
    );
  }

  Widget _buildSearchGroups() {
    return DefaultTabController(
      length: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    labelColor: primaryColor,
                    unselectedLabelColor: accentColor.withOpacity(0.62),
                    indicatorColor: actionColor,
                    tabs: [
                      Tab(text: 'و'),
                      Tab(text: 'أو'),
                      Tab(text: 'ليس'),
                    ],
                  ),
                ),
                IconButton(
                  icon: LibraryIcon.fromIcon(
                    Icons.clear_all,
                    size: 18,
                    color: accentColor.withOpacity(0.70),
                  ),
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                  onPressed: onClear,
                  tooltip: 'مسح جميع المربعات',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: TabBarView(
              children: [
                _buildGroupTab('و', 'and'),
                _buildGroupTab('أو', 'or'),
                _buildGroupTab('ليس', 'not'),
              ],
            ),
          ),
          _buildInlineErrorMessage(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: mutedColor,
              border: Border(top: AppChrome.borderSide()),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onSearch,
                  icon: const LibraryIcon(LibraryIconType.search, size: 16, color: Colors.white),
                  label: Text(
                    'بحث',
                    style: normalStyle(color: Colors.white, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    minimumSize: Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorMessage() {
    if (errorMessage == null) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 2),
      child: Center(
        child: Text(
          errorMessage!,
          style: normalStyle(color: Colors.red, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGroupTab(String label, String groupKey) {
    return _GroupTabContent(
      label: label,
      groupKey: groupKey,
      controllers: groupControllers[groupKey] ?? [],
      onAddQueryField: onAddQueryField,
      groupKeyForAnd: groupKey == 'and',
      buildAndGroupOptions: () => _buildAndGroupOptions(),
      buildGroupDescription: (key) => _buildGroupDescription(key),
      buildQueryField: (key, index, controller) =>
          _buildQueryField(key, index, controller),
    );
  }

  Widget _buildGroupDescription(String groupKey) {
    String description;
    if (groupKey == 'and') {
      description = 'يلزم وجود العبارات';
    } else if (groupKey == 'or') {
      description = 'يلزم وجود عبارة أو أكثر';
    } else if (groupKey == 'not') {
      description = 'يلزم غياب كل العبارات';
    } else {
      description = '';
    }

    return Text(
      description,
      style: normalStyle(fontSize: 12, color: Colors.grey.shade700),
    );
  }

  Widget _buildQueryField(
    String groupKey,
    int index,
    TextEditingController controller,
  ) {
    final controllers = groupControllers[groupKey] ?? [];
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Text('${index + 1}', style: normalStyle(fontSize: 11)),
          ),
          SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                isDense: true,
              ),
              style: normalStyle(fontSize: 12),
              onSubmitted: (_) => onSearch(),
            ),
          ),
          if (controllers.length > 1) ...[
            SizedBox(width: 4),
            IconButton(
              icon: const LibraryIcon(LibraryIconType.zoomOut, size: 20, color: Colors.red),
              padding: EdgeInsets.all(4),
              constraints: BoxConstraints(),
              onPressed: () => onRemoveQueryField(groupKey, index),
              tooltip: 'حذف مربع البحث',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedBooksSearchField() {
    if (selectedBooksForSearch == null || selectedBooksForSearch!.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
      ),
      child: TextField(
        controller: selectedBooksSearchController,
        decoration: InputDecoration(
          hintText: 'ابحث في الكتب المحددة',
          hintStyle: normalStyle(fontSize: 11, color: accentColor.withOpacity(0.64)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
          prefixIcon: LibraryIcon.fromIcon(Icons.search, size: 16, color: accentColor.withOpacity(0.64)),
        ),
        style: normalStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildSelectedBooksList() {
    if (selectedBooksForSearch == null || selectedBooksForSearch!.isEmpty) {
      return SizedBox.shrink();
    }

    // Use ValueListenableBuilder to rebuild when search text changes
    final controller = selectedBooksSearchController;
    if (controller == null) {
      return _buildFilteredList(selectedBooksForSearch!, '');
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return _buildFilteredList(selectedBooksForSearch!, value.text);
      },
    );
  }

  Widget _buildFilteredList(
    List<Map<String, dynamic>> allItems,
    String searchText,
  ) {
    // Filter the list based on search text
    final searchLower = searchText.toLowerCase().trim();
    final filteredList = searchLower.isEmpty
        ? allItems
        : allItems.where((item) {
            final name = (item['name'] as String).toLowerCase();
            final bookPath = (item['bookPath'] as String? ?? '').toLowerCase();
            final deathYear = (item['deathYear'] as String? ?? '')
                .toLowerCase();
            return name.contains(searchLower) ||
                bookPath.contains(searchLower) ||
                deathYear.contains(searchLower);
          }).toList();

    if (filteredList.isEmpty && searchLower.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'لا توجد نتائج',
              style: normalStyle(fontSize: 11, color: accentColor.withOpacity(0.64)),
            ),
          ),
        ),
      );
    }

    return _SelectedBooksScrollableList(
      filteredList: filteredList,
      onClearSelectedList: onClearSelectedList,
    );
  }

  Widget _buildResultsSummary() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (totalCount > 0) {
      return Text(
        'عدد النتائج: $totalCount',
        style: normalStyle(color: primaryColor, fontSize: 12),
      );
    }
    return SizedBox.shrink();
  }
}

/// Stateful widget for group tab content with isolated scrolling
class _GroupTabContent extends StatefulWidget {
  final String label;
  final String groupKey;
  final List<TextEditingController> controllers;
  final Function(String, int) onAddQueryField;
  final bool groupKeyForAnd;
  final Widget Function() buildAndGroupOptions;
  final Widget Function(String) buildGroupDescription;
  final Widget Function(String, int, TextEditingController) buildQueryField;

  const _GroupTabContent({
    Key? key,
    required this.label,
    required this.groupKey,
    required this.controllers,
    required this.onAddQueryField,
    required this.groupKeyForAnd,
    required this.buildAndGroupOptions,
    required this.buildGroupDescription,
    required this.buildQueryField,
  }) : super(key: key);

  @override
  State<_GroupTabContent> createState() => _GroupTabContentState();
}

class _GroupTabContentState extends State<_GroupTabContent> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Prevent scroll notifications from bubbling up to parent ScrollView
        return true;
      },
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView(
          controller: _scrollController,
          physics: ClampingScrollPhysics(),
          padding: EdgeInsets.all(8),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.groupKeyForAnd) ...[
                  widget.buildAndGroupOptions(),
                ] else ...[
                  // Add description text for other groups
                  widget.buildGroupDescription(widget.groupKey),
                ],
                IconButton(
                  icon: const LibraryIcon(LibraryIconType.zoomIn, size: 20, color: primaryColor),
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(),
                  onPressed: () => widget.onAddQueryField(
                    widget.groupKey,
                    widget.controllers.length,
                  ),
                  tooltip: 'إضافة مربع بحث',
                ),
              ],
            ),
            // Add description and options for "and" group in same row
            SizedBox(height: 8),

            if (widget.controllers.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'لا توجد مربعات بحث في هذه المجموعة',
                    style: normalStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              )
            else
              ...List.generate(widget.controllers.length, (index) {
                return widget.buildQueryField(
                  widget.groupKey,
                  index,
                  widget.controllers[index],
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Stateful widget for scrollable selected books list
class _SelectedBooksScrollableList extends StatefulWidget {
  final List<Map<String, dynamic>> filteredList;
  final VoidCallback? onClearSelectedList;

  const _SelectedBooksScrollableList({
    Key? key,
    required this.filteredList,
    this.onClearSelectedList,
  }) : super(key: key);

  @override
  State<_SelectedBooksScrollableList> createState() =>
      _SelectedBooksScrollableListState();
}

class _SelectedBooksScrollableListState
    extends State<_SelectedBooksScrollableList> {
  late ScrollController _scrollController;
  late int _lastItemCount;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lastItemCount = widget.filteredList.length;
    if (_lastItemCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  @override
  void didUpdateWidget(covariant _SelectedBooksScrollableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCount = widget.filteredList.length;
    if (nextCount > _lastItemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
    _lastItemCount = nextCount;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                physics: ClampingScrollPhysics(),
                itemCount: widget.filteredList.length,
                itemBuilder: (context, index) {
                  final item = widget.filteredList[index];
                  final type = item['type'] as String;
                  final name = item['name'] as String;
                  final deathYear = item['deathYear'] as String?;

                  return Container(
                    height: 28,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        LibraryIcon.fromIcon(
                          type == 'author'
                              ? Icons.edit
                              : type == 'section'
                                  ? Icons.category
                                  : type == 'period'
                                      ? Icons.calendar_today
                                      : Icons.book,
                          size: 12,
                          color: Colors.grey.shade700,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            type == 'author'
                                ? 'مؤلف: $name'
                                : type == 'section'
                                    ? 'تصنيف: $name'
                                    : type == 'period'
                                        ? 'فترة: $name'
                                        : deathYear != null
                                            ? '$name (ت $deathYear)'
                                            : name,
                            style: smallStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
