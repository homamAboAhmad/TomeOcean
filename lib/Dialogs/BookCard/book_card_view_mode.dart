// lib/ui/dialog_widgets/book_card_view_mode.dart
import 'package:flutter/material.dart';
import '../../Models/BookCard.dart';

class BookCardViewMode extends StatelessWidget {
  final BookCard book;
  final String sectionTitle;
  final String authorName;

  const BookCardViewMode({
    Key? key,
    required this.book,
    required this.sectionTitle,
    required this.authorName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // عنوان الكتاب
        Text(
          book.title.isEmpty ? 'لا يوجد عنوان' : book.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),

        // بيانات المؤلف والقسم
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              authorName.isEmpty ? 'مؤلف غير محدد' : authorName,
              style: theme.textTheme.titleMedium,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(width: 16),
            Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              sectionTitle.isEmpty ? 'قسم غير محدد' : sectionTitle,
              style: theme.textTheme.titleMedium,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // الوصف
        Text(
          book.description.isEmpty ? 'لا يوجد وصف.' : book.description,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}