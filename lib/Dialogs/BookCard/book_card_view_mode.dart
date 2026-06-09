import 'package:flutter/material.dart';
import '../../Models/BookCard.dart';
import '../../Models/BookMetadataOptions.dart';

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
        Text(
          book.title.isEmpty ? 'لا يوجد عنوان' : book.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                authorName.isEmpty ? 'مؤلف غير محدد' : authorName,
                style: theme.textTheme.titleMedium,
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                sectionTitle.isEmpty ? 'قسم غير محدد' : sectionTitle,
                style: theme.textTheme.titleMedium,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _infoLine(theme, 'النوع', BookMetadataOptions.typeLabel(book.bookType)),
        _infoLine(
          theme,
          'التقييم',
          book.matchesPrinted == true ? 'موافق للمطبوع' : 'غير موافق للمطبوع',
        ),
        if (book.publisher.isNotEmpty) _infoLine(theme, 'الناشر', book.publisher),
        if (book.edition.isNotEmpty) _infoLine(theme, 'الطبعة', book.edition),
        if (book.pageCount.isNotEmpty)
          _infoLine(theme, 'عدد الصفحات', book.pageCount),
        if (book.bookCardNotes.isNotEmpty)
          _infoLine(theme, 'ملاحظات البطاقة', book.bookCardNotes),
        const SizedBox(height: 12),
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

  Widget _infoLine(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: theme.textTheme.bodyLarge,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
