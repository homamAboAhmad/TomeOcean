import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ExeRunner {
  final String assetPath = 'assets/exe/pageRender.exe';
  final String exeFileName = 'pageRender.exe';

  // ⚠️ للتطوير: true = تشغيل Python مباشرة، false = تشغيل exe
  // عند الانتهاء من التطوير، غيّرها إلى false وأعد بناء الـ exe
  static const bool USE_PYTHON = kDebugMode;
  static const String PYTHON_SCRIPT =
      r'd:\ImportantProjects\golden_shamela\scripts\pageRender.py';

  /// الحصول على مسار الملف التنفيذي بأمان
  Future<String> getExePath() async {
    final String resolvedExecutable = Platform.resolvedExecutable;
    final String appDir = File(resolvedExecutable).parent.path;
    
    // 1. Check inside assets (Release mode)
    final String assetExePath = '$appDir\\data\\flutter_assets\\$assetPath';
    if (await File(assetExePath).exists()) {
      return assetExePath;
    }

    // 2. Fallback: Copy to ApplicationSupportDirectory (safer than Temp, less AV interference)
    final supportDir = await getApplicationSupportDirectory();
    final exeFile = File('${supportDir.path}\\$exeFileName');

    try {
      final byteData = await rootBundle.load(assetPath);
      final newFileSize = byteData.lengthInBytes;
      
      // Check if existing file needs update (compare size as version check)
      bool needsUpdate = true;
      if (await exeFile.exists()) {
        try {
          final existingSize = await exeFile.length();
          if (existingSize == newFileSize) {
            needsUpdate = false;
          } else {
            // Delete old version to replace it
            await exeFile.delete();
          }
        } catch (e) {
          print('Could not check existing exe size: $e');
        }
      }
      
      if (needsUpdate) {
        await exeFile.writeAsBytes(byteData.buffer.asUint8List());
        print('✓ pageRender.exe extracted/updated to: ${exeFile.path}');
      }
    } catch (e) {
      // If it fails (e.g. file is locked because it's running), just use the existing one if it exists
      if (!await exeFile.exists()) {
        print('Error extracting exe: $e');
      } else {
        print('Warning: Could not update exe (may be in use), using existing version: $e');
      }
    }

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
      final exePath = await getExePath();
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
