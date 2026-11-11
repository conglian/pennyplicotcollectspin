// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PCAdModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PCAdModel _$PCAdModelFromJson(Map<String, dynamic> json) => PCAdModel(
      nkmdl_int: (json['nkmdl_int'] as List<dynamic>?)
              ?.map((e) => PCAdModellist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nkmdl_rv: (json['nkmdl_rv'] as List<dynamic>?)
              ?.map((e) => PCAdModellist.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PCAdModelToJson(PCAdModel instance) => <String, dynamic>{
      'nkmdl_int': instance.nkmdl_int.map((e) => e.toJson()).toList(),
      'nkmdl_rv': instance.nkmdl_rv.map((e) => e.toJson()).toList(),
    };

PCAdModellist _$PCAdModellistFromJson(Map<String, dynamic> json) =>
    PCAdModellist(
      byfxjhld: json['byfxjhld'] as String? ?? '',
      dmhytwql: json['dmhytwql'] as String? ?? '',
      ugebepat: json['ugebepat'] as String? ?? '',
      gqqvwedz: (json['gqqvwedz'] as num?)?.toInt() ?? 0,
      wdzqbsbt: (json['wdzqbsbt'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PCAdModellistToJson(PCAdModellist instance) =>
    <String, dynamic>{
      'byfxjhld': instance.byfxjhld,
      'dmhytwql': instance.dmhytwql,
      'ugebepat': instance.ugebepat,
      'gqqvwedz': instance.gqqvwedz,
      'wdzqbsbt': instance.wdzqbsbt,
    };
