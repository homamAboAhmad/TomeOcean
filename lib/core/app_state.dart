import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:golden_shamela/Models/WordDocument.dart';

/// إدارة الحالة العامة للتطبيق
class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  List<WordDocument> openedBooks = [WordDocument()];
  Archive docArchive = Archive();

  List<Map<String, dynamic>>? cachedIndexedBooks;
  bool isLoadingIndexedBooks = false;
  String? mainWindowId;

  /// Callback for TOC navigation - set by DocViewer
  void Function(int pageIndex)? onTocNavigate;

  /// Search highlighting state - words to highlight when navigating from search results
  List<String> searchHighlightTerms = [];

  /// Search target: page index to scroll to after navigation (null = no target)
  int? searchTargetPageIndex;

  /// Search target: paragraph index within the page to scroll to (null = page only)
  int? searchTargetParagraphIndex;

  /// Clear search highlighting
  void clearSearchHighlight() {
    searchHighlightTerms = [];
    searchTargetPageIndex = null;
    searchTargetParagraphIndex = null;
  }

  /// Set search highlighting terms
  void setSearchHighlight(List<String> terms) {
    searchHighlightTerms = terms;
  }

  /// Set the search scroll target (page + paragraph)
  void setSearchTarget(int pageIndex, int? paragraphIndex) {
    searchTargetPageIndex = pageIndex;
    searchTargetParagraphIndex = paragraphIndex;
  }
}
