// lib/Dialogs/Author/author_books_manager_list.dart
import 'package:flutter/material.dart';
import '../../Models/BookCard.dart';
import '../../Styles/TextSyles.dart';
import '../../Styles/AppResourses.dart';

/// Widget for displaying books list in author books manager
class AuthorBooksManagerList extends StatelessWidget {
  final List<BookCard> books;
  final Set<String> selectedBookIds;
  final Set<String> authorBookIds;
  final Function(String, bool) onBookToggle;
  final bool isLoading;

  const AuthorBooksManagerList({
    Key? key,
    required this.books,
    required this.selectedBookIds,
    required this.authorBookIds,
    required this.onBookToggle,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل الكتب...',
              style: normalStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد كتب متاحة',
              style: normalStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: books.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        final book = books[index];
        final isSelected = selectedBookIds.contains(book.id);
        final isLinked = authorBookIds.contains(book.id);

        return Container(
          decoration: BoxDecoration(
            color: isLinked
                ? primaryColor.withOpacity(0.05)
                : (isSelected ? Colors.grey.shade50 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: isLinked
                ? Border.all(color: primaryColor.withOpacity(0.2))
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onBookToggle(book.id, !isSelected),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) => onBookToggle(book.id, value ?? false),
                      activeColor: primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: TextDirection.rtl,
                        children: [
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: Text(
                                  book.title,
                                  style: normalStyle(
                                    fontSize: 14,
                                    fontWeight: isLinked
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLinked) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.link,
                                  size: 16,
                                  color: primaryColor,
                                ),
                              ],
                            ],
                          ),
                          if (isLinked) ...[
                            const SizedBox(height: 4),
                            Text(
                              'مرتبط حالياً',
                              style: normalStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w400,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ],
                      ),
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
}

