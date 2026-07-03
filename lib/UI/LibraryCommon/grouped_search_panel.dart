import 'package:flutter/material.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/Search/widgets/search_phrase_options_panel.dart';

class GroupedSearchRequest {
  final Map<String, List<String>> groups;
  final String searchGrouping;
  final bool morphologicalSearch;
  final bool affixSearch;
  final bool considerHamzas;
  final bool considerDiacritics;
  final bool considerNumbers;
  final bool ordered;
  final bool proximity;

  const GroupedSearchRequest({
    required this.groups,
    required this.searchGrouping,
    required this.morphologicalSearch,
    required this.affixSearch,
    required this.considerHamzas,
    required this.considerDiacritics,
    required this.considerNumbers,
    required this.ordered,
    required this.proximity,
  });

  bool get hasActiveTerms => groups.values.any((terms) => terms.isNotEmpty);

  String get firstTerm {
    for (final key in const ['and', 'or', 'not']) {
      for (final term in groups[key] ?? const <String>[]) {
        final trimmed = term.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return '';
  }
}

class GroupedSearchController {
  Future<void> Function(String term)? _searchFirstField;

  Future<void> searchFirstField(String term) async {
    await _searchFirstField?.call(term);
  }

  void _attach(Future<void> Function(String term) searchFirstField) {
    _searchFirstField = searchFirstField;
  }

  void _detach() {
    _searchFirstField = null;
  }
}

class GroupedSearchPanel<T> extends StatefulWidget {
  final GroupedSearchController? controller;
  final Future<List<T>> Function(GroupedSearchRequest request) onSearch;
  final Widget Function(
    List<T> results,
    int? selectedIndex,
    ValueChanged<int> onSelected,
  ) resultsBuilder;
  final String emptyLabel;
  final String loadingLabel;
  final String noTermsMessage;
  final String failureMessage;
  final ValueChanged<T>? onResultSelected;

  const GroupedSearchPanel({
    super.key,
    this.controller,
    required this.onSearch,
    required this.resultsBuilder,
    this.emptyLabel = 'لا توجد نتائج',
    this.loadingLabel = 'جاري البحث...',
    this.noTermsMessage = 'أدخل عبارة بحث واحدة على الأقل',
    this.failureMessage = 'تعذر تنفيذ البحث',
    this.onResultSelected,
  });

  @override
  State<GroupedSearchPanel<T>> createState() => _GroupedSearchPanelState<T>();
}

class _GroupedSearchPanelState<T> extends State<GroupedSearchPanel<T>> {
  final Map<String, List<TextEditingController>> _groupControllers = {
    'and': List.generate(5, (_) => TextEditingController()),
    'or': List.generate(5, (_) => TextEditingController()),
    'not': List.generate(5, (_) => TextEditingController()),
  };
  final List<T> _results = [];

  bool _morphologicalSearch = false;
  bool _affixSearch = false;
  bool _considerHamzas = false;
  bool _considerDiacritics = false;
  bool _considerNumbers = true;
  bool _ordered = false;
  bool _proximity = false;
  bool _loading = false;
  String _searchGrouping = 'all';
  String? _errorMessage;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_searchFirstField);
  }

  @override
  void didUpdateWidget(covariant GroupedSearchPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?._detach();
    widget.controller?._attach(_searchFirstField);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    for (final controllers in _groupControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: LibraryDesignTokens.divider)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            SizedBox(width: 330, child: _optionsPane()),
            const VerticalDivider(width: 1, color: LibraryDesignTokens.divider),
            Expanded(child: _resultsPane()),
          ],
        ),
      ),
    );
  }

  Widget _optionsPane() {
    return Container(
      color: const Color(0xFFF8F8F8),
      child: SearchPhraseOptionsPanel(
        padding: const EdgeInsets.all(10),
        morphologicalSearch: _morphologicalSearch,
        affixSearch: _affixSearch,
        considerHamzas: _considerHamzas,
        considerDiacritics: _considerDiacritics,
        considerNumbers: _considerNumbers,
        onAdvancedOptionChanged: _setAdvancedOption,
        ordered: _ordered,
        proximity: _proximity,
        onPhraseOptionChanged: _setPhraseOption,
        groupControllers: _groupControllers,
        onAddQueryField: _addQueryField,
        onRemoveQueryField: _removeQueryField,
        onSearch: _search,
        onClear: _clear,
        isLoading: _loading,
        errorMessage: _errorMessage,
        totalCount: _results.length,
        searchGrouping: _searchGrouping,
        onSearchGroupingChanged: (value) {
          setState(() => _searchGrouping = value);
        },
      ),
    );
  }

  Widget _resultsPane() {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _loading ? widget.loadingLabel : widget.emptyLabel,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }
    return widget.resultsBuilder(_results, _selectedIndex, _selectResult);
  }

  Future<void> _searchFirstField(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      for (final controllers in _groupControllers.values) {
        for (final controller in controllers) {
          controller.clear();
        }
      }
      _groupControllers['and']!.first.text = trimmed;
    });
    await _search();
  }

  Future<void> _search() async {
    final request = _request();
    if (!request.hasActiveTerms) {
      setState(() => _errorMessage = widget.noTermsMessage);
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
      _selectedIndex = null;
    });
    try {
      final results = await widget.onSearch(request);
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(results);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = widget.failureMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    setState(() {
      for (final controllers in _groupControllers.values) {
        for (final controller in controllers) {
          controller.clear();
        }
      }
      _results.clear();
      _errorMessage = null;
      _selectedIndex = null;
    });
  }

  void _selectResult(int index) {
    setState(() => _selectedIndex = index);
    widget.onResultSelected?.call(_results[index]);
  }

  GroupedSearchRequest _request() {
    return GroupedSearchRequest(
      groups: _activeGroups(),
      searchGrouping: _searchGrouping,
      morphologicalSearch: _morphologicalSearch,
      affixSearch: _affixSearch,
      considerHamzas: _considerHamzas,
      considerDiacritics: _considerDiacritics,
      considerNumbers: _considerNumbers,
      ordered: _ordered,
      proximity: _proximity,
    );
  }

  void _setAdvancedOption(String option, bool value) {
    setState(() {
      switch (option) {
        case 'morphological':
          _morphologicalSearch = value;
          break;
        case 'affix':
          _affixSearch = value;
          break;
        case 'hamzas':
          _considerHamzas = value;
          break;
        case 'diacritics':
          _considerDiacritics = value;
          break;
        case 'numbers':
          _considerNumbers = value;
          break;
      }
    });
  }

  void _setPhraseOption(String option, bool value) {
    setState(() {
      if (option == 'ordered') _ordered = value;
      if (option == 'proximity') _proximity = value;
    });
  }

  void _addQueryField(String groupKey, int index) {
    setState(() {
      _groupControllers[groupKey]!.insert(index + 1, TextEditingController());
    });
  }

  void _removeQueryField(String groupKey, int index) {
    final controllers = _groupControllers[groupKey]!;
    if (controllers.length <= 1) return;
    setState(() {
      controllers[index].dispose();
      controllers.removeAt(index);
    });
  }

  Map<String, List<String>> _activeGroups() {
    return {
      for (final entry in _groupControllers.entries)
        entry.key: entry.value
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(),
    };
  }
}

class SearchResultCell extends StatelessWidget {
  final String text;
  final double? width;
  final int? flex;
  final bool center;

  const SearchResultCell(
    this.text, {
    super.key,
    this.width,
    this.flex,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      alignment: center ? Alignment.center : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: center ? TextAlign.center : TextAlign.right,
      ),
    );
    if (flex != null) return Expanded(flex: flex!, child: child);
    return SizedBox(width: width, child: child);
  }
}
