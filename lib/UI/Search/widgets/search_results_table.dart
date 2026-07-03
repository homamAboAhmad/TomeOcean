import 'package:flutter/material.dart';

import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'search_result_highlight_text.dart';

class ShamelaResultsTopBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final bool isSearching;
  final bool resultsHidden;
  final VoidCallback? onStopSearch;
  final VoidCallback? onNewSearchDialog;
  final VoidCallback? onToggleResults;

  const ShamelaResultsTopBar({
    super.key,
    required this.count,
    required this.totalCount,
    required this.isSearching,
    required this.resultsHidden,
    required this.onStopSearch,
    required this.onNewSearchDialog,
    required this.onToggleResults,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTotal = totalCount > count ? totalCount : count;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(bottom: AppChrome.borderSide()),
      ),
      child: Row(
        children: [
          LibraryIcon.fromIcon(Icons.search, color: primaryColor, size: 22),
          const SizedBox(width: 8),
          Text('نتائج البحث', style: mediumStyle(color: primaryColor)),
          const Spacer(),
          if (isSearching) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text('$visibleTotal نتيجة', style: smallStyle()),
          if (onToggleResults != null)
            IconButton(
              tooltip: resultsHidden ? 'إظهار النتائج' : 'إخفاء النتائج',
              onPressed: onToggleResults,
              icon: LibraryIcon.fromIcon(
                resultsHidden ? Icons.view_list : Icons.fullscreen,
                color: primaryColor,
                size: 22,
              ),
            ),
          if (onNewSearchDialog != null)
            IconButton(
              tooltip: 'بحث جديد',
              onPressed: onNewSearchDialog,
              icon: LibraryIcon.fromIcon(Icons.search, color: primaryColor, size: 22),
            ),
          if (isSearching && onStopSearch != null)
            IconButton(
              tooltip: 'إيقاف البحث',
              onPressed: onStopSearch,
              icon: LibraryIcon.fromIcon(Icons.cancel, color: Colors.red.shade700, size: 20),
            ),
        ],
      ),
    );
  }
}

class ShamelaResultPreviewPane extends StatelessWidget {
  final String queryLabel;
  final Map<String, dynamic>? previewResult;
  final String Function(String) snippetBuilder;
  final bool isSearching;
  final bool hasResults;

  const ShamelaResultPreviewPane({
    super.key,
    required this.queryLabel,
    required this.previewResult,
    required this.snippetBuilder,
    required this.isSearching,
    required this.hasResults,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: surfaceColor,
      padding: const EdgeInsets.all(18),
      child: Align(
        alignment: Alignment.topRight,
        child: hasResults ? _buildPreview() : _buildMessage(),
      ),
    );
  }

  Widget _buildMessage() {
    return Text(
      _message,
      style: normalStyle(color: accentColor.withOpacity(0.76), fontSize: 14),
    );
  }

  Widget _buildPreview() {
    final result = previewResult ?? const <String, dynamic>{};
    final title = (result['bookTitle'] ?? result['book_name'])?.toString() ?? '';
    final content = snippetBuilder(
      (result['raw_content'] ?? result['content'])?.toString() ?? '',
    );

    final titleColor = AppUiColors.color(AppColorRole.titles);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title.isEmpty ? _message : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppUiFonts.style(
            AppFontRole.searchResults,
            normalStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            ),
            sizeOffset: 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: AppUiFonts.style(
            AppFontRole.searchResults,
            normalStyle(fontSize: 15, height: 1.6),
            sizeOffset: 3,
          ),
        ),
      ],
    );
  }

  String get _message {
    if (isSearching && !hasResults) return 'جاري البحث...';
    if (hasResults) {
      return queryLabel.isEmpty ? 'نتائج البحث' : 'بحث: $queryLabel';
    }
    return 'لا توجد نتائج لعرضها';
  }
}

class ShamelaResultsTableHeader extends StatelessWidget {
  const ShamelaResultsTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(
          top: AppChrome.borderSide(),
          bottom: AppChrome.borderSide(),
        ),
      ),
      child: Row(
        children: const [
          _HeaderCell('مسلسل', width: 58),
          _HeaderCell('الكتاب', width: 280),
          _HeaderCell('النص', flex: 1),
          _HeaderCell('الباب', width: 180),
          _HeaderCell('الصفحة', width: 82),
        ],
      ),
    );
  }
}

class ShamelaResultsTableRow extends StatelessWidget {
  final int serial;
  final Map<String, dynamic> result;
  final bool selected;
  final String Function(String) snippetBuilder;
  final List<String> searchQueries;
  final VoidCallback onOpen;
  final VoidCallback? onDoubleOpen;

  const ShamelaResultsTableRow({
    super.key,
    required this.serial,
    required this.result,
    this.selected = false,
    required this.snippetBuilder,
    this.searchQueries = const [],
    required this.onOpen,
    this.onDoubleOpen,
  });

  @override
  Widget build(BuildContext context) {
    final bookName =
        (result['bookTitle'] ?? result['book_name'])?.toString() ?? '';
    final content = snippetBuilder(result['content']?.toString() ?? '');
    final pageNumber =
        (result['pageNumber'] ?? result['page_number'])?.toString() ?? '';
    final section = _sectionLabel(result['section_title'] ?? result['section_type']);
    final isComment = result['section_type']?.toString() == 'comment';
    final iconColor = isComment
        ? AppUiColors.color(AppColorRole.comments)
        : const Color(0xFF7A7700);

    return InkWell(
      onTap: onOpen,
      onDoubleTap: onDoubleOpen ?? onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? organicHighlightColor
              : serial.isOdd
                  ? surfaceColor
                  : bgColor.withOpacity(0.58),
          border: Border(bottom: AppChrome.borderSide(opacity: 0.55)),
        ),
        child: Row(
          children: [
            _BodyCell(serial.toString(), width: 58, color: accentColor.withOpacity(0.72)),
            _BodyCell(
              bookName,
              width: 280,
              icon: isComment ? Icons.comment_outlined : Icons.book,
              iconColor: iconColor,
            ),
            _BodyCell(content, flex: 1, searchQueries: searchQueries),
            _BodyCell(section, width: 180),
            _BodyCell(pageNumber, width: 82, color: primaryColor),
          ],
        ),
      ),
    );
  }

  String _sectionLabel(dynamic value) {
    final raw = value?.toString() ?? '';
    switch (raw) {
      case 'main':
        return 'المتن';
      case 'footnote':
        return 'الحواشي';
      case 'title':
        return 'العناوين';
      case 'comment':
        return 'التعليقات';
      default:
        return raw;
    }
  }
}

class ShamelaResultsFooter extends StatelessWidget {
  final int count;
  final int totalCount;
  final bool isSearching;
  final Widget? trailing;

  const ShamelaResultsFooter({
    super.key,
    required this.count,
    required this.totalCount,
    required this.isSearching,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTotal = totalCount > count ? totalCount : count;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: mutedColor,
        border: Border(top: AppChrome.borderSide()),
      ),
      child: Row(
        children: [
          Text(
            isSearching ? 'يعرض $count من $visibleTotal' : 'النتائج: $visibleTotal',
            style: smallStyle(),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
          if (trailing != null) const SizedBox(width: 8),
          LibraryIcon.fromIcon(Icons.search, color: primaryColor, size: 18),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double? width;
  final int? flex;

  const _HeaderCell(this.text, {this.width, this.flex});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(left: AppChrome.borderSide(opacity: 0.65)),
      ),
      child: Text(
        text,
        style: AppUiFonts.style(
          AppFontRole.searchResults,
          smallStyle(fontWeight: FontWeight.bold),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    if (flex != null) return Expanded(flex: flex!, child: child);
    return SizedBox(width: width, child: child);
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final double? width;
  final int? flex;
  final Color? color;
  final IconData? icon;
  final Color? iconColor;
  final List<String> searchQueries;

  const _BodyCell(
    this.text, {
    this.width,
    this.flex,
    this.color,
    this.icon,
    this.iconColor,
    this.searchQueries = const [],
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(left: AppChrome.borderSide(opacity: 0.65)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            LibraryIcon.fromIcon(icon!, size: 15, color: iconColor ?? actionColor),
            const SizedBox(width: 4),
          ],
          Expanded(child: _text()),
        ],
      ),
    );
    if (flex != null) return Expanded(flex: flex!, child: child);
    return SizedBox(width: width, child: child);
  }

  Widget _text() {
    final style = AppUiFonts.style(
      AppFontRole.searchResults,
      smallStyle(color: color ?? accentColor),
    );
    return SearchResultHighlightText(
      text: text,
      queries: searchQueries,
      baseStyle: style,
    );
  }
}
