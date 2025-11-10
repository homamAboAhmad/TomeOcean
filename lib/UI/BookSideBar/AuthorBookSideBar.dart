// lib/ui/widgets/author_books_sidebar.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import '../../Helpers/AuthorStorage.dart';
import '../../Helpers/BookCardStorage.dart';
import '../../Helpers/BookFilesHelper.dart';
import '../../Models/Author.dart';
import '../../Models/BookCard.dart';
class AuthorBooksSidebar extends StatefulWidget {
  final String authorId;
  final Function(File) onBookSelected;

  const AuthorBooksSidebar({
    Key? key,
    required this.authorId,
    required this.onBookSelected,
  }) : super(key: key);

  @override
  State<AuthorBooksSidebar> createState() => _AuthorBooksSidebarState();
}

class _AuthorBooksSidebarState extends State<AuthorBooksSidebar> {
  final BookCardStorage _bookCardStorage = BookCardStorage();
  final AuthorStorage _authorStorage = AuthorStorage();
  List<BookCard> _allBooks = [];
  List<BookCard> _filteredBooks = [];
  Author? _author;
  final TextEditingController _searchController = TextEditingController();

  // متغيرات للتحكم في ارتفاع قسم الوصف
  double _descriptionHeight = 150.0;
  final double _minHeight = 50.0;
  final double _maxHeight = 300.0;

  @override
  void initState() {
    super.initState();
    _loadAuthorAndBooks();
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAuthorAndBooks() {
    _author = AuthorStorage.getAuthorById(widget.authorId);
    if (_author == null) {
      setState(() {});
      return;
    }
    final allBooks = _bookCardStorage.getBookCardList();
    _allBooks = allBooks.where((book) => book.authorId == widget.authorId).toList();
    _filterBooks();
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _allBooks;
      } else {
        _filteredBooks = _allBooks.where((book) {
          return book.title.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _descriptionHeight += details.delta.dy;
      if (_descriptionHeight < _minHeight) {
        _descriptionHeight = _minHeight;
      } else if (_descriptionHeight > _maxHeight) {
        _descriptionHeight = _maxHeight;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_author == null) {
      return const SizedBox(
        width: 224,
        child: Center(child: Text('المؤلف غير موجود')),
      );
    }

    return SizedBox(
      width: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس الواجهة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text(
              _author!.name,
              style: normalStyle(fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
          ),

          // قسم وصف المؤلف (قابل للتعديل)
          SizedBox(
            height: _descriptionHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Text(
                  _author!.description.isEmpty ? 'لا يوجد وصف.' : _author!.description,
                  style: normalStyle(fontSize: 14),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ),

          // مقبض السحب
          GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 8.0,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade400),
                  bottom: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              child: Center(
                child: Container(
                  height: 4.0,
                  width: 40.0,
                  decoration: BoxDecoration(
                    color: Colors.grey[500],
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
            ),
          ),

          // حقل البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              style: normalStyle(),
              decoration: InputDecoration(
                hintTextDirection: TextDirection.rtl,
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // عرض قائمة الكتب المفلترة
          Expanded(
            child: _filteredBooks.isEmpty
                ? Center(
              child: Text(
                'لا توجد كتب مطابقة للبحث.',
                style: normalStyle(),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            )
                : ListView.builder(
              itemCount: _filteredBooks.length,
              itemBuilder: (context, index) {
                final bookCard = _filteredBooks[index];
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListTile(
                    leading: const Icon(Icons.menu_book),
                    title: Text(
                      bookCard.title,
                      style: normalStyle(),
                    ),
                    onTap: () async {
                      File? bookFile = await loadBookByName(bookCard.title);
                      if (bookFile != null) {
                        widget.onBookSelected(bookFile);
                      } else {
                        print("bookFile = null");
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}