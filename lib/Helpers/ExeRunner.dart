import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ExeRunnerException implements Exception {
  final String message;
  final String executablePath;
  final List<String> arguments;
  final String stage;
  final int? exitCode;
  final String stdout;
  final String stderr;

  ExeRunnerException(
    this.message, {
    required this.executablePath,
    required this.arguments,
    required this.stage,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  @override
  String toString() {
    final buffer = StringBuffer(message);
    buffer.writeln();
    buffer.writeln('stage: $stage');
    if (exitCode != null) buffer.writeln('exitCode: $exitCode');
    buffer.writeln('executable: $executablePath');
    buffer.writeln('arguments: ${arguments.join(' ')}');
    if (stderr.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('stderr:');
      buffer.write(stderr.trim());
    }
    if (stdout.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('stdout:');
      buffer.write(stdout.trim());
    }
    return buffer.toString().trimRight();
  }
}

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
      final bundledExeBytes = byteData.buffer.asUint8List();
      
      // Check if existing file needs update by comparing the actual bytes.
      bool needsUpdate = true;
      if (await exeFile.exists()) {
        try {
          final existingBytes = await exeFile.readAsBytes();
          if (_bytesEqual(existingBytes, bundledExeBytes)) {
            needsUpdate = false;
          } else {
            // Delete old version to replace it
            await exeFile.delete();
          }
        } catch (e) {
          print('Could not compare existing exe bytes: $e');
        }
      }
      
      if (needsUpdate) {
        await exeFile.writeAsBytes(bundledExeBytes);
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
    late final String executablePath;
    late final List<String> processArgs;

    if (USE_PYTHON) {
      // وضع التطوير: تشغيل Python مباشرة
      executablePath = 'python';
      processArgs = args;
    } else {
      // وضع الإنتاج: تشغيل exe
      final exePath = await getExePath();
      executablePath = exePath;
      processArgs = [
        outputFolder,
        inputFile,
        '--stage=$stage',
      ];
    }

    try {
      process = await Process.start(
        executablePath,
        processArgs,
        runInShell: true,
      );
    } catch (e) {
      throw ExeRunnerException(
        'Failed to start external processing tool.',
        executablePath: executablePath,
        arguments: processArgs,
        stage: stage,
        stderr: e.toString(),
      );
    }

    // إرسال مرجع العملية للمتصل (للإلغاء لاحقاً)
    onProcessStarted?.call(process);

    // الاستماع للمخرجات
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    // Python tracebacks are multi-line. Prefix stderr line-by-line so the UI
    // keeps the real exception line instead of showing only "Traceback...".
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stdoutBuffer.writeln(line);
          onOutput(line);
        });

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stderrBuffer.writeln(line);
          onOutput('ERROR:$line');
        });

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);

    if (exitCode != 0) {
      throw ExeRunnerException(
        'External processing tool failed.',
        executablePath: executablePath,
        arguments: processArgs,
        stage: stage,
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    }
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

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.lengthInBytes != b.lengthInBytes) return false;
    for (int i = 0; i < a.lengthInBytes; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
