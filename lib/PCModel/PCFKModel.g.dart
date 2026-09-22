// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PCFKModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PCFkModel _$PCFkModelFromJson(Map<String, dynamic> json) => PCFkModel(
      ui: json['ui'] == null
          ? const PCUIModel()
          : PCUIModel.fromJson(json['ui'] as Map<String, dynamic>),
      device: (json['device'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$PCFkModelToJson(PCFkModel instance) => <String, dynamic>{
      'ui': instance.ui.toJson(),
      'device': instance.device,
    };

PCUIModel _$PCUIModelFromJson(Map<String, dynamic> json) => PCUIModel(
      number: (json['number'] as num?)?.toInt() ?? 0,
      device: (json['device'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PCUIModelToJson(PCUIModel instance) => <String, dynamic>{
      'number': instance.number,
      'device': instance.device,
    };
