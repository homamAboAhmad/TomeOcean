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
  ..posY = (json['posY'] as num).toDouble()
  ..relativeFromH = json['relativeFromH'] as String
  ..relativeFromV = json['relativeFromV'] as String
  ..imageMemory = uint8ListFromJson(json['imageMemory'] as String?);

Map<String, dynamic> _$ImageDataToJson(ImageData instance) => <String, dynamic>{
  'rId': instance.rId,
  'width': instance.width,
  'height': instance.height,
  'posX': instance.posX,
  'alignH': instance.alignH,
  'alingV': instance.alingV,
  'relativeHeight': instance.relativeHeight,
  'posY': instance.posY,
  'relativeFromH': instance.relativeFromH,
  'relativeFromV': instance.relativeFromV,
  'imageMemory': uint8ListToJson(instance.imageMemory),
};
