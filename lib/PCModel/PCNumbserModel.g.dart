// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'PCNumbserModel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PCAPCConfig _$PCAPCConfigFromJson(Map<String, dynamic> json) => PCAPCConfig(
      eqRange: (json['eq_range'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      newAdConsole: (json['new_ad_console'] as num?)?.toInt() ?? 0,
      quizConsole: (json['quiz_console'] as num?)?.toInt() ?? 5,
      queueNumber: (json['queue_number'] as List<dynamic>?)
              ?.map((e) => PCQueueNumber.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tixianTask: (json['tixian_task'] as List<dynamic>?)
              ?.map((e) => PCTixianTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      intadPoint: (json['intad_point'] as List<dynamic>?)
              ?.map((e) => PCIntAdPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      wheelRange: (json['wheel_range'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      firstAdPrize: (json['first_ad_prize'] as num?)?.toDouble() ?? 0,
      growPoint: (json['grow_point'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      moneyPrize: (json['money_prize'] as List<dynamic>?)
              ?.map((e) => PCMoneyPrize.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      diamondPrize: (json['diamond_prize'] as List<dynamic>?)
              ?.map((e) => PCMoneyPrize.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      goldPrize: (json['gold_prize'] as List<dynamic>?)
              ?.map((e) => PCMoneyPrize.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PCAPCConfigToJson(PCAPCConfig instance) =>
    <String, dynamic>{
      'eq_range': instance.eqRange,
      'new_ad_console': instance.newAdConsole,
      'quiz_console': instance.quizConsole,
      'queue_number': instance.queueNumber.map((e) => e.toJson()).toList(),
      'tixian_task': instance.tixianTask.map((e) => e.toJson()).toList(),
      'intad_point': instance.intadPoint.map((e) => e.toJson()).toList(),
      'wheel_range': instance.wheelRange,
      'first_ad_prize': instance.firstAdPrize,
      'grow_point': instance.growPoint,
      'money_prize': instance.moneyPrize.map((e) => e.toJson()).toList(),
      'diamond_prize': instance.diamondPrize.map((e) => e.toJson()).toList(),
      'gold_prize': instance.goldPrize.map((e) => e.toJson()).toList(),
    };

PCQueueNumber _$PCQueueNumberFromJson(Map<String, dynamic> json) =>
    PCQueueNumber(
      intAll: (json['int_all'] as num?)?.toInt() ?? 0,
      intAllDelete: (json['int_all_delete'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      intCurrent: (json['int_current'] as num?)?.toInt() ?? 0,
      intCurrentDelete: (json['int_current_delete'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );

Map<String, dynamic> _$PCQueueNumberToJson(PCQueueNumber instance) =>
    <String, dynamic>{
      'int_all': instance.intAll,
      'int_all_delete': instance.intAllDelete,
      'int_current': instance.intCurrent,
      'int_current_delete': instance.intCurrentDelete,
    };

PCTixianTask _$PCTixianTaskFromJson(Map<String, dynamic> json) => PCTixianTask(
      title: json['title'] as String? ?? '',
      data: (json['data'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PCTixianTaskToJson(PCTixianTask instance) =>
    <String, dynamic>{
      'title': instance.title,
      'data': instance.data,
    };

PCIntAdPoint _$PCIntAdPointFromJson(Map<String, dynamic> json) => PCIntAdPoint(
      firstNumber: (json['first_number'] as num?)?.toInt() ?? 0,
      point: (json['point'] as num?)?.toInt() ?? 0,
      endNumber: (json['end_number'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PCIntAdPointToJson(PCIntAdPoint instance) =>
    <String, dynamic>{
      'first_number': instance.firstNumber,
      'point': instance.point,
      'end_number': instance.endNumber,
    };

PCMoneyPrize _$PCMoneyPrizeFromJson(Map<String, dynamic> json) => PCMoneyPrize(
      firstNumber: (json['first_number'] as num?)?.toInt() ?? 0,
      type: (json['type'] as num?)?.toInt() ?? 0,
      prize: (json['prize'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      endNumber: (json['end_number'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PCMoneyPrizeToJson(PCMoneyPrize instance) =>
    <String, dynamic>{
      'first_number': instance.firstNumber,
      'type': instance.type,
      'prize': instance.prize,
      'end_number': instance.endNumber,
    };
