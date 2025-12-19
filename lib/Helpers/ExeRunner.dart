import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ExeRunner {
  final String assetPath = 'assets/exe/pageRender.exe';
  final String exeFileName = 'pageRender.exe';

  // ⚠️ للتطوير: true = تشغيل Python مباشرة، false = تشغيل exe
  // عند الانتهاء من التطوير، غيّرها إلى false وأعد بناء الـ exe
  static const bool USE_PYTHON = true;
  static const String PYTHON_SCRIPT =
      r'd:\ImportantProjects\golden_shamela\scripts\pageRender.py';

  /// نسخ ملف exe من assets إلى مجلد مؤقت مرة واحدة فقط
  Future<String> copyExeIfNeeded() async {
    final tempDir = await getTemporaryDirectory();
    final exeFile = File('${tempDir.path}\\$exeFileName');

    if (!await exeFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await exeFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    return exeFile.path;
  }

  /// تشغيل الملف التنفيذي مع تمرير المدخلات والاستماع للمخرجات
  Future<void> runExe(
    String outputFolder,
    String inputFile,
    void Function(String) onOutput,
  ) async {
    late Process process;

    if (USE_PYTHON) {
      // وضع التطوير: تشغيل Python مباشرة
      process = await Process.start('python', [
        PYTHON_SCRIPT,
        outputFolder,
        inputFile,
      ], runInShell: true);
    } else {
      // وضع الإنتاج: تشغيل exe
      final exePath = await copyExeIfNeeded();
      process = await Process.start(exePath, [
        outputFolder,
        inputFile,
      ], runInShell: true);
    }

    // الاستماع للمخرجات
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      onOutput(data);
    });

    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      onOutput('ERROR:$data');
    });

    await process.exitCode;
  }
}
