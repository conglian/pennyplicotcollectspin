import 'package:json_annotation/json_annotation.dart';

part 'PCNumbserModel.g.dart';

/// gp177_pig_number：提现档位、广告开关和三阶段奖励的配置模型。
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class PCAPCConfig {
  const PCAPCConfig({
    this.eqRange = const [],
    this.newAdConsole = 0,
    this.quizConsole = 5,
    this.queueNumber = const [],
    this.tixianTask = const [],
    this.intadPoint = const [],
    this.wheelRange = const [],
    this.firstAdPrize = 0,
    this.growPoint = const [],
    this.moneyPrize = const [],
    this.diamondPrize = const [],
    this.goldPrize = const [],
  });
  final List<int> eqRange;
  final int newAdConsole;
  final int quizConsole;
  final List<PCQueueNumber> queueNumber;
  final List<PCTixianTask> tixianTask;
  @JsonKey(name: 'intad_point')
  final List<PCIntAdPoint> intadPoint;
  final List<int> wheelRange;
  final double firstAdPrize;
  final List<int> growPoint;
  final List<PCMoneyPrize> moneyPrize;
  final List<PCMoneyPrize> diamondPrize;
  final List<PCMoneyPrize> goldPrize;

  factory PCAPCConfig.fromJson(Map<String, dynamic> json) =>
      _$PCAPCConfigFromJson(json);
  factory PCAPCConfig.pc_fromJson(Map<String, dynamic> json) =>
      PCAPCConfig.fromJson(json);
  Map<String, dynamic> toJson() => _$PCAPCConfigToJson(this);
}

/// 提现排队人数与每次递减区间，不用于首页的每日收益排行榜。
@JsonSerializable(fieldRename: FieldRename.snake)
class PCQueueNumber {
  const PCQueueNumber({
    this.intAll = 0,
    this.intAllDelete = const [],
    this.intCurrent = 0,
    this.intCurrentDelete = const [],
  });
  final int intAll;
  final List<int> intAllDelete;
  final int intCurrent;
  final List<int> intCurrentDelete;
  factory PCQueueNumber.fromJson(Map<String, dynamic> json) =>
      _$PCQueueNumberFromJson(json);
  Map<String, dynamic> toJson() => _$PCQueueNumberToJson(this);
}

/// 后续提现任务配置：quiz / spin / video 对应目标次数。
@JsonSerializable(fieldRename: FieldRename.snake)
class PCTixianTask {
  const PCTixianTask({this.title = '', this.data = 0});
  final String title;
  final int data;
  factory PCTixianTask.fromJson(Map<String, dynamic> json) =>
      _$PCTixianTaskFromJson(json);
  Map<String, dynamic> toJson() => _$PCTixianTaskToJson(this);
}

/// 余额左闭右开区间内，point 表示 0–100 的插屏展示概率。
@JsonSerializable(fieldRename: FieldRename.snake)
class PCIntAdPoint {
  const PCIntAdPoint({
    this.firstNumber = 0,
    this.point = 0,
    this.endNumber = 0,
  });
  final int firstNumber;
  final int point;
  final int endNumber;
  factory PCIntAdPoint.fromJson(Map<String, dynamic> json) =>
      _$PCIntAdPointFromJson(json);
  Map<String, dynamic> toJson() => _$PCIntAdPointToJson(this);
}

/// 粉猪/钻石猪/金猪按累计数量匹配的奖励区间。
@JsonSerializable(fieldRename: FieldRename.snake)
class PCMoneyPrize {
  const PCMoneyPrize({
    this.firstNumber = 0,
    this.type = 0,
    this.prize = const [],
    this.endNumber = 0,
  });
  final int firstNumber;
  final int type;
  final List<double> prize;
  final int endNumber;
  factory PCMoneyPrize.fromJson(Map<String, dynamic> json) =>
      _$PCMoneyPrizeFromJson(json);
  Map<String, dynamic> toJson() => _$PCMoneyPrizeToJson(this);
}
