import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/helpers/search_history_store.dart';
import 'package:golden_shamela/UI/Search/helpers/search_summary_formatter.dart';
import 'package:golden_shamela/UI/Search/models/search_history_record.dart';

class SearchHistoryPanel extends StatefulWidget {
  final void Function(SearchHistoryRecord record, {required bool runSearch})
      onRecordSelected;

  const SearchHistoryPanel({
    super.key,
    required this.onRecordSelected,
  });

  @override
  State<SearchHistoryPanel> createState() => _SearchHistoryPanelState();
}

class _SearchHistoryPanelState extends State<SearchHistoryPanel> {
  final _store = SearchHistoryStore();
  List<SearchHistoryRecord> _records = const [];
  String? _selectedRecordId;

  @override
  void initState() {
    super.initState();
    _records = _store.loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 14),
          Expanded(child: _recordsCard()),
          const SizedBox(height: 12),
          _actionsBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        LibraryIcon.fromIcon(Icons.manage_search, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'سجلات البحث',
            style: mediumStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '${_records.length} سجل',
          style: smallStyle(color: accentColor.withOpacity(0.72)),
        ),
      ],
    );
  }

  Widget _recordsCard() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.fromBorderSide(AppChrome.borderSide()),
      ),
      child: _records.isEmpty
          ? _emptyState()
          : ListView.separated(
              itemCount: _records.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: borderColor,
              ),
              itemBuilder: (context, index) => _recordTile(_records[index]),
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Text(
        'لا توجد سجلات بحث بعد',
        style: normalStyle(color: accentColor.withOpacity(0.68), fontSize: 14),
      ),
    );
  }

  Widget _recordTile(SearchHistoryRecord record) {
    final selected = _selectedRecordId == record.id;
    final details = _recordDetails(record);
    return InkWell(
      onTap: () {
        setState(() => _selectedRecordId = record.id);
        widget.onRecordSelected(record, runSearch: false);
      },
      onDoubleTap: () => widget.onRecordSelected(record, runSearch: true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? organicHighlightColor : surfaceColor,
          border: Border(
            right: BorderSide(
              color: selected ? primaryColor : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            LibraryIcon.fromIcon(
              Icons.history,
              color: selected ? actionColor : accentColor.withOpacity(0.68),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: normalStyle(
                      fontSize: 14,
                      color: selected ? primaryColor : accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  ...details.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line,
                        style: smallStyle(
                          fontSize: 11,
                          color: accentColor.withOpacity(0.68),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: record.id,
              groupValue: _selectedRecordId,
              activeColor: primaryColor,
              onChanged: (value) => setState(() => _selectedRecordId = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsBar() {
    final selectedRecord = _selectedRecord;
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: AppChrome.borderSide()),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: selectedRecord == null ? null : _deleteSelectedRecord,
            icon: const LibraryIcon(LibraryIconType.remove, size: 18),
            label: Text('إزالة', style: normalStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: destructiveColor,
              side: BorderSide(color: destructiveColor.withOpacity(0.28)),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            ),
          ),
          const SizedBox(width: 18),
          ElevatedButton.icon(
            onPressed: selectedRecord == null
                ? null
                : () => widget.onRecordSelected(
                      selectedRecord,
                      runSearch: true,
                    ),
            icon: const LibraryIcon(LibraryIconType.play, size: 18),
            label: Text(
              'إعادة البحث',
              style: normalStyle(fontSize: 12, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _recordDetails(SearchHistoryRecord record) {
    return SearchSummaryFormatter.lines(
      groupQueries: record.groupQueries,
      searchGrouping: record.searchGrouping,
      searchSections: record.searchSections,
      options: record.options,
      scopeItems: record.scopeItems,
    );
  }

  SearchHistoryRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedRecordId) return record;
    }
    return null;
  }

  Future<void> _deleteSelectedRecord() async {
    final id = _selectedRecordId;
    if (id == null) return;
    final records = await _store.deleteRecord(id);
    if (!mounted) return;
    setState(() {
      _records = records;
      _selectedRecordId = null;
    });
  }
}
