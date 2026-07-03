import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';

class ReaderNavigationBar extends StatelessWidget {
  final String chapterName;
  final int currentPageNumber;
  final int maxPageNumber;
  final int currentJuzNumber;
  final List<RecitedTextFontOption> fontOptions;
  final RecitedTextFontOption selectedFontOption;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<RecitedTextFontOption?> onFontChanged;
  final ValueChanged<String> onTopSearchSubmitted;
  final VoidCallback onCopyWithReference;
  final VoidCallback onOpenCopyFontSettings;
  final bool isTafsirVisible;
  final bool isSearchVisible;
  final VoidCallback onToggleTafsir;
  final VoidCallback onToggleSearch;
  final VoidCallback onIncreaseFontSize;
  final VoidCallback onDecreaseFontSize;

  const ReaderNavigationBar({
    super.key,
    required this.chapterName,
    required this.currentPageNumber,
    required this.maxPageNumber,
    required this.currentJuzNumber,
    required this.fontOptions,
    required this.selectedFontOption,
    required this.searchController,
    required this.searchFocusNode,
    required this.onPageSelected,
    required this.onFontChanged,
    required this.onTopSearchSubmitted,
    required this.onCopyWithReference,
    required this.onOpenCopyFontSettings,
    required this.isTafsirVisible,
    required this.isSearchVisible,
    required this.onToggleTafsir,
    required this.onToggleSearch,
    required this.onIncreaseFontSize,
    required this.onDecreaseFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = currentPageNumber > 1;
    final canGoForward = currentPageNumber < maxPageNumber;
    return Container(
      height: 38,
      color: LibraryDesignTokens.header,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _group([
            _toggleButton(isTafsirVisible ? 'إخفاء التفسير' : 'إظهار التفسير', isTafsirVisible ? Icons.article : Icons.article_outlined, isTafsirVisible, onToggleTafsir),
            _toggleButton(isSearchVisible ? 'إخفاء البحث' : 'إظهار البحث', isSearchVisible ? Icons.view_list : Icons.view_list_outlined, isSearchVisible, onToggleSearch),
            _fontSizeButton('A+', 'تكبير الخط', onIncreaseFontSize),
            _fontSizeButton('A-', 'تصغير الخط', onDecreaseFontSize),
          ]),
          const SizedBox(width: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: _group([
              _navButton(Icons.first_page, canGoForward, () => onPageSelected(maxPageNumber)),
              _navButton(Icons.navigate_before, canGoForward, () => onPageSelected(currentPageNumber + 1)),
              _labelBox('$currentPageNumber', width: 58),
              _navButton(Icons.navigate_next, canGoBack, () => onPageSelected(currentPageNumber - 1)),
              _navButton(Icons.last_page, canGoBack, () => onPageSelected(1)),
            ]),
          ),
          const SizedBox(width: 8),
          _group([
            _labelBox('سورة: $chapterName', width: 132),
            const SizedBox(width: 6),
            _labelBox('الجزء: $currentJuzNumber', width: 96),
          ]),
          const Spacer(),
          _topSearchField(),
          const SizedBox(width: 8),
          _fontSelector(),
          const SizedBox(width: 8),
          _group([
            _plainButton('نسخ الصفحة مع العزو', Icons.copy, onCopyWithReference),
            _plainButton('إعداد خط نسخ الآية', Icons.text_fields, onOpenCopyFontSettings),
          ]),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          border: Border.all(color: LibraryDesignTokens.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _navButton(IconData icon, bool enabled, VoidCallback onPressed) {
    return IconButton(
      icon: LibraryIcon.fromIcon(
        icon,
        size: 18,
        color: enabled ? LibraryDesignTokens.icon : LibraryDesignTokens.icon.withOpacity(0.35),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 30),
      onPressed: enabled ? onPressed : null,
    );
  }

  Widget _toggleButton(String tooltip, IconData icon, bool selected, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: LibraryIcon.fromIcon(
        icon,
        size: 18,
        color: selected ? LibraryDesignTokens.primary : LibraryDesignTokens.icon,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      style: IconButton.styleFrom(
        backgroundColor: selected ? LibraryDesignTokens.primary.withOpacity(0.16) : null,
        foregroundColor: selected ? LibraryDesignTokens.primary : null,
      ),
      onPressed: onPressed,
    );
  }

  Widget _fontSizeButton(String label, String tooltip, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: onPressed,
    );
  }

  Widget _plainButton(String tooltip, IconData icon, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: LibraryIcon.fromIcon(icon, size: 18, color: LibraryDesignTokens.icon),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: onPressed,
    );
  }

  Widget _labelBox(String text, {required double width}) {
    return Container(
      width: width,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black45),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: normalStyle(fontSize: 13)),
    );
  }

  Widget _fontSelector() {
    return SizedBox(
      width: 110,
      height: 28,
      child: DropdownButton<RecitedTextFontOption>(
        value: selectedFontOption,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: normalStyle(fontSize: 13),
        items: fontOptions.map((option) {
          return DropdownMenuItem<RecitedTextFontOption>(
            value: option,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: onFontChanged,
      ),
    );
  }

  Widget _topSearchField() {
    return SizedBox(
      width: 210,
      height: 26,
      child: TextField(
        controller: searchController,
        focusNode: searchFocusNode,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: normalStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          hintText: 'بحث في الآيات Ctrl+F',
          border: OutlineInputBorder(),
        ),
        onSubmitted: onTopSearchSubmitted,
      ),
    );
  }
}
