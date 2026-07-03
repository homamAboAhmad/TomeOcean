import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:golden_shamela/UI/Search/shamela_search_window.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/core/indexed_books_loader.dart';
import 'package:golden_shamela/UI/Search/helpers/search_window_communication.dart';

/// صفحة نافذة البحث
class SearchWindowRoute extends StatefulWidget {
  const SearchWindowRoute({Key? key}) : super(key: key);

  @override
  State<SearchWindowRoute> createState() => _SearchWindowRouteState();
}

class _SearchWindowRouteState extends State<SearchWindowRoute> {
  final AppState _appState = AppState();
  final IndexedBooksLoader _booksLoader = IndexedBooksLoader();
  final SearchWindowCommunication _communication = SearchWindowCommunication();
  
  List<Map<String, dynamic>> _indexedBooks = [];

  @override
  void initState() {
    super.initState();
    _initializeBooks();
  }

  Future<void> _initializeBooks() async {
    if (_appState.cachedIndexedBooks != null && _appState.cachedIndexedBooks!.isNotEmpty) {
      setState(() {
        _indexedBooks = List.from(_appState.cachedIndexedBooks!);
      });
    }
    
    final books = await _booksLoader.getIndexedBooks();
    if (mounted) {
      setState(() {
        _indexedBooks = books;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_indexedBooks.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text('لا توجد كتب مفهرسة', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      body: ShamelaSearchWindow(
        onSearchRequested: _handleSearchRequest,
        indexedBooks: _indexedBooks,
        onClose: () {
          _closeWindow();
        },
      ),
    );
  }

  Future<void> _handleSearchRequest(Map<String, dynamic> searchParams) async {
    await _communication.sendSearchParamsToMainWindow(searchParams);
    await _closeWindow();
  }

  Future<void> _closeWindow() async {
    final controller = await WindowController.fromCurrentEngine();
    controller.hide();
  }
}


