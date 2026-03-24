import 'dart:io';

import '../Controllers/PathController.dart';
import 'package:path/path.dart' as p;

loadBooks() async {
  final dir = Directory(BOOKS_FOLDER_PATH);
  if (await dir.exists()) {
    final files = dir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return !name.startsWith('~\$') &&
          !name.startsWith('_temp_') &&
          name.toLowerCase().endsWith('.docx');
    }).toList();

    return files;
  }
}

/// يحذف أي ملفات مؤقتة (_temp_*.docx) متبقية في مجلد المكتبة
Future<void> cleanTempBooks() async {
  final dir = Directory(BOOKS_FOLDER_PATH);
  if (!await dir.exists()) return;

  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name.startsWith('_temp_') && name.toLowerCase().endsWith('.docx')) {
      try {
        await entity.delete();
      } catch (_) {
        // تجاهل أي فشل في الحذف لكي لا يوقف التشغيل
      }
    }
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
