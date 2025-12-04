// lib/Dialogs/Author/author_details_books_list.dart
import 'package:flutter/material.dart';
import '../../Models/BookCard.dart';
import '../../Styles/TextSyles.dart';

/// Widget for displaying author's books list
class AuthorDetailsBooksList extends StatelessWidget {
  final List<BookCard> books;
  final Function(BookCard)? onBookTap;
  final bool isLoading;

  const AuthorDetailsBooksList({
    Key? key,
    required this.books,
    this.onBookTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'كتب المؤلف',
              style: normalStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '${books.length}',
              style: normalStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: books.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد كتب مرتبطة بهذا المؤلف',
                          style: normalStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: books.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onBookTap != null ? () => onBookTap!(book) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Icon(
                                Icons.menu_book,
                                size: 18,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  book.title,
                                  style: normalStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
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
      ],
    );
  }
}

