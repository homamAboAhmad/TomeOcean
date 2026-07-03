import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Search/helpers/saved_search_scope_store.dart';
import 'package:golden_shamela/UI/Search/helpers/search_summary_formatter.dart';
import 'package:golden_shamela/UI/Search/models/saved_search_scope.dart';
import 'package:golden_shamela/UI/Search/models/search_state_snapshot.dart';

class SavedScopesPanel extends StatefulWidget {
  final List<Map<String, dynamic>> currentItems;
  final SearchStateSnapshot currentSnapshot;
  final ValueChanged<List<Map<String, dynamic>>> onScopeApplied;

  const SavedScopesPanel({
    super.key,
    required this.currentItems,
    required this.currentSnapshot,
    required this.onScopeApplied,
  });

  @override
  State<SavedScopesPanel> createState() => _SavedScopesPanelState();
}

class _SavedScopesPanelState extends State<SavedScopesPanel> {
  final _store = SavedSearchScopeStore();
  final _nameController = TextEditingController();
  List<SavedSearchScope> _scopes = const [];
  String? _selectedScopeId;

  @override
  void initState() {
    super.initState();
    _scopes = _store.loadScopes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
          _saveCurrentScopeCard(),
          const SizedBox(height: 14),
          Expanded(child: _savedScopesCard()),
          const SizedBox(height: 12),
          _actionsBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        LibraryIcon.fromIcon(Icons.description_outlined, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'المجالات المحفوظة',
            style: mediumStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '${widget.currentItems.length} عنصر في المجال الحالي',
          style: smallStyle(color: accentColor.withOpacity(0.72)),
        ),
      ],
    );
  }

  Widget _saveCurrentScopeCard() {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'اسم المجال، مثل: كتب التفسير المشهورة',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: LibraryIcon.fromIcon(Icons.edit_note, color: actionColor),
              ),
              style: normalStyle(fontSize: 13),
              onSubmitted: (_) => _saveCurrentScope(),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: widget.currentItems.isEmpty ? null : _saveCurrentScope,
            icon: const LibraryIcon(LibraryIconType.save, size: 18),
            label: Text(
              'حفظ المجال',
              style: normalStyle(fontSize: 12, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedScopesCard() {
    return _card(
      child: _scopes.isEmpty
          ? _emptyState()
          : ListView.separated(
              itemCount: _scopes.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: borderColor,
              ),
              itemBuilder: (context, index) => _scopeTile(_scopes[index]),
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Text(
        'لا توجد مجالات محفوظة بعد',
        style: normalStyle(color: accentColor.withOpacity(0.68), fontSize: 14),
      ),
    );
  }

  Widget _scopeTile(SavedSearchScope scope) {
    final selected = _selectedScopeId == scope.id;
    final details = _scopeDetails(scope);
    return InkWell(
      onTap: () => setState(() => _selectedScopeId = scope.id),
      onDoubleTap: () => widget.onScopeApplied(scope.items),
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
              Icons.folder_special_outlined,
              color: selected ? actionColor : accentColor.withOpacity(0.68),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scope.name,
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
              value: scope.id,
              groupValue: _selectedScopeId,
              activeColor: primaryColor,
              onChanged: (value) => setState(() => _selectedScopeId = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsBar() {
    final selectedScope = _selectedScope;
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
            onPressed: selectedScope == null ? null : _deleteSelectedScope,
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
            onPressed: selectedScope == null
                ? null
                : () => widget.onScopeApplied(selectedScope.items),
            icon: const LibraryIcon(LibraryIconType.check, size: 18),
            label: Text(
              'اختيار المجال',
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

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        border: Border.fromBorderSide(AppChrome.borderSide()),
        boxShadow: AppChrome.softShadow,
      ),
      child: child,
    );
  }

  List<String> _scopeDetails(SavedSearchScope scope) {
    return SearchSummaryFormatter.lines(
      groupQueries: scope.searchSnapshot.groupQueries,
      searchGrouping: scope.searchSnapshot.searchGrouping,
      searchSections: scope.searchSnapshot.searchSections,
      options: scope.searchSnapshot.options,
      scopeItems: scope.items,
    );
  }

  SavedSearchScope? get _selectedScope {
    for (final scope in _scopes) {
      if (scope.id == _selectedScopeId) return scope;
    }
    return null;
  }

  Future<void> _saveCurrentScope() async {
    final scopes = await _store.saveScope(
      name: _nameController.text,
      items: widget.currentItems,
      searchSnapshot: widget.currentSnapshot,
    );
    if (!mounted) return;
    setState(() {
      _scopes = scopes;
      _selectedScopeId = scopes.isEmpty ? null : scopes.first.id;
      _nameController.clear();
    });
  }

  Future<void> _deleteSelectedScope() async {
    final id = _selectedScopeId;
    if (id == null) return;
    final scopes = await _store.deleteScope(id);
    if (!mounted) return;
    setState(() {
      _scopes = scopes;
      _selectedScopeId = null;
    });
  }
}
