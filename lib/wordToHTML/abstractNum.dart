// كلاس AbstractNum لتمثيل تعريف الترقيم في مستند Word
import 'package:json_annotation/json_annotation.dart';
import 'package:xml/xml.dart';

part 'abstractNum.g.dart';

@JsonSerializable(explicitToJson: true)
class AbstractNum {
  final int abstractNumId; // معرف الترقيم
   Map<int, Level>
      levelsMap; // قائمة من الكائنات Level التي تمثل مستويات القائمة

  // مُنشئ الكلاس الذي يأخذ المعرف وقائمة المستويات
  AbstractNum({required this.abstractNumId, required this.levelsMap});

  AbstractNum.empty() : abstractNumId = 0, levelsMap = {};

  factory AbstractNum.fromJson(Map<String, dynamic> json) => _$AbstractNumFromJson(json);
  Map<String, dynamic> toJson() => _$AbstractNumToJson(this);

  static AbstractNum fromMap(Map<String, dynamic> json) {
    final abstractNum = _$AbstractNumFromJson(json);
    abstractNum.levelsMap = (json['levelsMap'] as Map<String, dynamic>).map(
            (k, e) => MapEntry(int.parse(k), Level.fromMap(e as Map<String, dynamic>)));
    return abstractNum;
  }

  // ميثود لتحويل عنصر XML إلى كائن Dart من نوع AbstractNum
  factory AbstractNum.fromXml(XmlElement xml) {
    // استخراج معرف الترقيم من السمة w:abstractNumId
    final abstractNumId = int.parse(xml.getAttribute('w:abstractNumId') ?? '0');
    // استخراج مستويات القائمة من عناصر w:lvl

    Map<int, Level> levelsMap = {};
    xml.findElements('w:lvl').forEach((lvlXml) {
      Level level = Level.fromXml(lvlXml);
      levelsMap[level.ilvl] = level;
    });
    // إنشاء كائن AbstractNum باستخدام المعرف وقائمة المستويات
    return AbstractNum(
      abstractNumId: abstractNumId,
      levelsMap: levelsMap,
    );
  }
}

// كلاس Level لتمثيل مستوى فردي في قائمة الترقيم
@JsonSerializable(explicitToJson: true)
class Level {
  final int
      ilvl; // مستوى القائمة (0 يمثل المستوى الأول، 1 يمثل المستوى الثاني، إلخ)
  final int startVal; // قيمة البداية للترقيم في هذا المستوى
  final String numFmt; // تنسيق الترقيم (مثل: decimal، roman، إلخ)
  final String lvlText; // النص المرتبط بالتنقيط (مثل: %1، %2، إلخ)
  final String lvlJc; // المحاذاة الأفقية للنص في المستوى
  final int indentLeft; // المسافة البادئة اليسرى للمستوى
  final int indentHanging; // المسافة المعلقة للمستوى

  // مُنشئ الكلاس الذي يأخذ جميع الخصائص كمدخلات
  Level({
    required this.ilvl,
    required this.startVal,
    required this.numFmt,
    required this.lvlText,
    required this.lvlJc,
    required this.indentLeft,
    required this.indentHanging,
  });

  Level.empty() : ilvl = 0, startVal = 0, numFmt = '', lvlText = '', lvlJc = '', indentLeft = 0, indentHanging = 0;

  factory Level.fromJson(Map<String, dynamic> json) => _$LevelFromJson(json);
  Map<String, dynamic> toJson() => _$LevelToJson(this);

  static Level fromMap(Map<String, dynamic> json) {
    return _$LevelFromJson(json);
  }

  // ميثود لتحويل عنصر XML إلى كائن Dart من نوع Level
  factory Level.fromXml(XmlElement xml) {
    // استخراج قيمة مستوى القائمة من السمة w:ilvl
    final ilvl = int.parse(xml.getAttribute('w:ilvl') ?? '0');

    // استخراج قيمة بداية الترقيم من عنصر w:start
    final startVal = int.parse(
        xml.findElements('w:start').firstOrNull?.getAttribute('w:val') ?? '0');

    // استخراج تنسيق الترقيم من عنصر w:numFmt
    final numFmt =
        xml.findElements('w:numFmt').first.getAttribute('w:val') ?? '';

    // استخراج النص المرتبط بالتنقيط من عنصر w:lvlText
    final lvlText =
        xml.findElements('w:lvlText').first.getAttribute('w:val') ?? '';

    // استخراج المحاذاة الأفقية من عنصر w:lvlJc
    final lvlJc = xml.findElements('w:lvlJc').first.getAttribute('w:val') ?? '';

    // استخراج المسافة البادئة اليسرى من عنصر w:ind
    final indentLeft = int.parse(
        xml.getElement("w:pPr")?.getElement('w:ind')?.getAttribute('w:left') ??
            '0');
    // استخراج المسافة المعلقة من عنصر w:ind
    final indentHanging = int.parse(xml
            .getElement("w:pPr")
            ?.getElement('w:ind')
            ?.getAttribute('w:hanging') ??
        '0');
    // إنشاء كائن Level باستخدام القيم المستخرجة
    return Level(
      ilvl: ilvl,
      startVal: startVal,
      numFmt: numFmt,
      lvlText: lvlText,
      lvlJc: lvlJc,
      indentLeft: indentLeft,
      indentHanging: indentHanging,
    );
  }
}
