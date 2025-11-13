// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'abstractNum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AbstractNum _$AbstractNumFromJson(Map<String, dynamic> json) => AbstractNum(
  abstractNumId: (json['abstractNumId'] as num).toInt(),
  levelsMap: (json['levelsMap'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(int.parse(k), Level.fromJson(e as Map<String, dynamic>)),
  ),
);

Map<String, dynamic> _$AbstractNumToJson(AbstractNum instance) =>
    <String, dynamic>{
      'abstractNumId': instance.abstractNumId,
      'levelsMap': instance.levelsMap.map(
        (k, e) => MapEntry(k.toString(), e.toJson()),
      ),
    };

Level _$LevelFromJson(Map<String, dynamic> json) => Level(
  ilvl: (json['ilvl'] as num).toInt(),
  startVal: (json['startVal'] as num).toInt(),
  numFmt: json['numFmt'] as String,
  lvlText: json['lvlText'] as String,
  lvlJc: json['lvlJc'] as String,
  indentLeft: (json['indentLeft'] as num).toInt(),
  indentHanging: (json['indentHanging'] as num).toInt(),
);

Map<String, dynamic> _$LevelToJson(Level instance) => <String, dynamic>{
  'ilvl': instance.ilvl,
  'startVal': instance.startVal,
  'numFmt': instance.numFmt,
  'lvlText': instance.lvlText,
  'lvlJc': instance.lvlJc,
  'indentLeft': instance.indentLeft,
  'indentHanging': instance.indentHanging,
};
