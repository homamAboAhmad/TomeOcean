// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ImageParser.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImageData _$ImageDataFromJson(Map<String, dynamic> json) => ImageData()
  ..rId = json['rId'] as String
  ..width = (json['width'] as num).toDouble()
  ..height = (json['height'] as num).toDouble()
  ..posX = (json['posX'] as num).toDouble()
  ..alignH = json['alignH'] as String
  ..alingV = json['alingV'] as String
  ..relativeHeight = (json['relativeHeight'] as num).toDouble()
  ..behindDoc = json['behindDoc'] as bool? ?? false
  ..posY = (json['posY'] as num).toDouble()
  ..relativeFromH = json['relativeFromH'] as String
  ..relativeFromV = json['relativeFromV'] as String
  ..wrapMode = json['wrapMode'] as String?
  ..imageMemory = uint8ListFromJson(json['imageMemory'] as String?)
  ..textBoxText = json['textBoxText'] as String?
  ..textColor = json['textColor'] as String?
  ..textSize = (json['textSize'] as num?)?.toDouble()
  ..fontFamily = json['fontFamily'] as String?
  ..containsPageField = json['containsPageField'] as bool? ?? false;

Map<String, dynamic> _$ImageDataToJson(ImageData instance) => <String, dynamic>{
  'rId': instance.rId,
  'width': instance.width,
  'height': instance.height,
  'posX': instance.posX,
  'alignH': instance.alignH,
  'alingV': instance.alingV,
  'relativeHeight': instance.relativeHeight,
  'behindDoc': instance.behindDoc,
  'posY': instance.posY,
  'relativeFromH': instance.relativeFromH,
  'relativeFromV': instance.relativeFromV,
  'wrapMode': instance.wrapMode,
  'imageMemory': uint8ListToJson(instance.imageMemory),
  'textBoxText': instance.textBoxText,
  'textColor': instance.textColor,
  'textSize': instance.textSize,
  'fontFamily': instance.fontFamily,
  'containsPageField': instance.containsPageField,
};
