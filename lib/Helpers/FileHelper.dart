


import 'dart:io';
import 'package:path/path.dart' as p;

String getFileName(String path){
  // file.uri.pathSegments.last.split(pattern)
  return p.basenameWithoutExtension(path);

}