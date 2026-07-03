import 'dart:io';

import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_entities_table.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/LibraryControl/library_control_repository.dart';
import 'package:golden_shamela/UI/Widgets/organic_background.dart';

part 'home_start_widgets.dart';

class HomeStartView extends StatefulWidget {
  final VoidCallback onOpenBooks;
  final VoidCallback onOpenRecitedText;
  final VoidCallback onOpenAuthors;
  final VoidCallback onOpenSearch;
  final void Function(String query, String? sectionId, String? sectionTitle)
      onSearch;
  final ValueChanged<String> onOpenSection;
  final ValueChanged<String> onOpenRecentBook;

  const HomeStartView({
    super.key,
    required this.onOpenBooks,
    required this.onOpenRecitedText,
    required this.onOpenAuthors,
    required this.onOpenSearch,
    required this.onSearch,
    required this.onOpenSection,
    required this.onOpenRecentBook,
  });

  @override
  State<HomeStartView> createState() => _HomeStartViewState();
}

class _HomeStartViewState extends State<HomeStartView> {
  late final Future<_HomeStartData> _dataFuture = _loadData();
  final _searchController = TextEditingController();
  final _repo = LibraryControlRepository();
  List<LibraryEntityRow> _scopeSections = const [];
  String? _selectedSectionId;
  String? _selectedSectionTitle;
  bool _loadingScopeSections = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeStartData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _HomeStartData();
        final scopeSections =
            _scopeSections.isEmpty ? data.sections : _scopeSections;
        return OrganicBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchStrip(
                      controller: _searchController,
                      sections: scopeSections,
                      selectedSectionId: _selectedSectionId,
                      onSectionChanged: (value) {
                        String? title;
                        for (final section in scopeSections) {
                          if (section.id == value) {
                            title = section.title;
                            break;
                          }
                        }
                        setState(() {
                          _selectedSectionId = value;
                          _selectedSectionTitle = title;
                        });
                      },
                      onScopeOpened: _loadScopeSectionsIfNeeded,
                      loadingScopes: _loadingScopeSections,
                      onOpenSearch: widget.onOpenSearch,
                      onSearch: _runSearch,
                    ),
                    const SizedBox(height: 22),
                    _HomeEntryGrid(
                      data: data,
                      onOpenBooks: widget.onOpenBooks,
                      onOpenRecitedText: widget.onOpenRecitedText,
                      onOpenAuthors: widget.onOpenAuthors,
                      onOpenSearch: widget.onOpenSearch,
                    ),
                    const SizedBox(height: 24),
                    _HomePanels(
                      data: data,
                      onOpenRecentBook: widget.onOpenRecentBook,
                      onOpenSection: widget.onOpenSection,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_HomeStartData> _loadData() async {
    try {
      final db = BooksMetadataDatabase();
      await db.initialize();
      final paths = await db.getRecentBookPaths();
      final recent = <_RecentBook>[];
      for (final path in paths) {
        if (recent.length >= 5) break;
        if (!await File(path).exists()) continue;
        final book = await db.getBookByPath(path);
        final author = book?.authorId.isEmpty == false
            ? await db.getAuthorById(book!.authorId)
            : null;
        recent.add(_RecentBook(
          path: path,
          title: book?.title ?? AppStoragePaths.displayTitleFromPath(path),
          author: author?.name ?? '',
          pageCount: book?.pageCount ?? '',
        ));
      }

      return _HomeStartData(
        bookCount: await db.countBooks(),
        authorCount: await db.countAuthors(),
        sectionCount: await db.countSections(),
        recentBooks: recent,
        sections: await _repo.loadSections('', limit: 6),
      );
    } catch (_) {
      return const _HomeStartData();
    }
  }

  void _runSearch() {
    widget.onSearch(
      _searchController.text,
      _selectedSectionId,
      _selectedSectionTitle,
    );
  }

  Future<void> _loadScopeSectionsIfNeeded() async {
    if (_scopeSections.isNotEmpty || _loadingScopeSections) return;
    setState(() => _loadingScopeSections = true);
    final sections = await _repo.loadSections('', limit: 10000);
    if (!mounted) return;
    setState(() {
      _scopeSections = sections;
      _loadingScopeSections = false;
    });
  }
}

class _SearchStrip extends StatelessWidget {
  final TextEditingController controller;
  final List<LibraryEntityRow> sections;
  final String? selectedSectionId;
  final ValueChanged<String?> onSectionChanged;
  final VoidCallback onScopeOpened;
  final bool loadingScopes;
  final VoidCallback onOpenSearch;
  final VoidCallback onSearch;

  const _SearchStrip({
    required this.controller,
    required this.sections,
    required this.selectedSectionId,
    required this.onSectionChanged,
    required this.onScopeOpened,
    required this.loadingScopes,
    required this.onOpenSearch,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: AppChrome.surfaceDecoration(
          radius: AppChrome.radiusLarge,
          shadow: true,
        ),
        child: Row(
          children: [
            _SearchSubmitButton(onTap: () {
              onSearch();
            }),
            const SizedBox(width: 12),
            _SearchScopeMenu(
              sections: sections,
              selectedSectionId: selectedSectionId,
              onChanged: onSectionChanged,
              onOpened: onScopeOpened,
              loading: loadingScopes,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  onSearch();
                },
                decoration: InputDecoration(
                  hintText: 'ابحث في الكتب',
                  hintStyle: mediumStyle(
                    color: accentColor.withOpacity(0.58),
                    fontSize: 20,
                  ),
                  border: InputBorder.none,
                ),
                style: mediumStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onOpenSearch,
              child: Text('بحث متقدم', style: normalStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchScopeMenu extends StatelessWidget {
  static const _allScopeValue = '__all_library__';

  final List<LibraryEntityRow> sections;
  final String? selectedSectionId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onOpened;
  final bool loading;

  const _SearchScopeMenu({
    required this.sections,
    required this.selectedSectionId,
    required this.onChanged,
    required this.onOpened,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    var label = 'كل المكتبة';
    if (selectedSectionId != null) {
      for (final section in sections) {
        if (section.id == selectedSectionId) {
          label = section.title;
          break;
        }
      }
    }
    return PopupMenuButton<String>(
      initialValue: selectedSectionId ?? _allScopeValue,
      tooltip: 'نطاق البحث',
      onOpened: onOpened,
      onSelected: (value) {
        onChanged(value == _allScopeValue ? null : value);
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: _allScopeValue,
          child: Text('كل المكتبة', textAlign: TextAlign.right),
        ),
        if (loading)
          const PopupMenuItem<String>(
            enabled: false,
            value: '__loading__',
            child: Text('جاري تحميل التصنيفات...', textAlign: TextAlign.right),
          ),
        for (final section in sections)
          PopupMenuItem<String>(
            value: section.id,
            child: Text(section.title, textAlign: TextAlign.right),
          ),
      ],
      child: _SearchChip(label: label),
    );
  }
}

class _HomeEntryGrid extends StatelessWidget {
  final _HomeStartData data;
  final VoidCallback onOpenBooks;
  final VoidCallback onOpenRecitedText;
  final VoidCallback onOpenAuthors;
  final VoidCallback onOpenSearch;

  const _HomeEntryGrid({
    required this.data,
    required this.onOpenBooks,
    required this.onOpenRecitedText,
    required this.onOpenAuthors,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      _Entry('القرآن الكريم', 'النص والتفاسير', Icons.auto_stories_rounded, onOpenRecitedText),
      _Entry('الكتب', '${data.bookCount} كتاب', Icons.menu_book_rounded, onOpenBooks),
      _Entry('المؤلفون', '${data.authorCount} مؤلف', Icons.people_alt_outlined, onOpenAuthors),
      _Entry('البحث المتقدم', 'بحث مخصص', Icons.manage_search_rounded, onOpenSearch),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 760
            ? constraints.maxWidth
            : (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [for (final entry in entries) _EntryCard(entry: entry, width: width)],
        );
      },
    );
  }
}
