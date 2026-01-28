import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ExeRunner {
  final String assetPath = 'assets/exe/pageRender.exe';
  final String exeFileName = 'pageRender.exe';

  // ⚠️ للتطوير: true = تشغيل Python مباشرة، false = تشغيل exe
  // عند الانتهاء من التطوير، غيّرها إلى false وأعد بناء الـ exe
  static const bool USE_PYTHON = false;
  static const String PYTHON_SCRIPT =
      r'd:\ImportantProjects\golden_shamela\scripts\pageRender.py';

  /// نسخ ملف exe من assets إلى مجلد مؤقت مرة واحدة فقط
  Future<String> copyExeIfNeeded() async {
    final tempDir = await getTemporaryDirectory();
    final exeFile = File('${tempDir.path}\\$exeFileName');

    // Always overwrite to ensure we have the latest version (especially after updates)
    // if (!await exeFile.exists()) {
    final byteData = await rootBundle.load(assetPath);
    await exeFile.writeAsBytes(byteData.buffer.asUint8List());
    // }

    return exeFile.path;
  }

  /// تشغيل الملف التنفيذي مع إمكانية الإلغاء
  /// يُرجع Future يكتمل عند انتهاء العملية
  /// يمكن استخدام onProcessStarted للحصول على مرجع العملية للإلغاء
  /// stage: 'word' | 'xml' | 'full' (default)
  Future<void> runExe(
    String outputFolder,
    String inputFile,
    void Function(String) onOutput, {
    void Function(Process)? onProcessStarted,
    String stage = 'full', // Pipeline support
  }) async {
    late Process process;
    print('USE_PYTHON: $USE_PYTHON, Stage: $stage');

    final args = [PYTHON_SCRIPT, outputFolder, inputFile, '--stage=$stage'];

    if (USE_PYTHON) {
      // وضع التطوير: تشغيل Python مباشرة
      process = await Process.start('python', args, runInShell: true);
    } else {
      // وضع الإنتاج: تشغيل exe
      final exePath = await copyExeIfNeeded();
      process = await Process.start(exePath, [
        outputFolder,
        inputFile,
        '--stage=$stage',
      ], runInShell: true);
    }

    // إرسال مرجع العملية للمتصل (للإلغاء لاحقاً)
    onProcessStarted?.call(process);

    // الاستماع للمخرجات
    process.stdout.transform(utf8.decoder).listen((data) {
      onOutput(data);
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      onOutput('ERROR:$data');
    });

    await process.exitCode;
  }

  /// قتل عملية بشكل إجباري (للإلغاء)
  static void killProcess(Process? process) {
    if (process != null) {
      try {
        process.kill(ProcessSignal.sigkill);
        print('Process killed successfully');
      } catch (e) {
        print('Failed to kill process: $e');
      }
    }
  }
}
