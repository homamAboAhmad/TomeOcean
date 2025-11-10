// lib/models/book_card.dart

import 'package:golden_shamela/Utils/NumberUtils.dart';

class BookCard {
   String title;
   String sectionId;      // معرف القسم أو الفئة
   String authorId;       // معرف المؤلف
   String description;  // ملخص أو وصف قصير
   String id;           // معرف فريد للكتاب

  BookCard({
    String? id,
     this.title= '',
     this.sectionId='',
     this.authorId='',
    this.description = '',
  }) : id = id ?? generateRandomKey();

  // تحويل من JSON إلى كائن
  factory BookCard.fromJson(Map<String, dynamic> json) {
    return BookCard(
      title: json['title'] ?? '',
      sectionId: json['sectionId'] ?? '',
      authorId: json['authorId'] ?? '',
      description: json['description'] ?? '',
      id: json['id'] ??generateRandomKey(),
    );
  }

  // تحويل الكائن إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sectionId': sectionId,
      'authorId': authorId,
      'description': description,
      'id': id,
    };
  }

  /// دالة copyWith لتعديل خصائص معينة وإنشاء كائن جديد
  BookCard copyWith({
    String? title,
    String? authorId,
    String? sectionId,
    String? description,
    String? id,
  }) {
    return BookCard(
      id: id ?? this.id,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      sectionId: sectionId ?? this.sectionId,
      description: description ?? this.description,
    );
  }
}