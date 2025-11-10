import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ExeRunner {
  final String assetPath = 'assets/exe/pageRender.exe';
  final String exeFileName = 'pageRender.exe';

  /// نسخ ملف exe من assets إلى مجلد مؤقت مرة واحدة فقط
  Future<String> copyExeIfNeeded() async {
    final tempDir = await getTemporaryDirectory();
    final exeFile = File('${tempDir.path}\\$exeFileName');

    if (!await exeFile.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await exeFile.writeAsBytes(byteData.buffer.asUint8List());
      print('Copied exe to: ${exeFile.path}');
    } else {
      print('Exe already exists at: ${exeFile.path}');
    }

    return exeFile.path;
  }

  /// تشغيل الملف التنفيذي مع تمرير المدخلات والاستماع للمخرجات
  Future<void> runExe(String outputFolder, String inputFile,void Function(String) onOutput) async {
    final exePath = await copyExeIfNeeded();

    final process = await Process.start(
      exePath,
      [outputFolder, inputFile],
      runInShell: true,
    );



    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('stdout: $data');
      onOutput(data);
    });

    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('stderr: $data');
    });

    final exitCode = await process.exitCode;
    print('Process exited with code $exitCode');
  }
}
