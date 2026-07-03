import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/SavedItems/helpers/work_session_store.dart';
import 'package:golden_shamela/UI/SavedItems/models/work_session_record.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_items_confirm.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/work_session_tile.dart';

class PreviousWorkSessionsTab extends StatefulWidget {
  final ValueChanged<WorkSessionRecord> onOpenSession;

  const PreviousWorkSessionsTab({
    super.key,
    required this.onOpenSession,
  });

  @override
  State<PreviousWorkSessionsTab> createState() =>
      _PreviousWorkSessionsTabState();
}

class _PreviousWorkSessionsTabState extends State<PreviousWorkSessionsTab> {
  final _store = WorkSessionStore();
  List<WorkSessionRecord> _sessions = const [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _sessions = _store.loadPreviousSessions();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSession;
    return Column(
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'حذف جلسة العمل المحددة من القائمة',
                onPressed: selected == null ? null : _deleteSelected,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                icon: Icons.cleaning_services_outlined,
                label: 'تفريغ القائمة',
                onPressed: _sessions.isEmpty ? null : _clearAll,
              ),
            ],
          ),
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
                      onTap: () => setState(() => _selectedId = session.id),
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
        'لا توجد جلسات عمل سابقة',
        style: normalStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final selected = _selectedSession;
    if (selected == null) return;
    final confirmed = await confirmSavedItemAction(
      context,
      title: 'حذف جلسة سابقة',
      message: 'هل تريد حذف "${selected.name}" من قائمة الجلسات السابقة؟',
    );
    if (!confirmed) return;
    final sessions = await _store.deletePreviousSession(selected.id);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _selectedId = null;
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await confirmSavedItemAction(
      context,
      title: 'تفريغ القائمة',
      message: 'سيتم حذف كل جلسات العمل السابقة من هذه القائمة.',
    );
    if (!confirmed) return;
    final sessions = await _store.clearPreviousSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _selectedId = null;
    });
  }

  WorkSessionRecord? get _selectedSession {
    for (final session in _sessions) {
      if (session.id == _selectedId) return session;
    }
    return null;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: LibraryIcon.fromIcon(icon, size: 16, color: primaryColor),
      label: Text(label, style: smallStyle(color: Colors.black87)),
    );
  }
}
