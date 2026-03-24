import 'dart:io';

void main() async {
  final tempDir = Directory.systemTemp;
  final exePath = '${tempDir.path}\\dummy_test_lock.exe';
  
  final file = File(exePath);
  await file.writeAsBytes([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]); // MZ
  
  final raf = await file.open(mode: FileMode.write);
  
  try {
    // Try to write to it using dart File API
    await File(exePath).writeAsBytes([1, 2, 3]);
    print('SUCCESS');
  } catch (e) {
    print('ERROR: $e');
  } finally {
    await raf.close();
  }
}
