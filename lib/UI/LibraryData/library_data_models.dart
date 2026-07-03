import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';

enum LibraryDataSection { authors, books, briefs }

enum LibraryDataItemType { author, book, brief }

extension LibraryDataSectionLabel on LibraryDataSection {
  String get label {
    switch (this) {
      case LibraryDataSection.authors:
        return 'المؤلفون';
      case LibraryDataSection.books:
        return 'الكتب';
      case LibraryDataSection.briefs:
        return 'النبذات';
    }
  }

  IconData get icon {
    switch (this) {
      case LibraryDataSection.authors:
        return Icons.history_edu;
      case LibraryDataSection.books:
        return Icons.menu_book;
      case LibraryDataSection.briefs:
        return Icons.sticky_note_2_outlined;
    }
  }
}

extension LibraryDataItemTypeLabel on LibraryDataItemType {
  IconData get icon {
    switch (this) {
      case LibraryDataItemType.author:
        return Icons.person_outline;
      case LibraryDataItemType.book:
        return Icons.menu_book_outlined;
      case LibraryDataItemType.brief:
        return Icons.sticky_note_2_outlined;
    }
  }
}

class LibraryDataSearchResult {
  final LibraryDataItemType type;
  final String title;
  final String snippet;
  final Author? author;
  final LibraryBookItem? book;

  const LibraryDataSearchResult({
    required this.type,
    required this.title,
    required this.snippet,
    this.author,
    this.book,
  });
}

class LibraryDataSnapshot {
  final List<Author> authors;
  final List<LibraryBookItem> books;
  final List<LibraryBookItem> briefBooks;
  final Map<String, int> authorBookCounts;

  const LibraryDataSnapshot({
    required this.authors,
    required this.books,
    required this.briefBooks,
    required this.authorBookCounts,
  });
}
