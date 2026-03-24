import 'dart:io';

void main() async {
  final tempDir = Directory.systemTemp;
  final exePath = '${tempDir.path}\\dummy_test_access.exe';
  
  // Create an empty file to act as the exe
  final file = File(exePath);
  await file.writeAsBytes([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]); // MZ header
  
  // Lock the file using a persistent open handle
  final raf = await file.open(mode: FileMode.write);
  
  try {
    final process = await Process.start(exePath, [], runInShell: true);
    
    process.stdout.transform(SystemEncoding().decoder).listen((data) => print('STDOUT: $data'));
    process.stderr.transform(SystemEncoding().decoder).listen((data) => print('STDERR: $data'));
    
    await process.exitCode;
  } catch (e) {
    print('EXCEPTION: $e');
  } finally {
    await raf.close();
  }
}
