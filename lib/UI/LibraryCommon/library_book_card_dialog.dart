import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:sqflite/sqflite.dart';

import 'library_book_card_panel.dart';
import 'library_icon.dart';
import 'library_book_item.dart';

Future<void> showLibraryBookCardDialog(
  BuildContext context, {
  required String title,
  String? bookPath,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _LibraryBookCardDialog(title: title, bookPath: bookPath),
  );
}

class _LibraryBookCardDialog extends StatelessWidget {
  final String title;
  final String? bookPath;

  const _LibraryBookCardDialog({required this.title, this.bookPath});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = (screenSize.width * 0.36).clamp(480.0, 620.0).toDouble();
    final height = (screenSize.height * 0.48).clamp(380.0, 540.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: [
              _DialogHeader(onClose: () => Navigator.of(context).pop()),
              Expanded(
                child: FutureBuilder<LibraryBookItem>(
                  future: _loadItem(),
                  builder: (_, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return LibraryBookCardPanel(item: snapshot.data);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<LibraryBookItem> _loadItem() async {
    final db = BooksMetadataDatabase();
    await db.initialize();
    final database = await db.database;
    final row = await _queryBookRow(database);
    if (row == null) {
      return LibraryBookItem(
        bookPath: bookPath ?? '',
        book: BookCard(title: title),
      );
    }
    return LibraryBookItem(
      bookPath: row['book_path'] as String? ?? bookPath ?? '',
      book: BookCard.fromDatabaseRow(row),
      authorName: row['author_name'] as String? ?? '',
      authorDeathYear: row['author_death_year'] as String? ?? '',
      authorDescription: row['author_description'] as String? ?? '',
      sectionTitle: row['section_title'] as String? ?? '',
    );
  }

  Future<Map<String, Object?>?> _queryBookRow(Database database) async {
    final path = bookPath;
    final rows = path == null || path.isEmpty
        ? await _queryByTitle(database)
        : await _queryByPath(database, path);
    if (rows.isEmpty && path != null && path.isNotEmpty) {
      final fallbackRows = await _queryByTitle(database);
      return fallbackRows.isEmpty ? null : fallbackRows.first;
    }
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> _queryByPath(
    Database database,
    String path,
  ) {
    return database.rawQuery(_bookDetailsSql('b.book_path = ?'), [path]);
  }

  Future<List<Map<String, Object?>>> _queryByTitle(Database database) {
    return database.rawQuery(_bookDetailsSql('b.book_name = ?'), [title]);
  }

  String _bookDetailsSql(String whereClause) => '''
      SELECT b.*,
             a.name AS author_name,
             a.death_year AS author_death_year,
             a.description AS author_description,
             s.title AS section_title
      FROM books b
      LEFT JOIN authors a ON a.id = b.author_id
      LEFT JOIN sections s ON s.id = b.section_id
      WHERE $whereClause
      LIMIT 1
    ''';
}

class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'إغلاق',
            onPressed: onClose,
            icon: const LibraryIcon(LibraryIconType.close),
          ),
          const Spacer(),
          const Text(
            'بطاقة الكتاب',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
