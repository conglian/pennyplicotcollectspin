import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';
import 'PCPigProgress.dart';
import 'PCQuizController.dart';
import 'PCWheelOpportunityStore.dart';
import 'PCWithdrawalController.dart';

/// 首页Debug表单读取的本地快照；排队名次与提现状态机共用真实数据源。
class PCHomeDebugSnapshot {
  const PCHomeDebugSnapshot({
    required this.cash,
    required this.diamonds,
    required this.gold,
    required this.queueRank,
    required this.queueTotal,
    required this.pigLevel,
    required this.wheelChances,
  });

  final double cash, diamonds, gold;
  final int queueRank, queueTotal, pigLevel, wheelChances;
}

/// 首页Debug改数工具：按绝对值覆盖本地缓存，空字段保留，正常阶段规则继续生效。
/// 界面通过onSync刷新Provider；由现有弹窗协调器等表单退出后再展示升级/排队提示。
class PCHomeDebugController {
  PCHomeDebugController({
    SharedPreferences? preferences,
    PCWithdrawalController? withdrawal,
    DateTime Function()? now,
    this.onSync,
  }) : _prefs = preferences,
       _withdrawal = withdrawal ?? PCWithdrawalController.instance,
       _now = now ?? DateTime.now;

  static const maxAmount = 999999999.99;
  static const maxQueueRank = 1000000000;
  static const maxWheelChances = 1000000000;
  static bool _applying = false;
  static final List<Completer<void>> _waiters = [];
  // 奖励恢复日志含旧绝对目标；已有结算未完成时不能覆盖后再让日志复活旧数值。
  static const _rewardJournalKeys = [
    PCQuizController.journalKey,
    'pc_wheel_transaction_v1',
    'pc_home_bubble_journal_v1',
    PCWithdrawalController.giftJournalKey,
  ];

  SharedPreferences? _prefs;
  final PCWithdrawalController _withdrawal;
  final DateTime Function() _now;
  final Future<void> Function()? onSync;

  static void _debugOnly() {
    if (!kDebugMode) throw UnsupportedError('仅Debug版本允许读取或修改调试数据');
  }

  Future<SharedPreferences> _preferences() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Map<String, dynamic> _decode(String? raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<PCHomeDebugSnapshot> read() async {
    _debugOnly();
    final prefs = await _preferences();
    await prefs.reload();
    await PCNumberHelpers().pc_initNumberModel(preferences: prefs);
    // 以机会账本为准修复兼容镜像，不能把旧pc_wheel_number当成真实次数。
    await PCWheelOpportunityStore.transaction(prefs, (_) async {});
    await _withdrawal.refresh();
    final quiz = _decode(prefs.getString(PCQuizController.storageKey));
    final progress = await PCPigProgress.sync(
      prefs,
      diamonds: (quiz['diamonds'] as num?)?.toDouble(),
      gold: (quiz['gold'] as num?)?.toDouble(),
      now: _now(),
    );
    return _snapshot(progress);
  }

  PCHomeDebugSnapshot _snapshot(PCPigProgress progress) => PCHomeDebugSnapshot(
    cash: progress.balance,
    diamonds: progress.diamonds,
    gold: progress.gold,
    queueRank: _withdrawal.queueRank,
    queueTotal: _withdrawal.queueTotal,
    pigLevel: progress.level,
    wheelChances: _prefs?.getInt('pc_wheel_number') ?? 0,
  );

  static double? _amount(double? value, String label) {
    if (value == null) return null;
    if (!value.isFinite || value < 0 || value > maxAmount) {
      throw FormatException('$label须为0到999999999.99之间的有限数值');
    }
    return (value * 100).round() / 100;
  }

  /// 任一字段可单独提交；先校验所有输入，再等待既有答题/转盘事务完成后覆盖。
  Future<PCHomeDebugSnapshot> apply({
    double? cash,
    double? diamonds,
    double? gold,
    int? queueRank,
    int? wheelChances,
  }) async {
    _debugOnly();
    if (cash == null &&
        diamonds == null &&
        gold == null &&
        queueRank == null &&
        wheelChances == null) {
      throw const FormatException('请至少填写一项调试数据');
    }
    cash = _amount(cash, '美元余额');
    diamonds = _amount(diamonds, '钻石数量');
    gold = _amount(gold, '金砖数量');
    if (queueRank != null && (queueRank < 1 || queueRank > maxQueueRank)) {
      throw const FormatException('排队名次须为1到1000000000之间的整数');
    }
    if (wheelChances != null &&
        (wheelChances < 0 || wheelChances > maxWheelChances)) {
      throw const FormatException('转盘次数须为0到1000000000之间的整数');
    }
    while (_applying) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _applying = true;
    try {
      // 活跃实例可能仍在完成上一笔答题写入，先等待，改数后再刷新其内存镜像。
      await PCQuizController.debugReloadActiveProgress();
      final prefs = await _preferences();
      await PCNumberHelpers().pc_initNumberModel(preferences: prefs);
      await PCWheelOpportunityStore.transaction(prefs, (ledger) async {
        if (_rewardJournalKeys.any(
          (key) => (prefs.getString(key) ?? '').isNotEmpty,
        )) {
          throw StateError('奖励正在保存，请等待完成后再修改调试数据');
        }
        final quiz = _decode(prefs.getString(PCQuizController.storageKey));
        await PCPigProgress.sync(
          prefs,
          diamonds: (quiz['diamonds'] as num?)?.toDouble(),
          gold: (quiz['gold'] as num?)?.toDouble(),
          now: _now(),
        );
        final previousLevel = prefs.getInt('pc_pig_level') ?? 0;
        if (cash != null) {
          await _stored(prefs.setDouble('pc_dollar_number', cash));
        }
        if (diamonds != null) {
          await _stored(prefs.setDouble('pc_quiz_diamonds', diamonds));
          await _stored(prefs.setInt('pc_domand_number', diamonds.floor()));
          if (previousLevel == 1) {
            await _stored(prefs.setDouble('pc_pig_level_index', diamonds));
          }
        }
        if (gold != null) {
          await _stored(prefs.setDouble('pc_quiz_gold', gold));
          await _stored(prefs.setInt('pc_zhuan_number', gold.floor()));
          if (previousLevel == 2) {
            await _stored(prefs.setDouble('pc_pig_level_index', gold));
          }
        }
        final progress = await PCPigProgress.sync(prefs, now: _now());
        if (quiz.isNotEmpty) {
          quiz['diamonds'] = progress.diamonds;
          quiz['gold'] = progress.gold;
          await _stored(
            prefs.setString(PCQuizController.storageKey, jsonEncode(quiz)),
          );
        }
        if (wheelChances != null) {
          // 未进入转盘也先结清今天的正常赠送，再覆盖目标值，避免首次进入又额外+3。
          // grantDaily同日幂等，不重置已领取日期或其他机会防重游标。
          await ledger.grantDaily(_now());
          await ledger.debugSetBalance(wheelChances);
        }
      });
      await _withdrawal.debugRefreshProgress(queueRank: queueRank);
      await PCQuizController.debugReloadActiveProgress();
      await onSync?.call();
      final progress = await PCPigProgress.sync(prefs, now: _now());
      return _snapshot(progress);
    } finally {
      _applying = false;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }

  static Future<void> _stored(Future<bool> operation) async {
    if (!await operation) throw StateError('调试数据保存失败，请重试');
  }
}
