import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PCModel/PCNumbserModel.dart';
import 'pc_LocalProvider.dart';

/// 数值配置唯一入口：打包 JSON 为默认值，同名缓存按字段覆盖。
class PCNumberHelpers {
  static final PCNumberHelpers _instance = PCNumberHelpers._();
  factory PCNumberHelpers() => _instance;
  PCNumberHelpers._();
  static const configKey = 'gp177_pig_number';
  static const assetPath = 'assets/File/gp177_pig_number.json';
  static const diamondTarget = 20.0;
  static const goldTarget = 10.0;
  final Random _random = Random();
  Future<String>? _assetSource;
  PCAPCConfig? _baseModel;
  PCAPCConfig? intModel;
  PCAPCConfig get model => intModel ?? const PCAPCConfig();
  List<int> get pc_eqRange {
    final values = model.eqRange.where((v) => v > 0).toSet().toList();
    return values.isEmpty ? const [100, 120, 150, 200] : values;
  }

  double get pc_firstTarget => pc_eqRange.first.toDouble();
  bool get pc_newUserNeedsAd => model.newAdConsole == 1;
  int get pc_quizConsole => model.quizConsole > 0 ? model.quizConsole : 5;
  List<int> get pc_wheelRange => model.wheelRange.length >= 2
      ? model.wheelRange.take(2).toList()
      : const [5, 10];
  PCQueueNumber get pc_queueNumber =>
      model.queueNumber.firstOrNull ??
      const PCQueueNumber(
        intAll: 388,
        intCurrent: 99,
        intAllDelete: [1, 3],
        intCurrentDelete: [5, 8],
      );
  List<PCTixianTask> get pc_tixianTasks {
    bool valid(PCTixianTask task) =>
        const {'quiz', 'spin', 'video'}.contains(task.title) && task.data > 0;
    final tasks = model.tixianTask.where(valid).toList();
    if (tasks.isNotEmpty) return tasks;
    final bundled = (_baseModel?.tixianTask ?? const <PCTixianTask>[])
        .where(valid)
        .toList();
    return bundled.isNotEmpty
        ? bundled
        : const [
            PCTixianTask(title: 'quiz', data: 10),
            PCTixianTask(title: 'spin', data: 10),
            PCTixianTask(title: 'video', data: 10),
          ];
  }

  Future<void> pc_initNumberModel({SharedPreferences? preferences}) async {
    await _loadBaseModel();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    intModel = pc_parseConfig(prefs.getString(configKey));
  }

  Future<void> _loadBaseModel() async {
    if (_baseModel == null) {
      final source = await (_assetSource ??= rootBundle.loadString(assetPath));
      _baseModel = PCAPCConfig.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
    }
  }

  /// Firebase同名参数有效时覆盖并缓存；为空、获取失败或JSON异常时恢复打包默认值。
  /// 每次从打包模型合并，远程新版本省略的字段不能残留上一版远程数值。
  Future<void> pc_applyRemoteConfig(
    String? raw, {
    SharedPreferences? preferences,
  }) async {
    await _loadBaseModel();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(raw ?? '');
      if (value is Map<String, dynamic> && value.isNotEmpty) decoded = value;
    } catch (_) {
      // 远程参数不可用时清理旧覆盖，保证默认来自本地JSON。
    }
    if (decoded == null) {
      await prefs.remove(configKey);
      intModel = _baseModel;
      return;
    }
    final source = jsonEncode(decoded);
    final merged = pc_parseConfig(source);
    await prefs.setString(configKey, source);
    intModel = merged;
  }

  /// 远程值无效时按字段回退，不能使本地奖励或提现档位变成空列表。
  PCAPCConfig pc_parseConfig(String? raw) {
    final base = _baseModel ?? model;
    try {
      final decoded = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
      final data = base.toJson();
      for (final key in data.keys.toList()) {
        if (!decoded.containsKey(key)) continue;
        try {
          final candidate = PCAPCConfig.fromJson({...data, key: decoded[key]});
          final valid = switch (key) {
            'eq_range' =>
              candidate.eqRange.isNotEmpty &&
                  candidate.eqRange.every((v) => v > 0),
            'new_ad_console' =>
              candidate.newAdConsole == 0 || candidate.newAdConsole == 1,
            'quiz_console' => candidate.quizConsole > 0,
            'wheel_range' =>
              candidate.wheelRange.length >= 2 &&
                  candidate.wheelRange.every((v) => v >= 0),
            'first_ad_prize' =>
              candidate.firstAdPrize.isFinite && candidate.firstAdPrize > 0,
            'money_prize' => _validRanges(candidate.moneyPrize),
            'diamond_prize' => _validRanges(candidate.diamondPrize),
            'gold_prize' => _validRanges(candidate.goldPrize),
            'intad_point' => _validProbabilities(candidate.intadPoint),
            'queue_number' =>
              candidate.queueNumber.isNotEmpty &&
                  candidate.queueNumber.every(
                    (row) =>
                        row.intAll > 0 &&
                        row.intCurrent > 0 &&
                        row.intAllDelete.length >= 2 &&
                        row.intCurrentDelete.length >= 2 &&
                        row.intAllDelete.every((value) => value >= 0) &&
                        row.intCurrentDelete.every((value) => value >= 0),
                  ),
            'tixian_task' =>
              candidate.tixianTask.isNotEmpty &&
                  candidate.tixianTask.every(
                    (task) =>
                        const {'quiz', 'spin', 'video'}.contains(task.title) &&
                        task.data > 0,
                  ),
            _ => decoded[key] != null,
          };
          if (valid) data[key] = decoded[key];
        } catch (_) {
          /* 此字段保留本地配置。 */
        }
      }
      return PCAPCConfig.fromJson(data);
    } catch (_) {
      return base;
    }
  }

  static bool _validRanges(List<PCMoneyPrize> rows) =>
      rows.isNotEmpty &&
      rows.every(
        (row) =>
            row.endNumber > row.firstNumber &&
            row.prize.length >= 2 &&
            row.prize.every((v) => v.isFinite && v > 0),
      );

  static bool _validProbabilities(List<PCIntAdPoint> rows) {
    if (rows.isEmpty) return false;
    final sorted = rows.toList()
      ..sort((a, b) => a.firstNumber.compareTo(b.firstNumber));
    for (var index = 0; index < sorted.length; index++) {
      final row = sorted[index];
      if (row.firstNumber < 0 ||
          row.endNumber <= row.firstNumber ||
          row.point < 0 ||
          row.point > 100 ||
          (index > 0 && sorted[index - 1].endNumber > row.firstNumber)) {
        return false;
      }
    }
    return true;
  }

  // 保留旧调用兼容；本次 eq_range 按 JSON 原值使用，不再隐式乘地区倍率。
  Future<void> pc_updateBrazilianPortuguese(BuildContext context) =>
      pc_initNumberModel();
  bool pc_isBrazilianPortuguese(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'pt' || locale.countryCode == 'BR';
  }

  bool pc_checkProbability({double? balance, Random? random}) {
    final value = balance ?? PCLocalProvider.instance.pc_dollar_number;
    final row = model.intadPoint
        .where((row) => value >= row.firstNumber && value < row.endNumber)
        .firstOrNull;
    final probability = (row?.point ?? 0).clamp(0, 100);
    return probability > 0 &&
        (random ?? _random).nextDouble() * 100 < probability;
  }

  List<PCMoneyPrize> _ranges(PCAPCConfig config, int level) => switch (level) {
    0 => config.moneyPrize,
    1 => config.diamondPrize,
    _ => config.goldPrize,
  };
  PCMoneyPrize? _find(List<PCMoneyPrize> rows, double value) => rows
      .where((row) => value >= row.firstNumber && value < row.endNumber)
      .firstOrNull;

  /// 奖励左闭右开采样并保留两位小数；仅现金受提现门槛限制。
  /// 钻石20和金砖10之后继续按对应末档发奖，阶段推进由PCPigProgress决定。
  double pc_prizeForLevel(
    int level,
    double collected, {
    Random? random,
    PCAPCConfig? config,
  }) {
    final currentModel = config ?? model;
    final target = level == 0
        ? (currentModel.eqRange.firstOrNull ?? 100).toDouble()
        : level == 1
        ? diamondTarget
        : goldTarget;
    final current = (collected * 100).round();
    final remaining = max(0, (target * 100).round() - current);
    if (remaining == 0 && level == 0) return 0;
    final rows = _ranges(currentModel, level).toList()
      ..sort((a, b) => a.firstNumber.compareTo(b.firstNumber));
    var row = _find(rows, collected);
    // 覆盖配置缺档时用打包配置的对应档，避免错误地套用最后一档。
    row ??= _find(_ranges(_baseModel ?? currentModel, level), collected);
    row ??= rows.lastOrNull;
    if (row == null || row.prize.length < 2) {
      throw StateError('Reward configuration is not loaded');
    }
    final low = min(row.prize.first, row.prize.last),
        high = max(row.prize.first, row.prize.last);
    final picked = max(
      1,
      ((low + (random ?? _random).nextDouble() * (high - low)) * 100).round(),
    );
    final end = row.endNumber * 100;
    if (level != 0) {
      // 普通档边界仍按配置衔接；末档目标不截断，超额数量继续采样末档。
      final cap = end > current && row.endNumber < target
          ? end - current
          : picked;
      return min(picked, cap) / 100;
    }
    return min(
          picked,
          min(remaining, end > current ? end - current : remaining),
        ) /
        100;
  }

  double pc_getPrizeWithDolasNum() =>
      pc_prizeForLevel(0, PCLocalProvider.instance.pc_dollar_number);
  List<double> pc_getPrizeWithDolasNSize(double balance) =>
      _find(model.moneyPrize, balance)?.prize ??
      model.moneyPrize.lastOrNull?.prize ??
      const [0, 0];
  double pc_getPrizeWithDomandGoldNum() {
    final local = PCLocalProvider.instance;
    return pc_prizeForLevel(local.pc_pig_level, local.pc_pig_level_index);
  }

  int pc_dolasbeishu() => 1;
}

int pc_pigFillSegment(int level, double amount) {
  final limit = level == 0
      ? PCNumberHelpers().pc_firstTarget
      : level == 1
      ? 20.0
      : 10.0;
  final position = (amount.clamp(0, limit) / (limit / 4)).ceil() - 1;
  return const [25, 50, 75, 100][position.clamp(0, 3)];
}
