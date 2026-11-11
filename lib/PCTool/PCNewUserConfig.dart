import 'dart:math';
import '../PCModel/PCNumbserModel.dart';
import 'PCNumberManager.dart';

/// 新用户参数适配器；共用 PCNumberHelpers 的本地 JSON 和同名配置缓存。
class PCNewUserConfig {
  const PCNewUserConfig({
    this.withdrawalTarget = 100,
    this.firstAdPrize = 6,
    this.showFirstAd = true,
    this.growPercent = 3,
    this.model = const PCAPCConfig(),
  });
  static const remoteKey = PCNumberHelpers.configKey;
  final double withdrawalTarget;
  final double firstAdPrize;

  /// 兼容旧调用；当前首次与普通签到均需激励，不再使用 new_ad_console。
  final bool showFirstAd;
  final double growPercent;
  final PCAPCConfig model;
  List<double> get checkInRewards => [
    firstAdPrize,
    .15,
    .20,
    .30,
    .50,
    .80,
    10,
  ];
  factory PCNewUserConfig.fromModel(PCAPCConfig model) => PCNewUserConfig(
    withdrawalTarget: (model.eqRange.firstOrNull ?? 100).toDouble(),
    firstAdPrize: model.firstAdPrize,
    showFirstAd: true,
    growPercent: (model.growPoint.firstOrNull ?? 3).toDouble(),
    model: model,
  );
  factory PCNewUserConfig.fromRaw(String? raw, {int fallbackAdConsole = 1}) =>
      PCNewUserConfig.fromModel(PCNumberHelpers().pc_parseConfig(raw));
  double quizPrize(double balance, Random random) => PCNumberHelpers()
      .pc_prizeForLevel(0, balance, random: random, config: model);
}
