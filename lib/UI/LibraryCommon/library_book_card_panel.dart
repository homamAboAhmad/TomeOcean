import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'library_book_item.dart';
import 'library_design_tokens.dart';
import 'library_icon.dart';

class LibraryBookCardPanel extends StatefulWidget {
  final LibraryBookItem? item;

  const LibraryBookCardPanel({super.key, required this.item});

  @override
  State<LibraryBookCardPanel> createState() => _LibraryBookCardPanelState();
}

class _LibraryBookCardPanelState extends State<LibraryBookCardPanel> {
  bool _showAuthor = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2EEDC),
        border: const Border(
          top: BorderSide(color: LibraryDesignTokens.divider),
        ),
      ),
      child: Column(
        children: [
          _tabs(),
          Expanded(
            child: item == null
                ? const Center(child: Text('اختر كتابًا لعرض البطاقة'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _showAuthor ? _authorCard(item) : _bookCard(item),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      height: 34,
      alignment: Alignment.centerRight,
      color: LibraryDesignTokens.surface,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          _tab('الكتاب', Icons.book, !_showAuthor, () {
            setState(() => _showAuthor = false);
          }),
          _tab('المؤلف', Icons.history_edu, _showAuthor, () {
            setState(() => _showAuthor = true);
          }),
        ],
      ),
    );
  }

  Widget _tab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? LibraryDesignTokens.selected : Colors.transparent,
          border: selected
              ? Border.all(color: LibraryDesignTokens.selectedBorder)
              : null,
        ),
        child: Row(
          children: [
            LibraryIcon.fromIcon(icon, size: 17),
            const SizedBox(width: 5),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _bookCard(LibraryBookItem item) {
    final book = item.book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line('الكتاب', book.title, strong: true),
        _line('المؤلف', item.authorDisplay),
        _line('القسم', item.sectionTitle),
        const Divider(),
        _line('النوع', BookMetadataOptions.typeLabel(book.bookType)),
        _line(
          'التقييم',
          book.matchesPrinted == true
              ? 'موافق للمطبوع'
              : 'غير موافق للمطبوع',
        ),
        if (book.publisher.isNotEmpty) _line('الناشر', book.publisher),
        if (book.edition.isNotEmpty) _line('الطبعة', book.edition),
        if (book.pageCount.isNotEmpty) _line('عدد الصفحات', book.pageCount),
        if (book.description.isNotEmpty) _line('نبذة عن الكتاب', book.description),
      ],
    );
  }

  Widget _authorCard(LibraryBookItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line('المؤلف', item.authorName, strong: true),
        _line('الوفاة', item.authorDeathYear),
        const Divider(),
        _line('البطاقة', item.authorDescription),
      ],
    );
  }

  Widget _line(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: AppUiFonts.style(
            AppFontRole.bookCard,
            TextStyle(
            color: Colors.black,
            fontSize: strong ? 17 : 15,
            fontWeight: strong ? FontWeight.bold : FontWeight.normal,
            ),
            sizeOffset: strong ? 2 : 0,
            fontWeight: strong ? FontWeight.bold : null,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: value.isEmpty ? 'غير محدد' : value),
          ],
        ),
      ),
    );
  }
}
