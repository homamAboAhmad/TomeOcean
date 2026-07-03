import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_search_field.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';

class ChapterSidebar extends StatefulWidget {
  final List<ChapterInfo> chapters;
  final int selectedChapterNumber;
  final int selectedPassageNumber;
  final int selectedJuzNumber;
  final int selectedHizbNumber;
  final int selectedQuarterNumber;
  final int selectedPageNumber;
  final ValueChanged<ChapterInfo> onSelected;
  final ValueChanged<int> onPassageSelected;
  final ValueChanged<int> onJuzSelected;
  final ValueChanged<int> onHizbSelected;
  final ValueChanged<int> onQuarterSelected;
  final ValueChanged<int> onPageSelected;

  const ChapterSidebar({
    super.key,
    required this.chapters,
    required this.selectedChapterNumber,
    required this.selectedPassageNumber,
    required this.selectedJuzNumber,
    required this.selectedHizbNumber,
    required this.selectedQuarterNumber,
    required this.selectedPageNumber,
    required this.onSelected,
    required this.onPassageSelected,
    required this.onJuzSelected,
    required this.onHizbSelected,
    required this.onQuarterSelected,
    required this.onPageSelected,
  });

  @override
  State<ChapterSidebar> createState() => _ChapterSidebarState();
}

class _ChapterSidebarState extends State<ChapterSidebar> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _filteredChapters();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LibraryDesignTokens.sidebar,
        border: Border(left: BorderSide(color: LibraryDesignTokens.divider)),
      ),
      child: Column(
        children: [
          LibrarySearchField(
            controller: _search,
            hint: 'بحث في السور',
            onChanged: (_) => setState(() {}),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chapters.length,
              itemExtent: LibraryDesignTokens.rowHeight,
              itemBuilder: (context, index) => _row(chapters[index]),
            ),
          ),
          const Divider(height: 1, color: LibraryDesignTokens.divider),
          _navigationControls(),
        ],
      ),
    );
  }

  Widget _row(ChapterInfo chapter) {
    final selected = chapter.number == widget.selectedChapterNumber;
    return InkWell(
      onTap: () => widget.onSelected(chapter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerRight,
        color: selected ? LibraryDesignTokens.selected : null,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '[${chapter.number}]',
                style: smallStyle(fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              child: Text(
                chapter.name,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: normalStyle(fontSize: 12, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ChapterInfo> _filteredChapters() {
    final query = LibraryTextNormalizer.normalize(_search.text);
    if (query.isEmpty) return widget.chapters;
    return widget.chapters.where((chapter) {
      return LibraryTextNormalizer.normalize(chapter.name).contains(query);
    }).toList();
  }

  Widget _navigationControls() {
    final selectedChapter = widget.chapters.firstWhere(
      (chapter) => chapter.number == widget.selectedChapterNumber,
      orElse: () => widget.chapters.first,
    );
    final passageCount = selectedChapter.totalPassages.clamp(1, 400).toInt();
    return Container(
      color: const Color(0xFFF4F4F4),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        children: [
          _groupTitle('الآية: [1 - $passageCount]'),
          _dropdownRow(
            widget.selectedPassageNumber.clamp(1, passageCount).toInt(),
            passageCount,
            widget.onPassageSelected,
          ),
          _groupTitle('الأجزاء والأرباع'),
          _dropdownRow(
            widget.selectedJuzNumber,
            30,
            widget.onJuzSelected,
            display: (number) => 'الجزء : $number',
          ),
          _dropdownRow(
            widget.selectedHizbNumber,
            60,
            widget.onHizbSelected,
            display: _hizbLabel,
          ),
          _dropdownRow(
            widget.selectedQuarterNumber.clamp(1, 4).toInt(),
            4,
            widget.onQuarterSelected,
            display: _quarterLabel,
          ),
          _groupTitle('الصفحات [1 - 604]'),
          _dropdownRow(widget.selectedPageNumber, 604, widget.onPageSelected),
        ],
      ),
    );
  }

  Widget _groupTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          const Expanded(child: Divider(color: LibraryDesignTokens.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(text, style: smallStyle(fontSize: 12)),
          ),
          const Expanded(child: Divider(color: LibraryDesignTokens.divider)),
        ],
      ),
    );
  }

  Widget _dropdownRow(
    int value,
    int count,
    ValueChanged<int> onChanged, {
    String Function(int number)? display,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: SizedBox(
        width: double.infinity,
        height: 28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value.clamp(1, count).toInt(),
              isExpanded: true,
              isDense: true,
              alignment: Alignment.centerRight,
              style: normalStyle(fontSize: 12),
              items: List.generate(count, (index) => index + 1).map((number) {
                return DropdownMenuItem<int>(
                  value: number,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(display?.call(number) ?? '$number'),
                  ),
                );
              }).toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ),
    );
  }

  String _hizbLabel(int number) {
    const names = ['الأول', 'الثاني', 'الثالث', 'الرابع'];
    return 'الحزب ${names[(number - 1) % names.length]}';
  }

  String _quarterLabel(int number) {
    const names = ['الأول', 'الثاني', 'الثالث', 'الرابع'];
    return 'الربع ${names[number - 1]}';
  }
}
