import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/SavedItems/helpers/saved_search_results_store.dart';
import 'package:golden_shamela/UI/SavedItems/models/saved_search_results_record.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';

class SaveSearchResultsBar extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final bool enabled;
  final SearchStateSnapshot searchSnapshot;

  const SaveSearchResultsBar({
    super.key,
    required this.results,
    required this.totalCount,
    required this.searchQueries,
    required this.morphologicalSearch,
    required this.enabled,
    required this.searchSnapshot,
  });

  @override
  State<SaveSearchResultsBar> createState() => _SaveSearchResultsBarState();
}

class _SaveSearchResultsBarState extends State<SaveSearchResultsBar> {
  final _nameController = TextEditingController();
  final _store = SavedSearchResultsStore();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 190,
          height: 24,
          child: TextField(
            controller: _nameController,
            enabled: widget.enabled && !_saving,
            style: smallStyle(color: accentColor, fontSize: 11),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'اسم النتائج',
              hintStyle: smallStyle(color: accentColor.withOpacity(0.58), fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 5,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 26,
          height: 26,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'حفظ نتائج البحث',
            onPressed: widget.enabled && !_saving ? _save : null,
            icon: const LibraryIcon(LibraryIconType.save, color: actionColor, size: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final name = _nameController.text.trim().isEmpty
        ? _fallbackName()
        : _nameController.text.trim();
    final record = SavedSearchResultsRecord(
      id: now.toString(),
      name: name,
      createdAt: now,
      orderIndex: 0,
      results: widget.results
          .map((row) => Map<String, dynamic>.from(row))
          .toList(),
      totalCount: widget.totalCount,
      searchQueries: List<String>.from(widget.searchQueries),
      morphologicalSearch: widget.morphologicalSearch,
      searchSnapshot: widget.searchSnapshot,
    );
    await _store.saveResult(record);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ نتائج البحث')),
    );
  }

  String _fallbackName() {
    final query = widget.searchQueries.join('، ').trim();
    return query.isEmpty ? 'نتائج بحث محفوظة' : 'بحث: $query';
  }
}
