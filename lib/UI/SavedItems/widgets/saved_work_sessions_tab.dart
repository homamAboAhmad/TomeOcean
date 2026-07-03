import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/SavedItems/helpers/work_session_store.dart';
import 'package:golden_shamela/UI/SavedItems/models/work_session_record.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_items_confirm.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_items_toolbar.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/work_session_tile.dart';

class SavedWorkSessionsTab extends StatefulWidget {
  final WorkSessionRecord Function(String name) createCurrentSession;
  final ValueChanged<WorkSessionRecord> onOpenSession;

  const SavedWorkSessionsTab({
    super.key,
    required this.createCurrentSession,
    required this.onOpenSession,
  });

  @override
  State<SavedWorkSessionsTab> createState() => _SavedWorkSessionsTabState();
}

class _SavedWorkSessionsTabState extends State<SavedWorkSessionsTab> {
  final _store = WorkSessionStore();
  final _nameController = TextEditingController();
  List<WorkSessionRecord> _sessions = const [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _sessions = _store.loadSavedSessions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSession;
    return Column(
      children: [
        SavedItemsToolbar(
          nameController: _nameController,
          hintText: 'اسم جلسة العمل',
          saveTooltip: 'حفظ جلسة العمل الحالية',
          onSave: _saveCurrentSession,
          onRename: selected == null ? null : _renameSelected,
          onMoveUp: selected == null ? null : () => _moveSelected(-1),
          onMoveDown: selected == null ? null : () => _moveSelected(1),
          onDelete: selected == null ? null : _deleteSelected,
        ),
        Expanded(
          child: _sessions.isEmpty
              ? _emptyState()
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return WorkSessionTile(
                      session: session,
                      selected: session.id == _selectedId,
                      onTap: () {
                        setState(() {
                          _selectedId = session.id;
                          _nameController.text = session.name;
                        });
                      },
                      onOpen: () => widget.onOpenSession(session),
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
        'لا توجد جلسات عمل محفوظة',
        style: normalStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    );
  }

  Future<void> _saveCurrentSession() async {
    final session = widget.createCurrentSession(_nameController.text);
    final sessions = await _store.saveSession(session);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _selectedId = session.id;
    });
  }

  Future<void> _renameSelected() async {
    final selected = _selectedSession;
    if (selected == null) return;
    final sessions = await _store.renameSavedSession(
      selected.id,
      _nameController.text,
    );
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  Future<void> _moveSelected(int direction) async {
    final selected = _selectedSession;
    if (selected == null) return;
    final sessions = await _store.moveSavedSession(selected.id, direction);
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  Future<void> _deleteSelected() async {
    final selected = _selectedSession;
    if (selected == null) return;
    final confirmed = await confirmSavedItemAction(
      context,
      title: 'حذف جلسة محفوظة',
      message: 'هل تريد حذف "${selected.name}"؟',
    );
    if (!confirmed) return;
    final sessions = await _store.deleteSavedSession(selected.id);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _selectedId = null;
      _nameController.clear();
    });
  }

  WorkSessionRecord? get _selectedSession {
    for (final session in _sessions) {
      if (session.id == _selectedId) return session;
    }
    return null;
  }
}
