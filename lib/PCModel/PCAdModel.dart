import 'package:json_annotation/json_annotation.dart';

part 'PCAdModel.g.dart';

/// 广告配置：插屏和激励广告分别由 nkmdl_int、nkmdl_rv 提供。
@JsonSerializable(explicitToJson: true)
class PCAdModel {
  List<PCAdModellist> nkmdl_int;
  List<PCAdModellist> nkmdl_rv;

  PCAdModel({this.nkmdl_int = const [], this.nkmdl_rv = const []});

  // 工厂构造函数，用于反序列化
  factory PCAdModel.fromJson(Map<String, dynamic> json) =>
      _$PCAdModelFromJson(json);

  // 序列化方法
  Map<String, dynamic> toJson() => _$PCAdModelToJson(this);
}

/// 单个广告位配置，保留 TopOn、CloudX 及其数值配置的原始字段。
@JsonSerializable()
class PCAdModellist {
  /// 广告位 ID。
  String byfxjhld;

  /// 广告平台：topon / cloudx。
  String dmhytwql;

  /// 广告类型：interstitial / reward。
  String ugebepat;

  int gqqvwedz;

  /// 同类型可用缓存的播放优先级，数值越大越优先。
  int wdzqbsbt;

  /// 本地运行时收益数据，不属于服务端广告配置。
  @JsonKey(includeFromJson: false, includeToJson: false)
  double? ecpm = 0;

  PCAdModellist({
    this.byfxjhld = '',
    this.dmhytwql = '',
    this.ugebepat = '',
    this.gqqvwedz = 0,
    this.wdzqbsbt = 0,
  });

  // 工厂构造函数，用于反序列化
  factory PCAdModellist.fromJson(Map<String, dynamic> json) =>
      _$PCAdModellistFromJson(json);

  // 序列化方法
  Map<String, dynamic> toJson() => _$PCAdModellistToJson(this);
}
