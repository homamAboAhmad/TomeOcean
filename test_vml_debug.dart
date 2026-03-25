import 'package:archive/archive.dart';
import 'package:golden_shamela/Utils/ArchiveToXml.dart';
import 'package:golden_shamela/wordToHTML/DocRelations.dart';
import 'package:golden_shamela/wordToHTML/ExtractWordImages.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'dart:io';

void main() async {
  print('=== VML Image Loading Diagnostic ===\n');

  // Test with a sample docx file
  String docxPath = 'assets/files/test_file.docx';
  if (!File(docxPath).existsSync()) {
    print('❌ File not found: $docxPath');
    return;
  }

  print('📄 Loading: $docxPath');
  var bytes = File(docxPath).readAsBytesSync();
  var archive = Archive(bytes.buffer);

  // Convert to map
  Map<String, ArchiveFile> archiveMap = {};
  for (var file in archive.files) {
    if (file.isFile) {
      archiveMap[file.name] = file;
    }
  }

  // 1. Extract images
  print('\n1️⃣ Extracting images...');
  var docImages = await extractImagesFromDocx(archiveMap);
  print('   Found ${docImages.length} images:');
  docImages.keys.forEach((key) {
    print('   - $key (${docImages[key]!.length} bytes)');
  });

  // 2. Parse relationships
  print('\n2️⃣ Parsing relationships...');
  var relIdList = addDocRelations(archiveMap);
  print('   Found ${relIdList.length} relationships:');
  relIdList.forEach((rId, rel) {
    print('   - $rId -> ${rel.Target} (${rel.Type})');
  });

  // 3. Check document.xml for VML images
  print('\n3️⃣ Scanning document.xml for VML images...');
  var docFile = archiveMap['word/document.xml'];
  if (docFile != null) {
    var doc = ArchiveToXml(docFile);
    var picts = doc.findAllElements('w:pict');
    print('   Found ${picts.length} VML <w:pict> elements');

    for (var i = 0; i < picts.length; i++) {
      var pict = picts.elementAt(i);
      var imagedatas = pict.findAllElements('v:imagedata');
      print('   Pict #$i: ${imagedatas.length} v:imagedata elements');

      for (var j = 0; j < imagedatas.length; j++) {
        var imagedata = imagedatas.elementAt(j);
        var rId = imagedata.getAttribute('r:id');
        print('     - rId: $rId');

        if (rId != null) {
          var target = relIdList[rId]?.Target;
          print('       Target: $target');
          if (target != null && docImages.containsKey(target)) {
            print('       ✅ Image data found in docImages!');
          } else if (target != null) {
            print('       ❌ Image data NOT found. Available keys: ${docImages.keys.join(', ')}');
          }
        }
      }
    }
  }

  // 4. Test WordDocument structure
  print('\n4️⃣ Testing WordDocument structure...');
  var wordDocument = WordDocument();
  wordDocument.docImages = docImages;
  wordDocument.relIdList = relIdList;

  print('   WordDocument.docImages: ${wordDocument.docImages.length} entries');
  print('   WordDocument.relIdList: ${wordDocument.relIdList.length} entries');

  // 5. Simulate image loading for rId15
  print('\n5️⃣ Simulating image load for rId15...');
  // Simulate an ImageData with rId15
  var testRId = 'rId15';
  var target = relIdList[testRId]?.Target;
  print('   rId15 -> Target: $target');

  if (target != null) {
    if (docImages.containsKey(target)) {
      print('   ✅ Image data exists: ${docImages[target]!.length} bytes');
    } else {
      print('   ❌ Image data missing. Available keys:');
      docImages.keys.forEach((key) {
        print('      - $key');
      });
    }
  } else {
    print('   ❌ rId15 not found in relIdList');
  }

  print('\n=== End Diagnostic ===');
}
