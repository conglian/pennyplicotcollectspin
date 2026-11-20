import 'dart:math';
import '../PCModel/PCNumbserModel.dart';
import 'PCNumberManager.dart';

enum PCQuizRewardType { cash, diamond, gold }

/// 答题配置适配器，数值与采样统一由 PCNumberHelpers 读取 gp177_pig_number。
class PCQuizConfig {
  const PCQuizConfig({this.model = const PCAPCConfig()});
  final PCAPCConfig model;
  double get withdrawalTarget => (model.eqRange.firstOrNull ?? 100).toDouble();
  static const diamondTarget = PCNumberHelpers.diamondTarget;
  static const goldTarget = PCNumberHelpers.goldTarget;
  factory PCQuizConfig.fromRaw(String? raw) =>
      PCQuizConfig(model: PCNumberHelpers().pc_parseConfig(raw));
  factory PCQuizConfig.fromModel(PCAPCConfig model) =>
      PCQuizConfig(model: model);
  double target(PCQuizRewardType type) => switch (type) {
    PCQuizRewardType.cash => withdrawalTarget,
    PCQuizRewardType.diamond => diamondTarget,
    PCQuizRewardType.gold => goldTarget,
  };
  double prize(PCQuizRewardType type, double collected, Random random) =>
      PCNumberHelpers().pc_prizeForLevel(
        type.index,
        collected,
        random: random,
        config: model,
      );
}

class PCQuizReward {
  const PCQuizReward({
    required this.id,
    required this.type,
    required this.amount,
    required this.questionIndex,
  });
  final String id;
  final PCQuizRewardType type;
  final double amount;
  final int questionIndex;

  /// 双倍结算沿用原奖励 ID，现金和钻石始终按原金额结算。
  PCQuizReward forSettlement({required bool doubleGold}) =>
      doubleGold && type == PCQuizRewardType.gold
      ? PCQuizReward(
          id: id,
          type: type,
          amount: ((amount * 2) * 100).round() / 100,
          questionIndex: questionIndex,
        )
      : this;

  String get amountText => format(amount);
  String get asset => switch (type) {
    PCQuizRewardType.cash => 'pc_quiz_cash_reward',
    PCQuizRewardType.diamond => 'pc_domand_icons',
    PCQuizRewardType.gold => 'pc_zhuan_icons',
  };
  String get pigAsset => switch (type) {
    PCQuizRewardType.cash => 'pc_big_icon_0',
    PCQuizRewardType.diamond => 'pc_quiz_pig_diamond',
    PCQuizRewardType.gold => 'pc_quiz_pig_gold',
  };
  String get pigAnimationAsset => switch (type) {
    PCQuizRewardType.cash => 'assets/File/home_pig_fen.zip',
    PCQuizRewardType.diamond => 'assets/File/home_domand.json.zip',
    PCQuizRewardType.gold => 'assets/File/home_huangjin.zip',
  };
  String get title => switch (type) {
    PCQuizRewardType.cash => 'Earned \$$amountText',
    PCQuizRewardType.diamond => 'Earned ×$amountText Diamond',
    PCQuizRewardType.gold => 'Earned ×$amountText Gold',
  };
  static String format(double value) => value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'questionIndex': questionIndex,
  };
  factory PCQuizReward.fromJson(Map<String, dynamic> data) => PCQuizReward(
    id: data['id'] as String,
    type: PCQuizRewardType.values.byName(data['type'] as String),
    amount: (data['amount'] as num).toDouble(),
    questionIndex: data['questionIndex'] as int,
  );
}
