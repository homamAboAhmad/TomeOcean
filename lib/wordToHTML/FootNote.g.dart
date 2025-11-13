// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'FootNote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FootNote _$FootNoteFromJson(Map<String, dynamic> json) => FootNote.empty()
  ..p = Paragraph.fromJson(json['p'] as Map<String, dynamic>)
  ..id = json['id'] as String
  ..displayNumber = json['displayNumber'] as String?;

Map<String, dynamic> _$FootNoteToJson(FootNote instance) => <String, dynamic>{
  'p': instance.p.toJson(),
  'id': instance.id,
  'displayNumber': instance.displayNumber,
};
