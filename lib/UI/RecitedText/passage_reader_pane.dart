import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/RecitedText/reader_navigation_bar.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_clipboard.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_mark_span_builder.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_passage_marker.dart';
import 'package:golden_shamela/UI/SettingsScreen.dart';

class PassageReaderPane extends StatefulWidget {
  final List<ChapterInfo> chapters;
  final ChapterInfo chapter;
  final List<PassageUnit> pagePassages;
  final String? selectedPassageKey;
  final int currentPageNumber;
  final int maxPageNumber;
  final int currentJuzNumber;
  final List<RecitedTextFontOption> fontOptions;
  final RecitedTextFontOption selectedFontOption;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final TafsirResource? selectedTafsirResource;
  final Future<Map<String, String>>? tafsirFuture;
  final bool isTafsirVisible, isSearchVisible;
  final ValueChanged<PassageUnit> onSelected;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<RecitedTextFontOption?> onFontChanged;
  final ValueChanged<String> onTopSearchSubmitted;
  final VoidCallback onToggleTafsir, onToggleSearch;
  const PassageReaderPane({
    super.key,
    required this.chapters,
    required this.chapter,
    required this.pagePassages,
    required this.selectedPassageKey,
    required this.currentPageNumber,
    required this.maxPageNumber,
    required this.currentJuzNumber,
    required this.fontOptions,
    required this.selectedFontOption,
    required this.searchController,
    required this.searchFocusNode,
    required this.selectedTafsirResource,
    required this.tafsirFuture,
    required this.isTafsirVisible, required this.isSearchVisible,
    required this.onSelected,
    required this.onPageSelected,
    required this.onFontChanged,
    required this.onTopSearchSubmitted,
    required this.onToggleTafsir, required this.onToggleSearch,
  });
  @override
  State<PassageReaderPane> createState() => _PassageReaderPaneState();
}

class _PassageReaderPaneState extends State<PassageReaderPane> {
  static const Color _selectedPassageColor = Color(0xFFB3261E);
  static const double _minReaderFontSize = 22, _maxReaderFontSize = 44;
  final List<TapGestureRecognizer> _passageRecognizers = [];
  String? _selectedText;
  bool _suppressNextTextMenu = false;
  double _readerFontSize = 30;

  @override
  void dispose() {
    _clearPassageRecognizers();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF6F1DC)),
        child: Column(
          children: [
            ReaderNavigationBar(
              chapterName: widget.chapter.name,
              currentPageNumber: widget.currentPageNumber,
              maxPageNumber: widget.maxPageNumber,
              currentJuzNumber: widget.currentJuzNumber,
              fontOptions: widget.fontOptions,
              selectedFontOption: widget.selectedFontOption,
              searchController: widget.searchController,
              searchFocusNode: widget.searchFocusNode,
              onPageSelected: widget.onPageSelected,
              onFontChanged: widget.onFontChanged,
              onTopSearchSubmitted: widget.onTopSearchSubmitted,
              onCopyWithReference: _copyWithReference,
              onOpenCopyFontSettings: _openCopyFontSettings,
              isTafsirVisible: widget.isTafsirVisible, isSearchVisible: widget.isSearchVisible,
              onToggleTafsir: widget.onToggleTafsir, onToggleSearch: widget.onToggleSearch,
              onIncreaseFontSize: _increaseFontSize,
              onDecreaseFontSize: _decreaseFontSize,
            ),
            Expanded(child: _pageBody(context)),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed) {
      if (_isZoomInKey(event.logicalKey)) return _changeFontSize(2);
      if (_isZoomOutKey(event.logicalKey)) return _changeFontSize(-2);
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyC) {
        keyboard.isShiftPressed ? _copyWithReference() : _copyPlain();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (widget.searchFocusNode.hasFocus || keyboard.isShiftPressed || keyboard.isAltPressed || keyboard.isMetaPressed) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) return _changePage(1);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) return _changePage(-1);
    return KeyEventResult.ignored;
  }
  bool _isZoomInKey(LogicalKeyboardKey key) => key == LogicalKeyboardKey.equal || key.keyLabel == '+';
  bool _isZoomOutKey(LogicalKeyboardKey key) => key == LogicalKeyboardKey.minus || key.keyLabel == '-';
  void _increaseFontSize() => _changeFontSize(2);
  void _decreaseFontSize() => _changeFontSize(-2);
  KeyEventResult _changeFontSize(double delta) {
    setState(() => _readerFontSize = (_readerFontSize + delta).clamp(_minReaderFontSize, _maxReaderFontSize).toDouble());
    return KeyEventResult.handled;
  }
  KeyEventResult _changePage(int delta) {
    final page = (widget.currentPageNumber + delta).clamp(1, widget.maxPageNumber).toInt();
    if (page == widget.currentPageNumber) return KeyEventResult.handled;
    widget.onPageSelected(page);
    return KeyEventResult.handled;
  }
  Widget _pageBody(BuildContext context) {
    if (widget.pagePassages.isEmpty) {
      return const Center(child: Text('لا يوجد نص في هذه الصفحة'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              if ((event.buttons & kSecondaryMouseButton) != 0) {
                if ((_selectedText ?? '').trim().isEmpty) {
                  _suppressNextTextMenu = true;
                  _showFallbackContextMenu(context, event.position);
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 26),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F1DC),
                border: Border.all(color: LibraryDesignTokens.primary, width: 1.8),
              ),
              child: TextSelectionTheme(
                data: const TextSelectionThemeData(selectionColor: Color(0x554E8F57)),
                child: SelectionArea(
                  contextMenuBuilder: (_, state) {
                    if (_suppressNextTextMenu) {
                      _suppressNextTextMenu = false;
                      return const SizedBox.shrink();
                    }
                    return _buildContextMenu(state);
                  },
                  onSelectionChanged: (content) => _selectedText = content?.plainText,
                  child: Text.rich(
                    TextSpan(children: _passageSpans()),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: normalStyle(fontSize: _readerFontSize, height: 2.05).copyWith(
                      fontFamily: widget.selectedFontOption.fontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  List<InlineSpan> _passageSpans() {
    _clearPassageRecognizers();
    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.pagePassages.length; i++) {
      final passage = widget.pagePassages[i];
      if (passage.passageNumber == 1) spans.add(_chapterHeaderSpan(passage.chapterNumber, i == 0));
      _addPassageSpan(spans, passage);
    }
    return spans;
  }
  InlineSpan _chapterHeaderSpan(int chapterNumber, bool atPageStart) {
    final name = _chapterName(chapterNumber);
    final hasBasmalah = chapterNumber != 1 && chapterNumber != 9;
    final divider = atPageStart ? '' : '\n────────────────────────\n';
    final basmalah = hasBasmalah ? '\nبسم الله الرحمن الرحيم' : '';
    final text = '$divider[ سورة $name ]$basmalah\n';
    return TextSpan(text: text, style: TextStyle(color: LibraryDesignTokens.primary, fontSize: _readerFontSize * 0.8, fontWeight: FontWeight.bold));
  }
  void _addPassageSpan(List<InlineSpan> spans, PassageUnit passage) {
    final selected = passage.passageKey == widget.selectedPassageKey;
    final marker = recitedTextPassageMarker(passage.passageNumber);
    final recognizer = TapGestureRecognizer()..onTap = () => widget.onSelected(passage);
    _passageRecognizers.add(recognizer);
    final passageStyle = TextStyle(color: selected ? _selectedPassageColor : Colors.black87, fontWeight: selected ? FontWeight.bold : null);
    spans.addAll(buildRecitedTextSpans(
      text: '${_passageText(passage)} ',
      style: passageStyle,
      useMarkFallback: widget.selectedFontOption.fontFamily == 'recited_complex',
      recognizer: recognizer,
    ));
    spans.add(TextSpan(
      text: marker,
      recognizer: recognizer,
      style: TextStyle(
        color: selected ? _selectedPassageColor : const Color(0xFF63A86A),
        fontWeight: selected ? FontWeight.bold : null,
        fontSize: _readerFontSize * 0.73,
      ),
    ));
  }
  Widget _buildContextMenu(SelectableRegionState state) {
    final anchor = state.contextMenuAnchors.primaryAnchor;
    return Stack(
      children: [
        Positioned(
          top: anchor.dy,
          left: anchor.dx,
          child: Material(
            color: const Color(0xFFF4EEF8),
            elevation: 3,
            borderRadius: BorderRadius.circular(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuItem('نسخ', () {
                  _copyPlain();
                  state.hideToolbar();
                }),
                _menuItem('نسخ مع العزو', () {
                  _copyWithReference();
                  state.hideToolbar();
                }),
                _menuItem('نسخ مع التفسير', () {
                  _copyWithTafsir();
                  state.hideToolbar();
                }),
                _menuItem('اختيار الكل', () {
                  state.selectAll(SelectionChangedCause.toolbar);
                  state.hideToolbar();
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(width: 140, height: 42, child: Center(child: Text(label, style: normalStyle(fontSize: 14)))),
      );

  Future<void> _showFallbackContextMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final localPosition = overlay.globalToLocal(position);
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(localPosition.dx, localPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'copy', child: Text('نسخ')),
        PopupMenuItem(value: 'copy_ref', child: Text('نسخ مع العزو')),
        PopupMenuItem(value: 'copy_tafsir', child: Text('نسخ مع التفسير')),
        PopupMenuItem(value: 'select_all', child: Text('اختيار الكل')),
      ],
    );
    _suppressNextTextMenu = false;
    if (action == 'copy') return _copyPlain();
    if (action == 'copy_ref') return _copyWithReference();
    if (action == 'copy_tafsir') return _copyWithTafsir();
    if (action == 'select_all') _selectAllText();
  }

  void _selectAllText() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return;
    Actions.maybeInvoke(focusContext, const SelectAllTextIntent(SelectionChangedCause.toolbar));
  }

  void _openCopyFontSettings() => showDialog(context: context, builder: (_) => const SettingsScreen(initialSection: 'copyFont'));

  Future<void> _copyPlain({PassageUnit? fallback}) async {
    await RecitedTextClipboard.setFormatted(plainText: _activeText(fallback), bodyText: _activeText(fallback), reference: '', fontOption: widget.selectedFontOption);
  }
  Future<void> _copyWithReference({PassageUnit? fallback}) async {
    final passages = _activePassages(fallback);
    final body = '﴿${_activeText(fallback).trim()}﴾';
    final reference = _reference(passages);
    await RecitedTextClipboard.setFormatted(plainText: '$body [$reference]', bodyText: body, reference: reference, fontOption: widget.selectedFontOption);
  }

  Future<void> _copyWithTafsir({PassageUnit? fallback}) async {
    final passages = _activePassages(fallback);
    final body = '﴿${_activeText(fallback).trim()}﴾';
    final reference = _reference(passages);
    final text = '$body [$reference]';
    final future = widget.tafsirFuture, resource = widget.selectedTafsirResource;
    if (future == null || resource == null) {
      await RecitedTextClipboard.setFormatted(plainText: text, bodyText: body, reference: reference, fontOption: widget.selectedFontOption);
      return;
    }
    final entries = await future;
    final tafsir = passages
        .map((item) => entries[item.passageKey]?.trim() ?? '')
        .where((item) => item.isNotEmpty)
        .join('\n\n');
    await RecitedTextClipboard.setFormatted(plainText: '$text\n\n${resource.name}:\n$tafsir', bodyText: body, reference: reference, fontOption: widget.selectedFontOption, tafsirTitle: resource.name, tafsirText: tafsir);
  }
  String _activeText(PassageUnit? fallback) {
    final selected = _cleanActiveText(_selectedText ?? '');
    if (selected.isNotEmpty) return selected;
    if (fallback == null) return _pagePlainText();
    return '${_passageText(fallback)} (${fallback.passageNumber})';
  }
  String _cleanActiveText(String text) => cleanRecitedTextControls(text).split('\n').where((line) => !RegExp(r'^\s*\[\s*سورة\s+.*\]\s*$').hasMatch(line)).join('\n').trim();

  List<PassageUnit> _activePassages(PassageUnit? fallback) {
    final selected = _compactText(_cleanActiveText(_selectedText ?? ''));
    if (selected.isNotEmpty) {
      final matches = widget.pagePassages.where((passage) {
        final text = _compactText(_passageText(passage));
        return selected.contains(text) || text.contains(selected);
      }).toList();
      if (matches.isNotEmpty) return matches;
    }
    if (fallback != null) return [fallback];
    return widget.pagePassages;
  }

  String _reference(List<PassageUnit> passages) {
    if (passages.isEmpty) return widget.chapter.name;
    final first = passages.first;
    final last = passages.last;
    final firstName = _chapterName(first.chapterNumber);
    if (first.chapterNumber != last.chapterNumber) {
      return '$firstName: ${first.passageNumber} - ${_chapterName(last.chapterNumber)}: ${last.passageNumber}';
    }
    final range = first.passageNumber == last.passageNumber ? '${first.passageNumber}' : '${first.passageNumber}-${last.passageNumber}';
    return '$firstName: $range';
  }

  String _chapterName(int chapterNumber) => widget.chapters.firstWhere((chapter) => chapter.number == chapterNumber, orElse: () => widget.chapter).name;
  String _pagePlainText() => widget.pagePassages.map((passage) => '${_passageText(passage)} (${passage.passageNumber})').join(' ');
  String _passageText(PassageUnit passage) => passage.displayText(useImlaeiText: widget.selectedFontOption.useImlaeiText);
  String _compactText(String text) => cleanRecitedTextControls(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  void _clearPassageRecognizers() {
    for (final recognizer in _passageRecognizers) {
      recognizer.dispose();
    }
    _passageRecognizers.clear();
  }
}
