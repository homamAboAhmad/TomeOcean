import 'dart:io';

void main() async {
  try {
    final file = File('test_access.txt');
    await file.writeAsString('test');
    await Process.run('attrib', ['+r', 'test_access.txt']);
    await file.writeAsString('test2');
  } catch (e) {
    print('Error caught:');
    print(e.toString().split('\n').first);
    print('---');
    print(e.toString());
  }
}
