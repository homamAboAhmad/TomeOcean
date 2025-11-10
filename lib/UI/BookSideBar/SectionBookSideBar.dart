// lib/ui/widgets/books_sidebar.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

import '../../Helpers/BookCardStorage.dart';
import '../../Helpers/BookFilesHelper.dart';
import '../../Models/BookCard.dart';

class SectionBookSideBar extends StatefulWidget {
  final String sectionId;
  final Function(File) onBookSelected;

  const SectionBookSideBar({
    Key? key,
    required this.sectionId,
    required this.onBookSelected,
  }) : super(key: key);

  @override
  State<SectionBookSideBar> createState() => _SectionBookSideBarState();
}

class _SectionBookSideBarState extends State<SectionBookSideBar> {
  final BookCardStorage _storage = BookCardStorage();
  List<BookCard> _allBooks = [];
  List<BookCard> _filteredBooks = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBooksForSection();
    // الاستماع للتغييرات في حقل البحث
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // تحميل الكتب الخاصة بالقسم المحدد
  void _loadBooksForSection() {
    final allBooks = _storage.getBookCardList();
    _allBooks = allBooks
        .where(
          (book) => book.sectionId == widget.sectionId,
        )
        .toList();
    _filterBooks();
  }

  // تصفية الكتب بناءً على نص البحث
  void _filterBooks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _allBooks;
      } else {
        _filteredBooks = _allBooks.where((book) {
          // البحث في العنوان والمؤلف والوصف
          return book.title.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس الواجهة الجانبية (تم تعديله)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text(
              widget.sectionId,
              style: normalStyle(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
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
                            File? bookFile =
                                await loadBookByName(bookCard.title);

                            if (bookFile != null)
                              widget.onBookSelected(bookFile);
                            else
                              print("bookFile = null");
                            // يمكنك إزالة هذا السطر إذا كنت لا تريد إغلاق السايد بار تلقائياً
                            // Navigator.of(context).pop();
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
