import 'dart:io';

import '../Controllers/PathController.dart';
import 'package:path/path.dart' as p;

loadBooks() async {
  final dir = Directory(BOOKS_FOLDER_PATH);
  if (await dir.exists()) {
    final files = dir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return !name.startsWith('~\$') && name.toLowerCase().endsWith('.docx');
    }).toList();

    return files;
  }
}

Future<File?> loadBookByName(String fileName) async {
  // إنشاء مسار كامل للملف باستخدام اسم المجلد واسم الملف
  final String filePath = '$BOOKS_FOLDER_PATH/$fileName.docx';
  final file = File(filePath);

  // التحقق مما إذا كان الملف موجوداً بالفعل
  if (await file.exists()) {
    return file;
  } else {
    // يمكنك طباعة رسالة للمساعدة في تتبع الأخطاء
    print(
      'الملف "$fileName" لم يتم العثور عليه في المسار "$BOOKS_FOLDER_PATH".',
    );
    return null;
  }
}
