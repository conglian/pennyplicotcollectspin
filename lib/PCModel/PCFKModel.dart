import 'package:json_annotation/json_annotation.dart';

part 'PCFKModel.g.dart';

@JsonSerializable(explicitToJson: true)
class PCFkModel {
  final PCUIModel ui;
  final List<String> device;

  const PCFkModel({
    this.ui = const PCUIModel(),
    this.device = const <String>[],
  });

  factory PCFkModel.fromJson(Map<String, dynamic> json) =>
      _$PCFkModelFromJson(json);

  Map<String, dynamic> toJson() => _$PCFkModelToJson(this);
}

@JsonSerializable()
class PCUIModel {
  final int number;
  final int device;

  const PCUIModel({
    this.number = 0,
    this.device = 0,
  });

  factory PCUIModel.fromJson(Map<String, dynamic> json) =>
      _$PCUIModelFromJson(json);

  Map<String, dynamic> toJson() => _$PCUIModelToJson(this);
}
