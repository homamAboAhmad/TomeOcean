// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PPr.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PPr _$PPrFromJson(Map<String, dynamic> json) => PPr.empty()
  ..textAlign = json['textAlign'] as String?
  ..rtl = json['rtl'] as bool?
  ..bidi = json['bidi'] as bool?
  ..paddingLeft = (json['paddingLeft'] as num?)?.toDouble()
  ..forceStrutHeight = json['forceStrutHeight'] as bool
  ..paddingRight = (json['paddingRight'] as num?)?.toDouble()
  ..firstLineIndent = (json['firstLineIndent'] as num?)?.toDouble()
  ..pStyle = json['pStyle'] as String?
  ..numId = (json['numId'] as num?)?.toInt()
  ..paragraphNumber = (json['paragraphNumber'] as num?)?.toInt()
  ..ilvl = (json['ilvl'] as num?)?.toInt()
  ..numberingH = json['numberingH'] as String?
  ..tabStops = (json['tabStops'] as List<dynamic>)
      .map((e) => TabStop.fromJson(e as Map<String, dynamic>))
      .toList()
  ..tocLevel = (json['tocLevel'] as num?)?.toInt()
  ..spacingBefore = (json['spacingBefore'] as num?)?.toDouble()
  ..spacingAfter = (json['spacingAfter'] as num?)?.toDouble()
  ..lineHeight = (json['lineHeight'] as num?)?.toDouble();

Map<String, dynamic> _$PPrToJson(PPr instance) => <String, dynamic>{
  'textAlign': instance.textAlign,
  'rtl': instance.rtl,
  'bidi': instance.bidi,
  'paddingLeft': instance.paddingLeft,
  'forceStrutHeight': instance.forceStrutHeight,
  'paddingRight': instance.paddingRight,
  'firstLineIndent': instance.firstLineIndent,
  'pStyle': instance.pStyle,
  'numId': instance.numId,
  'paragraphNumber': instance.paragraphNumber,
  'ilvl': instance.ilvl,
  'numberingH': instance.numberingH,
  'tabStops': instance.tabStops.map((e) => e.toJson()).toList(),
  'tocLevel': instance.tocLevel,
  'spacingBefore': instance.spacingBefore,
  'spacingAfter': instance.spacingAfter,
  'lineHeight': instance.lineHeight,
};
