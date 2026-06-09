import 'dart:io';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:golden_shamela/Services/AppStoragePaths.dart';
import '../Utils/ArchiveToXml.dart';

class EmbeddedFontExtractor {
  /// يُرجع Map<اسم_الخط, مسار_الملف_المحلي>
  static Future<Map<String, String>> extractEmbeddedFonts(
    Archive archive,
    String bookCacheDir, [
    String? sharedFontsDirPath,
  ]) async {
    Map<String, String> extractedFonts = {};
    
    Map<String, ArchiveFile> archiveMap = {};
    for (var file in archive) {
      archiveMap[file.name] = file;
    }
    
    // 1. قراءة fontTable.xml
    ArchiveFile? fontTableFile = archiveMap['word/fontTable.xml'];
    if (fontTableFile == null) return {};
    
    XmlDocument fontTableDoc = ArchiveToXml(fontTableFile);
    
    // 2. قراءة العلاقات
    ArchiveFile? relsFile = archiveMap['word/_rels/fontTable.xml.rels'];
    Map<String, String> relsMap = {};
    if (relsFile != null) {
      XmlDocument relsDoc = ArchiveToXml(relsFile);
      for (var rel in relsDoc.findAllElements('Relationship')) {
        String? id = rel.getAttribute('Id');
        String? target = rel.getAttribute('Target');
        if (id != null && target != null) {
          relsMap[id] = target;
        }
      }
    }
    
    // 3. مسار الكاش المشترك للخطوط
    late final Directory sharedFontsDir;
    if (sharedFontsDirPath != null && sharedFontsDirPath.isNotEmpty) {
      sharedFontsDir = Directory(sharedFontsDirPath);
    } else {
      sharedFontsDir = Directory(AppStoragePaths.sharedFontsPath);
    }
    if (!await sharedFontsDir.exists()) {
      await sharedFontsDir.create(recursive: true);
    }
    
    // 4. لكل خط مدمج: استخراج الملف
    for (var fontEl in fontTableDoc.findAllElements('w:font')) {
      String? fontName = fontEl.getAttribute('w:name');
      if (fontName == null) continue;
      
      // فحص كل نوع تضمين
      for (String embedType in [
        'w:embedRegular', 'w:embedBold', 
        'w:embedItalic', 'w:embedBoldItalic'
      ]) {
        var embedEl = fontEl.getElement(embedType);
        if (embedEl == null) continue;
        
        String? rId = embedEl.getAttribute('r:id');
        String? fontKey = embedEl.getAttribute('w:fontKey');
        
        if (rId == null) continue;
        String? targetPath = relsMap[rId];
        if (targetPath == null) continue;
        
        // المسار الكامل داخل الأرشيف
        String fullPath = targetPath.startsWith('/')
            ? targetPath.substring(1) 
            : 'word/$targetPath';
        
        ArchiveFile? fontFile = archiveMap[fullPath];
        if (fontFile == null) continue;
        
        List<int> rawData = fontFile.content as List<int>;
        String fontHash = md5.convert(rawData).toString();
        
        String safeFontName = fontName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        String localPath = p.join(sharedFontsDir.path, '${safeFontName}_${fontHash}_$embedType.ttf');
        File localFile = File(localPath);
        
        if (!await localFile.exists()) {
          List<int> deobfuscatedData = _deobfuscateFont(rawData, fontKey);
          await localFile.writeAsBytes(deobfuscatedData);
        }
        
        extractedFonts[fontName] = localPath;
      }
    }
    
    return extractedFonts;
  }

  /// يستعيد خرائط الخطوط المضمّنة من مجلد shared_fonts عندما تكون
  /// metadata القديمة لا تحتوي extractedFontPaths.
  static Future<Map<String, String>> recoverSharedFontPaths(
    Iterable<String> fontFamilies, [
    String? sharedFontsDirPath,
  ]) async {
    late final Directory sharedFontsDir;
    if (sharedFontsDirPath != null && sharedFontsDirPath.isNotEmpty) {
      sharedFontsDir = Directory(sharedFontsDirPath);
    } else {
      sharedFontsDir = Directory(AppStoragePaths.sharedFontsPath);
    }
    if (!await sharedFontsDir.exists()) {
      return {};
    }

    final entries = await sharedFontsDir.list().toList();
    final files = entries
        .where((entry) => entry is File)
        .cast<File>()
        .where((file) {
          final name = p.basename(file.path).toLowerCase();
          return name.endsWith('.ttf') || name.endsWith('.otf');
        })
        .toList();
    if (files.isEmpty) {
      return {};
    }

    final recovered = <String, String>{};
    for (final rawFamily in fontFamilies) {
      final family = rawFamily.trim();
      if (family.isEmpty) continue;

      final safeFontName = family.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final matches = files
          .where((file) => p.basename(file.path).startsWith('${safeFontName}_'))
          .toList();
      if (matches.isEmpty) continue;

      matches.sort((a, b) {
        final aName = p.basename(a.path).toLowerCase();
        final bName = p.basename(b.path).toLowerCase();
        final aRegular = aName.contains('embedregular.ttf');
        final bRegular = bName.contains('embedregular.ttf');
        if (aRegular != bRegular) {
          return aRegular ? -1 : 1;
        }
        return aName.compareTo(bName);
      });

      recovered[family] = matches.first.path;
    }

    return recovered;
  }
  
  /// فك تشفير الخطوط المحمية (ODTTF format)
  /// حسب مواصفات ECMA-376 Part 2:
  /// - المفتاح هو GUID بصيغة {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
  /// - يُحوَّل إلى 16 بايت مع ترتيب Little Endian للأجزاء الأولى
  /// - يُطبَّق XOR على أول 32 بايت من الملف (المفتاح يتكرر مرتين)
  static List<int> _deobfuscateFont(List<int> data, String? fontKey) {
    if (fontKey == null || fontKey.isEmpty) return data;
    
    String cleanKey = fontKey
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('-', '');
    
    if (cleanKey.length != 32) return data;
    
    // تحويل hex string إلى 16 بايت
    List<int> guidBytes = [];
    for (int i = 0; i < cleanKey.length; i += 2) {
      guidBytes.add(int.parse(cleanKey.substring(i, i + 2), radix: 16));
    }
    
    // ترتيب البايتات حسب مواصفات ODTTF (GUID Little Endian)
    // Part 1 (4 bytes): reversed | Part 2 (2 bytes): reversed
    // Part 3 (2 bytes): reversed | Parts 4-5 (8 bytes): normal
    List<int> keyBytes = [
      guidBytes[3], guidBytes[2], guidBytes[1], guidBytes[0],
      guidBytes[5], guidBytes[4],
      guidBytes[7], guidBytes[6],
      ...guidBytes.sublist(8, 16),
    ];
    
    // XOR أول 32 بايت (المفتاح 16 بايت يتكرر مرتين)
    List<int> result = List.from(data);
    for (int i = 0; i < 32 && i < result.length; i++) {
      result[i] = result[i] ^ keyBytes[i % 16];
    }
    
    return result;
  }
}
