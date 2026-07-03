import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_search_field.dart';

Future<LibraryEntityRow?> showLibraryEntityPickerDialog({
  required BuildContext context,
  required String title,
  required String searchHint,
  required String titleHeader,
  required String secondaryHeader,
  required Future<List<LibraryEntityRow>> Function(String query) loadRows,
}) {
  return showDialog<LibraryEntityRow>(
    context: context,
    builder: (_) => _LibraryEntityPickerDialog(
      title: title,
      searchHint: searchHint,
      titleHeader: titleHeader,
      secondaryHeader: secondaryHeader,
      loadRows: loadRows,
    ),
  );
}

class _LibraryEntityPickerDialog extends StatefulWidget {
  const _LibraryEntityPickerDialog({
    required this.title,
    required this.searchHint,
    required this.titleHeader,
    required this.secondaryHeader,
    required this.loadRows,
  });

  final String title;
  final String searchHint;
  final String titleHeader;
  final String secondaryHeader;
  final Future<List<LibraryEntityRow>> Function(String query) loadRows;

  @override
  State<_LibraryEntityPickerDialog> createState() =>
      _LibraryEntityPickerDialogState();
}

class _LibraryEntityPickerDialogState extends State<_LibraryEntityPickerDialog> {
  final _search = TextEditingController();
  List<LibraryEntityRow> _rows = [];
  String? _selectedId;
  bool _loading = true;
  Timer? _searchDebounce;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            _submit();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 560,
            height: 460,
            child: Column(
              children: [
                LibrarySearchField(
                  controller: _search,
                  hint: widget.searchHint,
                  onChanged: _scheduleLoad,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : LibraryEntitiesTable(
                          rows: _rows,
                          selectedId: _selectedId,
                          titleHeader: widget.titleHeader,
                          secondaryHeader: widget.secondaryHeader,
                          onSelected: (id) => setState(() => _selectedId = id),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: _selectedId == null ? null : _submit,
              child: const Text('موافق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load(String query) async {
    _searchDebounce?.cancel();
    final ticket = ++_loadSerial;
    setState(() => _loading = true);
    final rows = await widget.loadRows(query);
    if (!mounted || ticket != _loadSerial) return;
    setState(() {
      _rows = rows;
      if (!_rows.any((row) => row.id == _selectedId)) _selectedId = null;
      _loading = false;
    });
  }

  void _scheduleLoad(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _load(query),
    );
  }

  void _submit() {
    for (final row in _rows) {
      if (row.id == _selectedId) {
        Navigator.pop(context, row);
        return;
      }
    }
  }
}
