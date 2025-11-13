// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SectPr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SectPr _$SectPrFromJson(Map<String, dynamic> json) => SectPr.emptyJson()
  ..width = (json['width'] as num?)?.toDouble()
  ..height = (json['height'] as num?)?.toDouble()
  ..topMargin = (json['topMargin'] as num).toDouble()
  ..bottomMargin = (json['bottomMargin'] as num).toDouble()
  ..leftMargin = (json['leftMargin'] as num).toDouble()
  ..rightMargin = (json['rightMargin'] as num).toDouble()
  ..firstRange = (json['firstRange'] as num).toInt()
  ..lastRange = (json['lastRange'] as num).toInt()
  ..footer = const XmlElementConverter().fromJson(json['footer'] as String?)
  ..headerFirst = const XmlElementConverter().fromJson(
    json['headerFirst'] as String?,
  )
  ..headerEven = const XmlElementConverter().fromJson(
    json['headerEven'] as String?,
  )
  ..headerOdd = const XmlElementConverter().fromJson(
    json['headerOdd'] as String?,
  )
  ..headerDefault = const XmlElementConverter().fromJson(
    json['headerDefault'] as String?,
  )
  ..sectPrElement = const XmlElementConverter().fromJson(
    json['sectPrElement'] as String?,
  );

Map<String, dynamic> _$SectPrToJson(SectPr instance) => <String, dynamic>{
  'width': instance.width,
  'height': instance.height,
  'topMargin': instance.topMargin,
  'bottomMargin': instance.bottomMargin,
  'leftMargin': instance.leftMargin,
  'rightMargin': instance.rightMargin,
  'firstRange': instance.firstRange,
  'lastRange': instance.lastRange,
  'footer': const XmlElementConverter().toJson(instance.footer),
  'headerFirst': const XmlElementConverter().toJson(instance.headerFirst),
  'headerEven': const XmlElementConverter().toJson(instance.headerEven),
  'headerOdd': const XmlElementConverter().toJson(instance.headerOdd),
  'headerDefault': const XmlElementConverter().toJson(instance.headerDefault),
  'sectPrElement': const XmlElementConverter().toJson(instance.sectPrElement),
};
