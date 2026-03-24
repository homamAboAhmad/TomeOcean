import 'dart:io';

void main() async {
  final tempDir = Directory.systemTemp;
  final exePath = '${tempDir.path}\\dummy_test_cmd_lock.exe';
  
  final file = File(exePath);
  await file.writeAsBytes([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]); // MZ
  
  // Start the process using cmd.exe
  final process = await Process.start('cmd.exe', ['/c', exePath]);
  
  // Immediately lock it for writing
  try {
    final raf = await file.open(mode: FileMode.write);
    await Future.delayed(Duration(seconds: 1));
    await raf.close();
  } catch (e) {
    print('Failed to lock: $e');
  }
  
  process.stdout.transform(SystemEncoding().decoder).listen((data) => print('STDOUT: $data'));
  process.stderr.transform(SystemEncoding().decoder).listen((data) => print('STDERR: $data'));
  
  await process.exitCode;
}
