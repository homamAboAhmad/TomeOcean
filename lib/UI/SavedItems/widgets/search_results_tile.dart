import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/SavedItems/models/saved_search_results_record.dart';

class SearchResultsTile extends StatelessWidget {
  final SavedSearchResultsRecord result;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const SearchResultsTile({
    super.key,
    required this.result,
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
                LibraryIcon.fromIcon(Icons.manage_search, size: 16, color: actionColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    result.name,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: normalStyle(fontSize: 13, color: accentColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'عدد النتائج: ${_visibleTotal()}',
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

  int _visibleTotal() {
    return result.totalCount > result.results.length
        ? result.totalCount
        : result.results.length;
  }

  List<String> _details() {
    final lines = <String>[];
    final groups = result.searchSnapshot.groupQueries;
    final andWords = _words(groups['and']);
    final orWords = _words(groups['or']);
    final notWords = _words(groups['not']);
    if (andWords.isNotEmpty) lines.add('كل الكلمات: $andWords');
    if (orWords.isNotEmpty) lines.add('إحدى الكلمات: $orWords');
    if (notWords.isNotEmpty) lines.add('استبعاد: $notWords');
    if (lines.isEmpty && result.searchQueries.isNotEmpty) {
      lines.add('الكلمات: ${result.searchQueries.join('، ')}');
    }

    final sections = result.searchSnapshot.searchSections.entries
        .where((entry) => entry.value)
        .map((entry) => _sectionLabel(entry.key))
        .where((label) => label.isNotEmpty)
        .join('، ');
    if (sections.isNotEmpty) lines.add('المجالات: $sections');

    final options = <String>[];
    if (result.morphologicalSearch) options.add('صرفي');
    result.searchSnapshot.options.forEach((key, value) {
      if (value) options.add(_optionLabel(key));
    });
    if (options.isNotEmpty) lines.add('الخيارات: ${options.join('، ')}');
    return lines.take(5).toList();
  }

  String _words(List<String>? values) {
    final words = values
            ?.map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const [];
    return words.join('، ');
  }

  String _sectionLabel(String key) {
    return switch (key) {
      'main' => 'المتن',
      'footnote' => 'الحواشي',
      'comment' => 'التعليقات',
      'title' => 'العناوين',
      _ => key,
    };
  }

  String _optionLabel(String key) {
    return switch (key) {
      'affixSearch' => 'لواحق وسوابق',
      'considerHamzas' => 'اعتبار الهمزات',
      'considerDiacritics' => 'اعتبار التشكيل',
      'considerNumbers' => 'اعتبار الأرقام',
      'allPhrasesRequired' => 'كل العبارات',
      'ordered' => 'مرتبة',
      'proximity' => 'متقاربة',
      _ => key,
    };
  }
}
