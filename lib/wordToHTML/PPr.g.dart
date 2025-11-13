// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PPr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PPr _$PPrFromJson(Map<String, dynamic> json) => PPr.empty()
  ..textAlign = json['textAlign'] as String?
  ..rtl = json['rtl'] as bool?
  ..paddingLeft = (json['paddingLeft'] as num?)?.toDouble()
  ..paddingRight = (json['paddingRight'] as num?)?.toDouble()
  ..pStyle = json['pStyle'] as String?
  ..numId = (json['numId'] as num?)?.toInt()
  ..paragraphNumber = (json['paragraphNumber'] as num?)?.toInt()
  ..ilvl = (json['ilvl'] as num?)?.toInt()
  ..numberingH = json['numberingH'] as String?;

Map<String, dynamic> _$PPrToJson(PPr instance) => <String, dynamic>{
  'textAlign': instance.textAlign,
  'rtl': instance.rtl,
  'paddingLeft': instance.paddingLeft,
  'paddingRight': instance.paddingRight,
  'pStyle': instance.pStyle,
  'numId': instance.numId,
  'paragraphNumber': instance.paragraphNumber,
  'ilvl': instance.ilvl,
  'numberingH': instance.numberingH,
};
