import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/SavedItems/helpers/saved_search_results_store.dart';
import 'package:golden_shamela/UI/SavedItems/models/saved_search_results_record.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_items_confirm.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_items_toolbar.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/search_results_tile.dart';

class SavedSearchResultsTab extends StatefulWidget {
  final ValueChanged<SavedSearchResultsRecord> onOpenResults;

  const SavedSearchResultsTab({
    super.key,
    required this.onOpenResults,
  });

  @override
  State<SavedSearchResultsTab> createState() => _SavedSearchResultsTabState();
}

class _SavedSearchResultsTabState extends State<SavedSearchResultsTab> {
  final _store = SavedSearchResultsStore();
  final _nameController = TextEditingController();
  List<SavedSearchResultsRecord> _results = const [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _results = _store.loadResults();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedResult;
    return Column(
      children: [
        SavedItemsToolbar(
          nameController: _nameController,
          hintText: 'اسم جديد للنتائج المحددة',
          saveTooltip: '',
          onSave: null,
          showSaveButton: false,
          onRename: selected == null ? null : _renameSelected,
          onMoveUp: selected == null ? null : () => _moveSelected(-1),
          onMoveDown: selected == null ? null : () => _moveSelected(1),
          onDelete: selected == null ? null : _deleteSelected,
        ),
        Expanded(
          child: _results.isEmpty
              ? _emptyState()
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return SearchResultsTile(
                      result: result,
                      selected: result.id == _selectedId,
                      onTap: () {
                        setState(() {
                          _selectedId = result.id;
                          _nameController.text = result.name;
                        });
                      },
                      onOpen: () => _openResult(result),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Text(
        'لا توجد نتائج بحث محفوظة',
        style: normalStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    );
  }

  Future<void> _renameSelected() async {
    final selected = _selectedResult;
    if (selected == null) return;
    final results = await _store.renameResult(selected.id, _nameController.text);
    if (!mounted) return;
    setState(() => _results = results);
  }

  Future<void> _moveSelected(int direction) async {
    final selected = _selectedResult;
    if (selected == null) return;
    final results = await _store.moveResult(selected.id, direction);
    if (!mounted) return;
    setState(() => _results = results);
  }

  Future<void> _deleteSelected() async {
    final selected = _selectedResult;
    if (selected == null) return;
    final confirmed = await confirmSavedItemAction(
      context,
      title: 'حذف نتائج بحث محفوظة',
      message: 'هل تريد حذف "${selected.name}"؟',
    );
    if (!confirmed) return;
    final results = await _store.deleteResult(selected.id);
    if (!mounted) return;
    setState(() {
      _results = results;
      _selectedId = null;
      _nameController.clear();
    });
  }

  Future<void> _openResult(SavedSearchResultsRecord result) async {
    final loaded = await _store.loadResultData(result);
    if (!mounted) return;
    if (loaded.results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل ملف نتائج البحث')),
      );
      return;
    }
    widget.onOpenResults(loaded);
  }

  SavedSearchResultsRecord? get _selectedResult {
    for (final result in _results) {
      if (result.id == _selectedId) return result;
    }
    return null;
  }
}
