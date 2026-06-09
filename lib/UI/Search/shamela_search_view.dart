import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Search/helpers/search_highlighting_helper.dart';
import 'package:golden_shamela/UI/Search/widgets/no_results_widget.dart';
import 'package:golden_shamela/UI/WordPageScreen.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import 'package:golden_shamela/Helpers/TextProcessor.dart';
import 'package:golden_shamela/core/app_state.dart';

/// Shamela-style search results view:
/// top = page preview, bottom = results list, draggable divider.
class ShamelaSearchView extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final int totalCount;
  final List<String> searchQueries;
  final bool morphologicalSearch;
  final bool isSearching;
  final Function(String bookPath, int pageIndex) onOpenBookFull;
  final Function(String query, bool morphological)? onNewSearch;
  final VoidCallback? onNewSearchDialog;
  final VoidCallback? onStopSearch;

  const ShamelaSearchView({
    Key? key,
    required this.results,
    required this.totalCount,
    required this.searchQueries,
    required this.morphologicalSearch,
    this.isSearching = false,
    required this.onOpenBookFull,
    this.onNewSearch,
    this.onNewSearchDialog,
    this.onStopSearch,
  }) : super(key: key);

  @override
  State<ShamelaSearchView> createState() => _ShamelaSearchViewState();
}

class _ShamelaSearchViewState extends State<ShamelaSearchView> {
  // ── Preview ──
  WordDocument? _previewDoc;
  WordPage? _previewPage;
  bool _isLoadingPreview = false;
  String? _previewError;
  int _selectedResultIndex = -1;

  // ── Draggable splitter fraction (top / total) ──
  double _splitFraction = 0.55;


  // ── Snippet highlighting ──
  late SearchHighlightingHelper _highlightingHelper;
  final Map<int, Widget> _snippetCache = {};

  // ── Document cache keyed by book title ──
  final Map<String, WordDocument> _docCache = {};

  // ── Scroll controllers ──
  final ScrollController _resultsScrollCtrl = ScrollController();
  final ScrollController _previewScrollCtrl = ScrollController();

  // ── Paragraph key infrastructure for scroll-to-match ──
  final Map<int, GlobalKey> _paragraphKeys = {};
  int? _targetParagraphIndex;

  @override
  void initState() {
    super.initState();
    _highlightingHelper = SearchHighlightingHelper(
      morphologicalSearch: widget.morphologicalSearch,
    );
    if (widget.results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _selectResult(0));
    }
  }

  @override
  void didUpdateWidget(ShamelaSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final queriesChanged = oldWidget.searchQueries != widget.searchQueries ||
        oldWidget.morphologicalSearch != widget.morphologicalSearch;

    if (queriesChanged) {
      _snippetCache.clear();
      _highlightingHelper = SearchHighlightingHelper(
        morphologicalSearch: widget.morphologicalSearch,
      );
    }

    if (oldWidget.results != widget.results) {
      if (widget.results.isEmpty) {
        // New search started with empty results
        setState(() {
          _previewDoc = null;
          _previewPage = null;
          _selectedResultIndex = -1;
        });
      } else if (_selectedResultIndex == -1 && widget.results.isNotEmpty) {
        // First batch arrived, auto-select first result
        WidgetsBinding.instance.addPostFrameCallback((_) => _selectResult(0));
      }
      // If results just grew (streaming), don't touch selection
    }
  }

  @override
  void dispose() {
    _resultsScrollCtrl.dispose();
    _previewScrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────── Preview loading ───────────────────

  Future<void> _selectResult(int index) async {
    if (index < 0 || index >= widget.results.length) return;
    if (index == _selectedResultIndex && _previewPage != null) return;

    final result = widget.results[index];
    final bookPath = result['book_path'] as String? ?? '';
    final pageNumber = (result['page_number'] as num?)?.toInt() ?? 0;
    if (bookPath.isEmpty) return;

    setState(() {
      _selectedResultIndex = index;
      _isLoadingPreview = true;
      _previewError = null;
      _paragraphKeys.clear();
      _targetParagraphIndex = null;
    });

    try {
      AppState().setSearchHighlight(widget.searchQueries);

      final doc = await _loadDocument(bookPath);
      final targetPage = pageNumber.clamp(0, doc.pageFilePaths.length - 1);
      doc.currentPage = targetPage;
      final page = await doc.getPage(targetPage);

      // ابحث عن أول فقرة تحتوي على إحدى كلمات البحث (مع تطبيع عربي)
      int? foundParagraphIndex;
      if (widget.searchQueries.isNotEmpty) {
        final normalizedQueries = widget.searchQueries
            .map((q) => TextProcessor.normalizeArabic(q.trim()))
            .where((q) => q.isNotEmpty)
            .toList();
        for (int pIdx = 0; pIdx < page.ps.length; pIdx++) {
          final pText = TextProcessor.normalizeArabic(page.ps[pIdx].text);
          final found = normalizedQueries.any((q) => pText.contains(q));
          if (found) {
            foundParagraphIndex = pIdx;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _previewDoc = doc;
        _previewPage = page;
        _isLoadingPreview = false;
        _targetParagraphIndex = foundParagraphIndex;
      });

      if (_targetParagraphIndex != null) {
        // نحتاج إطارين: الأول ليُبنى الـ widget, الثاني ليتوفر الـ context
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToTargetParagraph();
          });
        });
      } else if (_previewScrollCtrl.hasClients) {
        _previewScrollCtrl.jumpTo(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
        _previewError = '$e';
      });
    }
  }

  void _scrollToTargetParagraph() {
    final target = _targetParagraphIndex;
    if (target == null) return;
    final ctx = _paragraphKeys[target]?.currentContext;
    if (ctx == null) {
      // لم يُبنَ بعد، حاول مرة أخرى
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTargetParagraph());
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.18,
      duration: Duration.zero,
    );
  }

  Future<WordDocument> _loadDocument(String bookPath) async {
    final title = AppStoragePaths.bookIdFromPath(bookPath);
    if (_docCache.containsKey(title)) return _docCache[title]!;

    final sourcePath = AppStoragePaths.bookSourcePath(title);
    final archivePath = await File(sourcePath).exists() ? sourcePath : bookPath;
    if (!await File(archivePath).exists()) {
      throw Exception('مصدر الكتاب مفقود. يرجى إعادة استيراده.');
    }
    final bookCacheDir = Directory(AppStoragePaths.bookDirPath(title));
    final metadataFile = File(AppStoragePaths.bookMetadataPath(title));
    final pagesDir = Directory(AppStoragePaths.bookPagesDirPath(title));

    Future<WordDocument> _loadFromCache() async {
      final json =
          jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
      final doc = WordDocument.fromCacheJson(json);
      doc.pagesDirectory = pagesDir.path;

      final pageFiles = await pagesDir.list().toList();
      pageFiles.sort((a, b) {
        final aNum = int.tryParse(p.basename(a.path).split('.').first) ?? 0;
        final bNum = int.tryParse(p.basename(b.path).split('.').first) ?? 0;
        return aNum.compareTo(bNum);
      });
      doc.pageFilePaths =
          pageFiles.map((f) => p.basename(f.path)).toList();
      doc.initLoadedPages();

      try {
        if (await File(archivePath).exists()) {
          doc.archive = await FileToArchive(archivePath);
        }
      } catch (_) {}

      _docCache[title] = doc;
      return doc;
    }

    // 1. Try existing cache
    if (await bookCacheDir.exists() && await metadataFile.exists()) {
      try {
        return await _loadFromCache();
      } catch (_) {
        await AppStoragePaths.deleteRebuildableCache(title);
      }
    }

    // 2. Cache missing → reprocess then load
    await BookProcessingService().parseAndCacheForOpening(archivePath);
    if (await metadataFile.exists()) {
      return _loadFromCache();
    }

    throw Exception('الكتاب غير مفهرس والكاش مفقود');
  }

  // ─────────────────── Snippet builder ───────────────────

  static final RegExp _pgMarkerRegex = RegExp(r'\{\{PG:\d+\}\}');

  Widget _buildSnippet(int index, String content) {
    if (_snippetCache.containsKey(index)) return _snippetCache[index]!;

    final cleaned = content.replaceAll(_pgMarkerRegex, '');
    final fallback = Text(
      cleaned.length > 120 ? '${cleaned.substring(0, 120)}...' : cleaned,
      style: smallStyle(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    return FutureBuilder<Widget>(
      future: _highlightingHelper.extractSnippetWithHighlight(
        cleaned,
        widget.searchQueries,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _snippetCache[index] = snapshot.data!;
          return snapshot.data!;
        }
        return fallback;
      },
    );
  }

  // ─────────────────── Build ───────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade200,
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalH = constraints.maxHeight;
                  const dividerH = 8.0;
                  final topH =
                      (totalH * _splitFraction).clamp(80.0, totalH - 120.0);
                  final bottomH = totalH - topH - dividerH;

                  return Column(
                    children: [
                      SizedBox(height: topH, child: _buildPreviewArea()),
                      _buildDraggableDivider(totalH),
                      SizedBox(height: bottomH, child: _buildResultsList()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Preview area ───────────────────

  Widget _buildPreviewArea() {
    if (_isLoadingPreview) {
      return Container(
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_previewError != null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text(_previewError!, style: normalStyle(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    if (_previewPage == null || _previewDoc == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('اختر نتيجة لعرضها', style: bigStyle(color: Colors.grey.shade400)),
            ],
          ),
        ),
      );
    }

    final selectedResult =
        (_selectedResultIndex >= 0 && _selectedResultIndex < widget.results.length)
            ? widget.results[_selectedResultIndex]
            : null;
    final bookName = selectedResult?['book_name'] as String? ?? '';
    final pageNum = (selectedResult?['page_number'] as num?)?.toInt() ?? 0;

    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: primaryColor.withOpacity(0.08),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$bookName — ص ${pageNum + 1}',
                    style: normalStyle(fontWeight: FontWeight.bold, color: primaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('فتح الكتاب', style: smallStyle(color: primaryColor)),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    if (selectedResult != null) {
                      widget.onOpenBookFull(
                        selectedResult['book_path'] ?? '',
                        pageNum,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _previewScrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _previewScrollCtrl,
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: WordPageScreen(
                      _previewPage!,
                      wordDocument: _previewDoc!,
                      paragraphKeyBuilder: (pIdx) =>
                          _paragraphKeys.putIfAbsent(pIdx, () => GlobalKey()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Draggable divider ───────────────────

  Widget _buildDraggableDivider(double totalHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        setState(() {
          _splitFraction += details.delta.dy / totalHeight;
          _splitFraction = _splitFraction.clamp(0.15, 0.80);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 8,
          color: Colors.grey.shade300,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────── Results list ───────────────────

  Widget _buildResultsList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Text(
                  'نتائج البحث: ${widget.results.length}',
                  style: mediumStyle(fontWeight: FontWeight.bold, color: primaryColor),
                ),
                if (widget.isSearching) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onStopSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text('إيقاف', style: smallStyle(color: Colors.red.shade700)),
                    ),
                  ),
                ] else if (widget.results.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text('اكتمل', style: smallStyle(color: Colors.green.shade700)),
                ],
                const Spacer(),
                if (widget.searchQueries.isNotEmpty)
                  Text(
                    widget.searchQueries.join(' | '),
                    style: smallStyle(color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          Expanded(
            child: widget.results.isEmpty
                ? NoResultsWidget(
                    searchQueries: widget.searchQueries,
                    onNewSearch: widget.onNewSearchDialog,
                  )
                : Scrollbar(
                    controller: _resultsScrollCtrl,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _resultsScrollCtrl,
                      itemCount: widget.results.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final r = widget.results[index];
                        final isSelected = index == _selectedResultIndex;
                        final bookName = r['book_name'] as String? ?? '';
                        final pageNum =
                            (r['page_number'] as num?)?.toInt() ?? 0;
                        final content = r['content'] as String? ?? '';

                        return Material(
                          color: isSelected
                              ? primaryColor.withOpacity(0.1)
                              : Colors.white,
                          child: InkWell(
                            onTap: () => _selectResult(index),
                            onDoubleTap: () {
                              widget.onOpenBookFull(
                                r['book_path'] ?? '',
                                pageNum,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${pageNum + 1}',
                                      style: smallStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bookName,
                                          style: mediumStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        _buildSnippet(index, content),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

}
