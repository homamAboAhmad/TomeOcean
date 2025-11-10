import 'dart:io';

import '../Controllers/PathController.dart';

loadBooks() async {
  final dir = Directory(BOOKS_FOLDER_PATH);
  if (await dir.exists()) {
    final files = dir
        .listSync()
        .whereType<File>()
        // .where((f) => f.path.endsWith('.docx')) // لو حابب تحدد نوع الملفات
        .toList();

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
        'الملف "$fileName" لم يتم العثور عليه في المسار "$BOOKS_FOLDER_PATH".');
    return null;
  }
}
