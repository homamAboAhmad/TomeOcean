import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/SavedItems/models/work_session_record.dart';

class WorkSessionTile extends StatelessWidget {
  final WorkSessionRecord session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const WorkSessionTile({
    super.key,
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? organicHighlightColor : surfaceColor,
          border: Border(
            bottom: AppChrome.borderSide(),
            right: BorderSide(
              color: selected ? actionColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                LibraryIcon.fromIcon(Icons.folder_open, size: 16, color: actionColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.name,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: normalStyle(fontSize: 13, color: accentColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '[عدد التبويبات: ${session.tabCount}]',
                  style: smallStyle(color: accentColor.withOpacity(0.72), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._details().map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: smallStyle(color: accentColor.withOpacity(0.82), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _details() {
    final lines = <String>[];
    for (final book in session.books.take(5)) {
      final title = book.title.trim().isNotEmpty
          ? book.title
          : AppStoragePaths.displayTitleFromPath(book.bookPath);
      lines.add('كتاب: $title');
    }
    for (final tab in session.searchTabs.take(3)) {
      final label = tab.searchQueries.isEmpty
          ? tab.title
          : tab.searchQueries.join('، ');
      lines.add('بحث: $label');
    }
    if (session.tabCount > lines.length) {
      lines.add('وتبويبات أخرى: ${session.tabCount - lines.length}');
    }
    return lines.isEmpty ? const ['لا توجد تفاصيل محفوظة'] : lines;
  }
}
