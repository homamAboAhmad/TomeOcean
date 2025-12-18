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
}


