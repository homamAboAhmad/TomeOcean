import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_fragment.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_lazy_book_card_panel.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_split_pane.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_text_normalizer.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_content_widgets.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_models.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_repository.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_search_panel.dart';
import 'package:golden_shamela/UI/LibraryData/library_data_section_tabs.dart';

class LibraryDataTabView extends StatefulWidget {
  const LibraryDataTabView({super.key});

  @override
  State<LibraryDataTabView> createState() => _LibraryDataTabViewState();
}

class _LibraryDataTabViewState extends State<LibraryDataTabView> {
  final LibraryDataRepository _repository = LibraryDataRepository();
  final TextEditingController _authorsSearch = TextEditingController();
  final TextEditingController _booksSearch = TextEditingController();
  final TextEditingController _briefsSearch = TextEditingController();
  final TextEditingController _authorBooksSearch = TextEditingController();
  final ValueNotifier<Future<LibraryBookItem?>?> _bookDetails =
      ValueNotifier(null);
  final ValueNotifier<Future<LibraryBookItem?>?> _briefDetails =
      ValueNotifier(null);
  final ValueNotifier<Future<LibraryBookItem?>?> _authorBookDetails =
      ValueNotifier(null);

  late Future<LibraryDataSnapshot> _snapshotFuture;
  LibraryDataSection _section = LibraryDataSection.authors;
  String? _selectedAuthorId;
  String? _selectedBookPath;
  String? _selectedBriefPath;
  String? _selectedAuthorBookPath;
  String _bookSearchScope = 'title_author';
  String _briefSearchScope = 'full';
  String _authorBookSearchScope = 'title_author';
  bool _showAuthorBookCard = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _repository.loadSnapshot();
  }

  @override
  void dispose() {
    _authorsSearch.dispose();
    _booksSearch.dispose();
    _briefsSearch.dispose();
    _authorBooksSearch.dispose();
    _bookDetails.dispose();
    _briefDetails.dispose();
    _authorBookDetails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<LibraryDataSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('تعذر تحميل بيانات المؤلفين والكتب'),
            );
          }
          return _dataLayout(snapshot.data!);
        },
      ),
    );
  }

  Widget _dataLayout(LibraryDataSnapshot snapshot) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final initialLeft =
            ((width - 360) / width).clamp(0.62, 0.84).toDouble();
        final minLeft =
            ((width - 520) / width).clamp(0.45, 0.78).toDouble();
        final maxLeft =
            ((width - 280) / width).clamp(0.68, 0.9).toDouble();
        return LibrarySplitPane(
          axis: Axis.horizontal,
          initialRatio: initialLeft,
          minRatio: minLeft,
          maxRatio: maxLeft,
          first: _leftPane(snapshot),
          second: _rightSidebar(snapshot),
        );
      },
    );
  }

  Widget _leftPane(LibraryDataSnapshot snapshot) {
    return LibrarySplitPane(
      axis: Axis.vertical,
      initialRatio: 0.67,
      minRatio: 0.4,
      maxRatio: 0.85,
      first: _detailsPane(snapshot),
      second: LibraryDataSearchPanel(
        repository: _repository,
        onResultSelected: _handleSearchResult,
      ),
    );
  }

  Widget _rightSidebar(LibraryDataSnapshot snapshot) {
    return DefaultTextStyle(
      style: normalStyle(fontSize: 12, fontWeight: FontWeight.w600),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: LibraryDesignTokens.sidebar,
          border: Border(left: BorderSide(color: LibraryDesignTokens.divider)),
        ),
        child: Column(
          children: [
            LibraryDataSectionTabs(
              section: _section,
              onSelected: (section) => setState(() => _section = section),
            ),
            Expanded(child: _sidebarBody(snapshot)),
          ],
        ),
      ),
    );
  }

  Widget _sidebarBody(LibraryDataSnapshot snapshot) {
    switch (_section) {
      case LibraryDataSection.authors:
        return _authorsSidebar(snapshot);
      case LibraryDataSection.books:
        return _booksSidebar(snapshot);
      case LibraryDataSection.briefs:
        return _briefsSidebar(snapshot);
    }
  }

  Widget _detailsPane(LibraryDataSnapshot snapshot) {
    switch (_section) {
      case LibraryDataSection.authors:
        return LibraryDataAuthorDetailsPane(
          author: _selectedAuthor(_filterAuthors(snapshot.authors)),
        );
      case LibraryDataSection.books:
        return LibraryDataBookDetailsPane(details: _bookDetails);
      case LibraryDataSection.briefs:
        return LibraryDataBriefDetailsPane(details: _briefDetails);
    }
  }

  Widget _authorsSidebar(LibraryDataSnapshot snapshot) {
    final authors = _filterAuthors(snapshot.authors);
    final selectedAuthor = _selectedAuthor(authors);
    return LibrarySplitPane(
      axis: Axis.vertical,
      initialRatio: 0.55,
      minRatio: 0.35,
      maxRatio: 0.75,
      first: LibraryDataListShell(
        countLabel: 'عدد المؤلفين: ${snapshot.authors.length}',
        child: LibraryEntitiesFragment(
          searchController: _authorsSearch,
          searchHint: 'بحث في المؤلفين والتراجم',
          onSearchChanged: (_) => setState(() {}),
          rows: authors.map((author) {
            return LibraryEntityRow(
              id: author.id,
              title: author.name,
              secondary: author.deathYear ?? 'غير محدد',
              count: snapshot.authorBookCounts[author.id] ?? 0,
            );
          }).toList(),
          selectedId: selectedAuthor?.id,
          titleHeader: 'المؤلف',
          secondaryHeader: 'الوفاة',
          onSelected: (id) => setState(() {
            _selectedAuthorId = id;
            _selectedAuthorBookPath = null;
            _authorBookDetails.value = null;
          }),
        ),
      ),
      second: _authorBooksSection(snapshot, selectedAuthor),
    );
  }

  Widget _authorBooksSection(
    LibraryDataSnapshot snapshot,
    Author? selectedAuthor,
  ) {
    if (selectedAuthor == null) {
      return const Center(child: Text('اختر مؤلفًا لعرض كتبه'));
    }
    final books = _filterBooks(
      snapshot.books.where((item) => item.book.authorId == selectedAuthor.id),
      _authorBooksSearch.text,
      _authorBookSearchScope,
    );
    final booksPane = LibraryDataBooksPane(
      controller: _authorBooksSearch,
      hint: 'بحث في كتب المؤلف',
      books: books,
      selectedPath: _selectedAuthorBookPath,
      scope: _authorBookSearchScope,
      onSearchChanged: (_) => setState(() {}),
      onScopeChanged: (value) => setState(() => _authorBookSearchScope = value),
      onSelected: _selectAuthorBook,
      leadingActions: [
        IconButton(
          tooltip: 'بطاقة الكتاب',
          icon: LibraryIcon.fromIcon(
            Icons.chrome_reader_mode_outlined,
            size: 24,
            color: _showAuthorBookCard
                ? LibraryDesignTokens.primary
                : LibraryDesignTokens.icon,
          ),
          onPressed: () {
            setState(() => _showAuthorBookCard = !_showAuthorBookCard);
          },
        ),
      ],
    );
    if (!_showAuthorBookCard) return booksPane;
    return LibrarySplitPane(
      axis: Axis.vertical,
      initialRatio: 0.55,
      minRatio: 0.32,
      maxRatio: 0.78,
      first: booksPane,
      second: LibraryLazyBookCardPanel(details: _authorBookDetails),
    );
  }

  Widget _booksSidebar(LibraryDataSnapshot snapshot) {
    final books = _filterBooks(snapshot.books, _booksSearch.text, _bookSearchScope);
    return LibraryDataListShell(
      countLabel: 'عدد الكتب: ${snapshot.books.length}',
      child: LibraryDataBooksPane(
        controller: _booksSearch,
        hint: 'بحث في الكتب',
        books: books,
        selectedPath: _selectedBookPath,
        scope: _bookSearchScope,
        onScopeChanged: (value) => setState(() => _bookSearchScope = value),
        onSearchChanged: (_) => setState(() {}),
        onSelected: _selectBook,
      ),
    );
  }

  Widget _briefsSidebar(LibraryDataSnapshot snapshot) {
    final books = _filterBooks(snapshot.briefBooks, _briefsSearch.text, _briefSearchScope);
    return LibraryDataListShell(
      countLabel: 'عدد النبذات: ${snapshot.briefBooks.length}',
      child: LibraryDataBooksPane(
        controller: _briefsSearch,
        hint: 'بحث في النبذات',
        books: books,
        selectedPath: _selectedBriefPath,
        scope: _briefSearchScope,
        onScopeChanged: (value) => setState(() => _briefSearchScope = value),
        onSearchChanged: (_) => setState(() {}),
        onSelected: _selectBrief,
      ),
    );
  }

  List<Author> _filterAuthors(List<Author> authors) {
    final query = _authorsSearch.text;
    return authors.where((author) {
      return LibraryTextNormalizer.contains(
        '${author.name} ${author.deathYear ?? ''} ${author.description}',
        query,
      );
    }).toList();
  }

  List<LibraryBookItem> _filterBooks(
    Iterable<LibraryBookItem> books,
    String query,
    String scope,
  ) {
    return books.where((item) {
      final source = scope == 'title'
          ? item.title
          : scope == 'title_author'
              ? '${item.title} ${item.authorName}'
              : item.bookCardSearchText;
      return LibraryTextNormalizer.contains(source, query);
    }).toList();
  }

  Author? _selectedAuthor(List<Author> authors) {
    if (authors.isEmpty) return null;
    return authors.cast<Author?>().firstWhere(
          (author) => author?.id == _selectedAuthorId,
          orElse: () => authors.first,
        );
  }

  void _selectBook(LibraryBookItem item) {
    setState(() {
      _section = LibraryDataSection.books;
      _selectedBookPath = item.bookPath;
      _bookDetails.value = _repository.loadBookDetails(item);
    });
  }

  void _selectBrief(LibraryBookItem item) {
    setState(() {
      _section = LibraryDataSection.briefs;
      _selectedBriefPath = item.bookPath;
      _briefDetails.value = _repository.loadBookDetails(item);
    });
  }

  void _selectAuthorBook(LibraryBookItem item) {
    setState(() {
      _selectedAuthorBookPath = item.bookPath;
      _authorBookDetails.value = _repository.loadBookDetails(item);
    });
  }

  void _handleSearchResult(LibraryDataSearchResult result) {
    setState(() {
      switch (result.type) {
        case LibraryDataItemType.author:
          _section = LibraryDataSection.authors;
          _authorsSearch.clear();
          _selectedAuthorId = result.author?.id;
          _selectedAuthorBookPath = null;
          _authorBookDetails.value = null;
          break;
        case LibraryDataItemType.book:
          _section = LibraryDataSection.books;
          _booksSearch.clear();
          final book = result.book;
          if (book != null) {
            _selectedBookPath = book.bookPath;
            _bookDetails.value = _repository.loadBookDetails(book);
          }
          break;
        case LibraryDataItemType.brief:
          _section = LibraryDataSection.briefs;
          _briefsSearch.clear();
          final book = result.book;
          if (book != null) {
            _selectedBriefPath = book.bookPath;
            _briefDetails.value = _repository.loadBookDetails(book);
          }
          break;
      }
    });
  }
}
