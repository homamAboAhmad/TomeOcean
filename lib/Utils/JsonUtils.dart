import 'dart:convert';
import 'dart:io';

 readJsonFile(String? filePath) async {
   if(filePath==null) return;
  try {
    // تحقق مما إذا كان الملف موجودًا
    if (File(filePath).existsSync()) {
      // قراءة محتويات الملف
      String contents = await File(filePath).readAsString();

      // تحويل المحتوى من JSON إلى خريطة (Map)
      Map<String,dynamic> jsonData = jsonDecode(contents);
      return jsonData['pages'];
    } else {
      print("File does not exist: $filePath");
    }
  } catch (e) {
    print("Error reading JSON file: $e");
  }
}

