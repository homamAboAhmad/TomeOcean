import 'dart:io';

String getAssetsPath() {
  final String executablePath = Platform.resolvedExecutable;
  final programDirectory = Directory(executablePath).parent;

  return '${programDirectory.path}\\data\\flutter_assets';
}
