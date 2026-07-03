import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/grouped_search_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';
import 'package:golden_shamela/UI/RecitedText/chapter_sidebar.dart';
import 'package:golden_shamela/UI/RecitedText/passage_reader_pane.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_models.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_repository.dart';
import 'package:golden_shamela/UI/RecitedText/recited_text_search_panel.dart';
import 'package:golden_shamela/UI/RecitedText/tafsir_pane.dart';

class RecitedTextTabView extends StatefulWidget {
  const RecitedTextTabView({super.key});

  @override
  State<RecitedTextTabView> createState() => _RecitedTextTabViewState();
}

class _RecitedTextTabViewState extends State<RecitedTextTabView> {
  static const List<RecitedTextFontOption> _fontOptions = [
    RecitedTextFontOption(label: 'الرسم الإملائي', fontFamily: 'recited_traditional', useImlaeiText: true),
    RecitedTextFontOption(label: 'الخط الأميري', fontFamily: 'recited_amiri'),
    RecitedTextFontOption(label: 'خط المجمع', fontFamily: 'recited_complex'),
  ];

  final RecitedTextRepository _repository = RecitedTextRepository();
  final TextEditingController _topSearch = TextEditingController();
  final FocusNode _topSearchFocus = FocusNode();
  final GroupedSearchController _bottomSearchController = GroupedSearchController();
  late Future<RecitedTextSnapshot> _snapshotFuture;

  String? _selectedPassageKey = '1:1';
  RecitedTextFontOption _selectedFontOption = _fontOptions.first;
  TafsirResource? _selectedTafsir;
  Future<Map<String, String>>? _tafsirFuture;
  bool _showTafsir = true;
  bool _showSearch = true;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _repository.loadSnapshot();
  }

  @override
  void dispose() {
    _topSearch.dispose();
    _topSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: FutureBuilder<RecitedTextSnapshot>(
          future: _snapshotFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _missingData(snapshot.error);
            }
            if (snapshot.data!.chapters.isEmpty || snapshot.data!.passages.isEmpty) {
              return _missingData(null);
            }
            _ensurePosition(snapshot.data!);
            _ensureTafsir(snapshot.data!);
            return _layout(snapshot.data!);
          },
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!HardwareKeyboard.instance.isControlPressed) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.keyF) return KeyEventResult.ignored;
    if (!_showSearch) setState(() => _showSearch = true);
    _topSearchFocus.requestFocus();
    _topSearch.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _topSearch.text.length,
    );
    return KeyEventResult.handled;
  }

  Widget _layout(RecitedTextSnapshot snapshot) {
    final passage = _selectedPassage(snapshot);
    return LibrarySplitPane(
      axis: Axis.horizontal,
      initialRatio: 0.82,
      minRatio: 0.62,
      maxRatio: 0.9,
      first: _mainPane(snapshot),
      second: SizedBox(
        width: 210,
        child: ChapterSidebar(
          chapters: snapshot.chapters,
          selectedChapterNumber: passage.chapterNumber,
          selectedPassageNumber: passage.passageNumber,
          selectedJuzNumber: passage.juzNumber,
          selectedHizbNumber: passage.hizbNumber,
          selectedQuarterNumber: passage.quarterNumber,
          selectedPageNumber: passage.pageNumber,
          onSelected: (chapter) => _selectChapter(snapshot, chapter.number),
          onPassageSelected: (number) {
            _selectPassageNumber(snapshot, passage.chapterNumber, number);
          },
          onJuzSelected: (number) => _selectFirstMatching(
            snapshot,
            (item) => item.juzNumber == number,
          ),
          onHizbSelected: (number) => _selectFirstMatching(
            snapshot,
            (item) => item.hizbNumber == number,
          ),
          onQuarterSelected: (number) {
            final index = ((passage.hizbNumber - 1) * 4) + number;
            _selectFirstMatching(snapshot, (item) => item.quarterIndex == index);
          },
          onPageSelected: (number) => _selectPage(snapshot, number),
        ),
      ),
    );
  }

  Widget _mainPane(RecitedTextSnapshot snapshot) {
    if (!_showSearch) return _readerAndTafsir(snapshot);
    return LibrarySplitPane(
      axis: Axis.vertical,
      initialRatio: 0.7,
      minRatio: 0.45,
      maxRatio: 0.86,
      first: _readerAndTafsir(snapshot),
      second: RecitedTextSearchPanel(
        controller: _bottomSearchController,
        repository: _repository,
        snapshot: snapshot,
        onResultSelected: _selectSearchResult,
      ),
    );
  }

  Widget _readerAndTafsir(RecitedTextSnapshot snapshot) {
    final passage = _selectedPassage(snapshot);
    final chapter = _chapterFor(snapshot, passage.chapterNumber);
    final pagePassages = _pagePassages(snapshot, passage.pageNumber);
    final reader = PassageReaderPane(
      chapters: snapshot.chapters,
      chapter: chapter,
      pagePassages: pagePassages,
      selectedPassageKey: _selectedPassageKey,
      currentPageNumber: passage.pageNumber,
      maxPageNumber: _maxPageNumber(snapshot),
      currentJuzNumber: passage.juzNumber,
      fontOptions: _fontOptions,
      selectedFontOption: _selectedFontOption,
      searchController: _topSearch,
      searchFocusNode: _topSearchFocus,
      selectedTafsirResource: _selectedTafsir,
      tafsirFuture: _tafsirFuture,
      isTafsirVisible: _showTafsir,
      isSearchVisible: _showSearch,
      onSelected: _selectPassage,
      onPageSelected: (page) => _selectPage(snapshot, page),
      onFontChanged: (option) {
        if (option != null) setState(() => _selectedFontOption = option);
      },
      onTopSearchSubmitted: _submitTopSearch,
      onToggleTafsir: () => setState(() => _showTafsir = !_showTafsir),
      onToggleSearch: () => setState(() => _showSearch = !_showSearch),
    );
    if (!_showTafsir) return reader;
    return LibrarySplitPane(
      axis: Axis.vertical,
      initialRatio: 0.68,
      minRatio: 0.35,
      maxRatio: 0.9,
      first: reader,
      second: TafsirPane(
        resources: snapshot.tafsirResources,
        selectedResource: _selectedTafsir,
        onResourceChanged: _changeTafsir,
        selectedPassageKey: _selectedPassageKey,
        tafsirFuture: _tafsirFuture,
        onClose: () => setState(() => _showTafsir = false),
      ),
    );
  }

  Widget _missingData(Object? error) {
    final path = AppStoragePaths.recitedTextStorePath;
    final exists = Directory(path).existsSync();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          exists
              ? 'تعذر قراءة ملفات النص المقروء'
              : 'ضع ملفات النص المقروء في:\n$path',
          textAlign: TextAlign.center,
          style: normalStyle(fontSize: 16, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  void _ensurePosition(RecitedTextSnapshot snapshot) {
    final exists = snapshot.passages.any((item) {
      return item.passageKey == _selectedPassageKey;
    });
    if (exists) return;
    _setCurrentPassage(snapshot.passages.first, clearPageSelection: true);
  }

  void _ensureTafsir(RecitedTextSnapshot snapshot) {
    if (_selectedTafsir != null || snapshot.tafsirResources.isEmpty) return;
    _selectedTafsir = snapshot.defaultTafsir;
    if (_selectedTafsir != null) {
      _tafsirFuture = _repository.loadTafsir(_selectedTafsir!);
    }
  }

  void _changeTafsir(TafsirResource? resource) {
    if (resource == null) return;
    setState(() {
      _selectedTafsir = resource;
      _tafsirFuture = _repository.loadTafsir(resource);
    });
  }

  void _selectSearchResult(RecitedTextSearchResult result) {
    setState(() => _setCurrentPassage(result.passage, clearPageSelection: true));
  }

  Future<void> _submitTopSearch(String text) async {
    final term = text.trim();
    if (term.isEmpty) return;
    if (_showSearch) {
      await _bottomSearchController.searchFirstField(term);
      return;
    }
    setState(() => _showSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bottomSearchController.searchFirstField(term);
    });
  }

  void _selectChapter(RecitedTextSnapshot snapshot, int chapterNumber) {
    _selectFirstMatching(snapshot, (item) => item.chapterNumber == chapterNumber);
  }

  void _selectPassageNumber(
    RecitedTextSnapshot snapshot,
    int chapterNumber,
    int passageNumber,
  ) {
    _selectFirstMatching(snapshot, (item) {
      return item.chapterNumber == chapterNumber &&
          item.passageNumber == passageNumber;
    });
  }

  void _selectPage(RecitedTextSnapshot snapshot, int pageNumber) {
    _selectFirstMatching(snapshot, (item) => item.pageNumber == pageNumber);
  }

  void _selectFirstMatching(
    RecitedTextSnapshot snapshot,
    bool Function(PassageUnit item) test,
  ) {
    for (final passage in snapshot.passages) {
      if (!test(passage)) continue;
      setState(() => _setCurrentPassage(passage, clearPageSelection: true));
      return;
    }
  }

  void _selectPassage(PassageUnit passage) {
    setState(() => _setCurrentPassage(passage, clearPageSelection: true));
  }

  void _setCurrentPassage(
    PassageUnit passage, {
    required bool clearPageSelection,
  }) {
    _selectedPassageKey = passage.passageKey;
  }

  PassageUnit _selectedPassage(RecitedTextSnapshot snapshot) {
    return snapshot.passages.firstWhere(
      (item) => item.passageKey == _selectedPassageKey,
      orElse: () => snapshot.passages.first,
    );
  }

  ChapterInfo _chapterFor(RecitedTextSnapshot snapshot, int chapterNumber) {
    return snapshot.chapters.firstWhere(
      (chapter) => chapter.number == chapterNumber,
      orElse: () => snapshot.chapters.first,
    );
  }

  List<PassageUnit> _pagePassages(RecitedTextSnapshot snapshot, int pageNumber) {
    return snapshot.passages
        .where((item) => item.pageNumber == pageNumber)
        .toList();
  }

  int _maxPageNumber(RecitedTextSnapshot snapshot) {
    var maxPage = 1;
    for (final passage in snapshot.passages) {
      if (passage.pageNumber > maxPage) maxPage = passage.pageNumber;
    }
    return maxPage;
  }
}
