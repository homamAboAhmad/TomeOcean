import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/SavedItems/models/saved_search_results_record.dart';
import 'package:golden_shamela/UI/SavedItems/models/work_session_record.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/previous_work_sessions_tab.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_search_results_tab.dart';
import 'package:golden_shamela/UI/SavedItems/widgets/saved_work_sessions_tab.dart';

class SavedItemsDialog extends StatelessWidget {
  final WorkSessionRecord Function(String name) createCurrentSession;
  final ValueChanged<WorkSessionRecord> onOpenSession;
  final ValueChanged<SavedSearchResultsRecord> onOpenResults;

  const SavedItemsDialog({
    super.key,
    required this.createCurrentSession,
    required this.onOpenSession,
    required this.onOpenResults,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.all(26),
        child: SizedBox(
          width: 760,
          height: 720,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _titleBar(context),
                _tabs(),
                Expanded(
                  child: TabBarView(
                    children: [
                      PreviousWorkSessionsTab(onOpenSession: onOpenSession),
                      SavedWorkSessionsTab(
                        createCurrentSession: createCurrentSession,
                        onOpenSession: onOpenSession,
                      ),
                      SavedSearchResultsTab(
                        onOpenResults: onOpenResults,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(bottom: AppChrome.borderSide()),
      ),
      child: Row(
        children: [
          LibraryIcon.fromIcon(Icons.folder_special_outlined, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'المكتبة الشاملة - المحفوظات',
              style: normalStyle(fontSize: 13, color: accentColor),
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            padding: EdgeInsets.zero,
            icon: const LibraryIcon(LibraryIconType.close, size: 19),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      height: 52,
      color: bgColor,
      child: TabBar(
        labelColor: primaryColor,
        unselectedLabelColor: accentColor.withOpacity(0.72),
        indicatorColor: actionColor,
        labelStyle: smallStyle(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: smallStyle(fontSize: 12),
        tabs: [
          _tab(Icons.history, 'جلسات العمل السابقة'),
          _tab(Icons.save, 'جلسات العمل المحفوظة'),
          _tab(Icons.manage_search, 'نتائج البحث المحفوظة'),
        ],
      ),
    );
  }

  Widget _tab(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LibraryIcon.fromIcon(icon, size: 18),
          const SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }
}

Future<void> showSavedItemsDialog({
  required BuildContext context,
  required WorkSessionRecord Function(String name) createCurrentSession,
  required ValueChanged<WorkSessionRecord> onOpenSession,
  required ValueChanged<SavedSearchResultsRecord> onOpenResults,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => SavedItemsDialog(
      createCurrentSession: createCurrentSession,
      onOpenSession: onOpenSession,
      onOpenResults: onOpenResults,
    ),
  );
}
