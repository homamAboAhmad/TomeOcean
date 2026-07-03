import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/widgets/search_query_text_field.dart';

class SearchPhraseOptionsPanel extends StatelessWidget {
  final bool morphologicalSearch;
  final bool affixSearch;
  final bool considerHamzas;
  final bool considerDiacritics;
  final bool considerNumbers;
  final Function(String, bool) onAdvancedOptionChanged;
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
  final String? searchGrouping;
  final Function(String)? onSearchGroupingChanged;
  final Widget? trailingContent;
  final String? title;
  final EdgeInsetsGeometry padding;

  const SearchPhraseOptionsPanel({
    super.key,
    required this.morphologicalSearch,
    required this.affixSearch,
    required this.considerHamzas,
    required this.considerDiacritics,
    required this.considerNumbers,
    required this.onAdvancedOptionChanged,
    required this.ordered,
    required this.proximity,
    required this.onPhraseOptionChanged,
    required this.groupControllers,
    required this.onAddQueryField,
    required this.onRemoveQueryField,
    required this.onSearch,
    required this.onClear,
    required this.isLoading,
    required this.totalCount,
    this.errorMessage,
    this.searchGrouping,
    this.onSearchGroupingChanged,
    this.trailingContent,
    this.title,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.right,
                style: normalStyle(
                  fontSize: 13,
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            _buildSearchTypeOptions(),
            const SizedBox(height: 4),
            _buildAdvancedOptions(),
            const SizedBox(height: 12),
            _buildSearchGrouping(),
            _buildSearchGroups(),
            if (trailingContent != null) ...[
              const SizedBox(height: 4),
              trailingContent!,
            ],
            const SizedBox(height: 6),
            _buildResultsSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTypeOptions() {
    return Row(
      children: [
        Flexible(
          child: _buildCheckbox('بحث صرفي', morphologicalSearch, (value) {
            onAdvancedOptionChanged('morphological', value);
          }),
        ),
        const SizedBox(width: 24),
        Flexible(
          child: _buildCheckbox('بحث باللواصق', affixSearch, (value) {
            onAdvancedOptionChanged('affix', value);
          }),
        ),
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _buildCheckbox('مراعاة الهمزات', considerHamzas, (value) {
          onAdvancedOptionChanged('hamzas', value);
        }),
        _buildCheckbox('مراعاة التشكيل', considerDiacritics, (value) {
          onAdvancedOptionChanged('diacritics', value);
        }),
        _buildCheckbox('مراعاة الأرقام', considerNumbers, (value) {
          onAdvancedOptionChanged('numbers', value);
        }),
      ],
    );
  }

  Widget _buildSearchGrouping() {
    if (onSearchGroupingChanged == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('البحث بكل المجموعات', style: normalStyle(fontSize: 11)),
            value: 'all',
            groupValue: searchGrouping ?? 'all',
            onChanged: (value) => onSearchGroupingChanged!(value!),
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('البحث بواحدة أو أكثر', style: normalStyle(fontSize: 11)),
            value: 'one_or_more',
            groupValue: searchGrouping ?? 'all',
            onChanged: (value) => onSearchGroupingChanged!(value!),
          ),
        ),
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
            height: 22,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    labelColor: primaryColor,
                    unselectedLabelColor: accentColor.withOpacity(0.62),
                    indicatorColor: actionColor,
                    tabs: const [
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
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                  tooltip: 'مسح جميع المربعات',
                ),
              ],
            ),
          ),
          SizedBox(
            height: _groupTabsHeight,
            child: TabBarView(
              children: [
                _buildGroupTab('and'),
                _buildGroupTab('or'),
                _buildGroupTab('not'),
              ],
            ),
          ),
          _buildInlineErrorMessage(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: mutedColor,
              border: Border(top: AppChrome.borderSide()),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onSearch,
                  icon: const LibraryIcon(LibraryIconType.search, size: 16, color: Colors.white),
                  label: Text(
                    isLoading ? 'جاري البحث...' : 'بحث',
                    style: normalStyle(color: Colors.white, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 28),
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

  double get _groupTabsHeight {
    var maxCount = 1;
    for (final controllers in groupControllers.values) {
      if (controllers.length > maxCount) maxCount = controllers.length;
    }
    return 48 + maxCount * 42.0;
  }

  Widget _buildGroupTab(String groupKey) {
    final controllers = groupControllers[groupKey] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: groupKey == 'and'
                    ? _buildAndGroupOptions()
                    : _buildGroupDescription(groupKey),
              ),
              IconButton(
                icon: const LibraryIcon(LibraryIconType.zoomIn, size: 20, color: primaryColor),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                tooltip: 'إضافة مربع بحث',
                onPressed: () => onAddQueryField(
                    groupKey, controllers.isEmpty ? 0 : controllers.length - 1),
              ),
            ],
          ),
        ),
        ...List.generate(
          controllers.length,
          (index) => _buildQueryField(groupKey, index, controllers[index]),
        ),
      ],
    );
  }

  Widget _buildAndGroupOptions() {
    return Row(
      children: [
        Text(
          'يلزم وجود العبارات',
          style: normalStyle(fontSize: 11, color: accentColor),
        ),
        const SizedBox(width: 12),
        _buildCheckbox('مرتبة', ordered, (value) {
          onPhraseOptionChanged('ordered', value);
        }),
        const SizedBox(width: 8),
        _buildCheckbox('متقاربة', proximity, (value) {
          onPhraseOptionChanged('proximity', value);
        }),
      ],
    );
  }

  Widget _buildGroupDescription(String groupKey) {
    final description = switch (groupKey) {
      'or' => 'يلزم وجود عبارة أو أكثر',
      'not' => 'يلزم غياب كل العبارات',
      _ => '',
    };
    return Text(
      description,
      style: normalStyle(fontSize: 11, color: accentColor),
    );
  }

  Widget _buildQueryField(
    String groupKey,
    int index,
    TextEditingController controller,
  ) {
    final controllers = groupControllers[groupKey] ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: SearchQueryTextField(
              index: index,
              controller: controller,
              onSubmitted: onSearch,
            ),
          ),
          if (controllers.length > 1) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const LibraryIcon(LibraryIconType.zoomOut, size: 20, color: Colors.red),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () => onRemoveQueryField(groupKey, index),
              tooltip: 'حذف مربع البحث',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Center(
        child: Text(
          errorMessage!,
          style: normalStyle(color: Colors.red, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Text('النتائج: $totalCount',
        style: normalStyle(fontSize: 11, color: accentColor));
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
            onChanged: (next) => onChanged(next ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: primaryColor,
            checkColor: Colors.white,
            fillColor: value ? MaterialStateProperty.all(primaryColor) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: normalStyle(fontSize: 11)),
      ],
    );
  }
}
