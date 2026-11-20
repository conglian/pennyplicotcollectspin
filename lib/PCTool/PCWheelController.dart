import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';
import 'PCPigProgress.dart';
import 'PCQuizConfig.dart';
import 'PCWheelOpportunityStore.dart';

enum PCWheelStartResult { started, pending, noSpins, complete, busy }

/// 一次已扣机会、尚未领取的转盘结果；落点和奖励金额落盘后不再随机。
class PCWheelTurn {
  const PCWheelTurn({
    required this.segment,
    required this.spinsAfter,
    required this.reward,
  });
  final int segment, spinsAfter;
  final PCQuizReward reward;
  Map<String, dynamic> toJson() => {
    'segment': segment,
    'spinsAfter': spinsAfter,
    'reward': reward.toJson(),
  };
  factory PCWheelTurn.fromJson(Map<String, dynamic> data) => PCWheelTurn(
    segment: data['segment'] as int,
    spinsAfter: data['spinsAfter'] as int,
    reward: PCQuizReward.fromJson(
      Map<String, dynamic>.from(data['reward'] as Map),
    ),
  );
}

/// 转盘本地结算：粉猪仅金额区，钻石/金猪仅Cash Bag；扣次数、领奖均支持中断恢复。
class PCWheelController extends ChangeNotifier {
  PCWheelController({
    Random? random,
    DateTime Function()? now,
    this.onSync,
    this.onWithdrawalSpin,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;
  static const storageKey = 'pc_wheel_pending_v1';
  static const journalKey = 'pc_wheel_transaction_v1';
  // 从正上方开始，顺时针每45度一个分区；底部Try Again不参与抽奖。
  static const cashSegments = [1, 2, 6];
  static const bagSegments = [0, 3, 5, 7];
  final Random _random;
  final DateTime Function() _now;
  DateTime get now => _now();
  final Future<void> Function()? onSync;

  /// 实际转动ID随扣次日志重放，提现任务按ID去重；普通重开待奖不再计次。
  final Future<void> Function(String eventId)? onWithdrawalSpin;
  SharedPreferences? _prefs;
  Future<void>? _loading;
  PCWheelTurn? _pending;
  bool _busy = false, _disposed = false;
  PCWheelTurn? get pending => _pending;
  int get spins => _prefs?.getInt('pc_wheel_number') ?? 0;
  double get diamonds => _prefs?.getDouble('pc_quiz_diamonds') ?? 0;
  double get gold => _prefs?.getDouble('pc_quiz_gold') ?? 0;
  bool get isBusy => _busy;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
    await PCWheelOpportunityStore.transaction(_prefs!, (ledger) async {
      await _recover(ledger);
      await ledger.grantDaily(_now());
    });
    await onSync?.call();
    _notify();
  }

  Future<void> _recover(PCWheelOpportunityTransaction ledger) async {
    final journal = _read(journalKey);
    if (journal != null) await _applyJournal(journal, ledger);
    final raw = _read(storageKey);
    _pending = raw == null ? null : PCWheelTurn.fromJson(raw);
  }

  /// 切页、回前台和本地午夜刷新；与转动/答题的机会事务串行，不覆盖待奖。
  Future<void> refreshDailyOpportunities() async {
    await load();
    await PCWheelOpportunityStore.transaction(_prefs!, (ledger) async {
      await _recover(ledger);
      await ledger.grantDaily(_now());
    });
    await onSync?.call();
    _notify();
  }

  Map<String, dynamic>? _read(String key) {
    final raw = _prefs!.getString(key);
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<PCWheelStartResult> start() async {
    if (_busy) return PCWheelStartResult.busy;
    _busy = true;
    _notify();
    try {
      await load();
      final result = await PCWheelOpportunityStore.transaction(_prefs!, (
        ledger,
      ) async {
        await _recover(ledger);
        await ledger.grantDaily(_now());
        final raw = _read(storageKey);
        if (raw != null) {
          _pending = PCWheelTurn.fromJson(raw);
          return PCWheelStartResult.pending;
        }
        await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
        final progress = await PCPigProgress.sync(_prefs!);
        if (spins <= 0) return PCWheelStartResult.noSpins;
        final segments = progress.level == 0 ? cashSegments : bagSegments;
        final turn = PCWheelTurn(
          segment: segments[_random.nextInt(segments.length)],
          spinsAfter: spins - 1,
          reward: PCQuizReward(
            id: 'wheel_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 30)}',
            type: PCQuizRewardType.values[progress.level],
            amount: PCNumberHelpers().pc_prizeForLevel(
              progress.level,
              progress.amount,
              random: _random,
            ),
            questionIndex: -1,
          ),
        );
        final journal = {
          'action': 'start',
          'turn': turn.toJson(),
          'opportunityEvent': true,
        };
        await _prefs!.setString(journalKey, jsonEncode(journal));
        await _applyJournal(journal, ledger);
        _pending = turn;
        return PCWheelStartResult.started;
      });
      await onSync?.call();
      return result;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<PCQuizReward?> claim({
    String? expectedRewardId,
    bool doubleGold = false,
  }) async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      await load();
      final result = await PCWheelOpportunityStore.transaction(_prefs!, (
        ledger,
      ) async {
        await _recover(ledger);
        await ledger.grantDaily(_now());
        final raw = _read(storageKey);
        if (raw == null) return null;
        final pending = PCWheelTurn.fromJson(raw).reward;
        if (expectedRewardId != null && pending.id != expectedRewardId) {
          return null;
        }
        final reward = pending.forSettlement(doubleGold: doubleGold);
        final progress = await PCPigProgress.sync(_prefs!);
        double add(double current, double limit) =>
            min(limit, ((current + reward.amount) * 100).round() / 100);
        final journal = <String, dynamic>{
          'action': 'claim',
          'rewardId': reward.id,
          if (reward.type == PCQuizRewardType.cash)
            'balanceAfter': add(
              progress.balance,
              PCNumberHelpers().pc_firstTarget,
            ),
          'diamondsAfter': reward.type == PCQuizRewardType.diamond
              ? ((progress.diamonds + reward.amount) * 100).round() / 100
              : progress.diamonds,
          'goldAfter': reward.type == PCQuizRewardType.gold
              ? ((progress.gold + reward.amount) * 100).round() / 100
              : progress.gold,
        };
        await _prefs!.setString(journalKey, jsonEncode(journal));
        await _applyJournal(journal, ledger);
        _pending = null;
        return reward;
      });
      await onSync?.call();
      return result;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// 关闭奖励框或激励失败后放弃这次结果；消耗的机会不返还，也不结算奖励。
  /// 与扣次、领取共用机会事务；旧弹窗的失败回调不能清除后来产生的奖励。
  Future<bool> discardPending({required String expectedRewardId}) async {
    await load();
    final discarded = await PCWheelOpportunityStore.transaction(_prefs!, (
      ledger,
    ) async {
      await _recover(ledger);
      if (_pending?.reward.id != expectedRewardId) return false;
      final journal = <String, dynamic>{
        'action': 'discard',
        'rewardId': expectedRewardId,
      };
      await _storeDiscard(_prefs!.setString(journalKey, jsonEncode(journal)));
      await _applyJournal(journal, ledger);
      _pending = null;
      return true;
    });
    _notify();
    return discarded;
  }

  Future<void> _applyJournal(
    Map<String, dynamic> journal,
    PCWheelOpportunityTransaction ledger,
  ) async {
    if (journal['action'] == 'start') {
      final turn = PCWheelTurn.fromJson(
        Map<String, dynamic>.from(journal['turn'] as Map),
      );
      await ledger.consumeWheel(
        turn.reward.id,
        legacyTarget: journal['opportunityEvent'] == true
            ? null
            : turn.spinsAfter,
      );
      await _prefs!.setString(storageKey, jsonEncode(turn.toJson()));
      await onWithdrawalSpin?.call(turn.reward.id);
    } else if (journal['action'] == 'discard') {
      final pending = _read(storageKey);
      // 日志可能在删除待奖前被中断；重放仅删除同一笔，不能误伤新结果。
      if (pending != null &&
          PCWheelTurn.fromJson(pending).reward.id == journal['rewardId']) {
        await _storeDiscard(_prefs!.remove(storageKey));
      }
    } else {
      if (journal['balanceAfter'] is num) {
        await _prefs!.setDouble(
          'pc_dollar_number',
          max(
            _prefs!.getDouble('pc_dollar_number') ?? 0,
            (journal['balanceAfter'] as num).toDouble(),
          ),
        );
      }
      await PCPigProgress.sync(
        _prefs!,
        diamonds: (journal['diamondsAfter'] as num).toDouble(),
        gold: (journal['goldAfter'] as num).toDouble(),
      );
      await _prefs!.remove(storageKey);
    }
    if (journal['action'] == 'discard') {
      await _storeDiscard(_prefs!.remove(journalKey));
    } else {
      await _prefs!.remove(journalKey);
    }
  }

  Future<void> _storeDiscard(Future<bool> operation) async {
    if (!await operation) throw StateError('Unable to discard wheel reward');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
