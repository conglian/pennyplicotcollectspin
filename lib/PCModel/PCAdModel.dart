import 'package:json_annotation/json_annotation.dart';

part 'PCAdModel.g.dart';

@JsonSerializable()
class PCAdModel {
  late int xjgrpkac = 0;
  late int wgcmmsne = 0;
  late bool olstk_switch = false;
  late List<PCAdModellist> olstk_int = [];
  late List<PCAdModellist> olstk_rv = [];
  PCAdModel();

  // 工厂构造函数，用于反序列化
  factory PCAdModel.fromJson(Map<String, dynamic> json) => _$PCAdModelFromJson(json);

  // 序列化方法
  Map<String, dynamic> toJson() => _$PCAdModelToJson(this);
}

@JsonSerializable()
class PCAdModellist {
  // id
  late String ayyibgmi = "";
  // type
  late String ckovkxxo = "";
  // ad_type
  late String ichurcix = "";
  //
  late int tavomvmz = 0;
  //
  late double? ecpm = 0;

  PCAdModellist();

  // 工厂构造函数，用于反序列化
  factory PCAdModellist.fromJson(Map<String, dynamic> json) => _$PCAdModellistFromJson(json);

  // 序列化方法
  Map<String, dynamic> toJson() => _$PCAdModellistToJson(this);
}