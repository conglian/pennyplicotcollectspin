import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';
import 'PCPigProgress.dart';
import 'PCQuizConfig.dart';

/// 首页三个奖励气泡：缓存展示金额，领取成功后按新阶段、数量重新生成全部三个奖励。
/// 第0个免费气泡打开领奖框时冷却60秒；预留记录独立落盘，关闭不发奖也不重置。
/// 同代气泡只可结算一次；领取日志用绝对目标值恢复，冷启动不重复发奖。
class PCHomeRewardController extends ChangeNotifier {
  PCHomeRewardController({
    Random? random,
    DateTime Function()? now,
    this.onSync,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;
  static const storageKey = 'pc_home_bubble_rewards_v1';
  static const journalKey = 'pc_home_bubble_journal_v1';
  static const freeSlot = 0;
  static const freeCooldown = Duration(seconds: 60);
  static bool _claimInFlight = false;
  final Random _random;
  final DateTime Function() _now;
  final Future<void> Function()? onSync;
  SharedPreferences? _prefs;
  Future<void>? _loading;
  Future<void>? _refreshing;
  Map<String, dynamic> _data = {};
  Timer? _cooldownTimer;
  bool _loaded = false, _busy = false, _disposed = false;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy || _refreshing != null;
  int get generation => _data['generation'] as int? ?? 0;
  int get level => _data['level'] as int? ?? 0;
  double get collected => (_data['amount'] as num? ?? 0).toDouble();
  double get diamonds => _prefs?.getDouble('pc_quiz_diamonds') ?? 0;
  double get gold => _prefs?.getDouble('pc_quiz_gold') ?? 0;
  DateTime? get freeCooldownUntil {
    final value = _cooldownMillis(_data);
    return value > 0 ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  Duration get freeCooldownRemaining {
    final until = freeCooldownUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 向上取整，剩余不足1秒仍保持禁用，避免显示0秒却不能点击。
  int get freeCooldownSeconds =>
      (freeCooldownRemaining.inMicroseconds / Duration.microsecondsPerSecond)
          .ceil();

  bool isFreeSlot(int slot) => slot == freeSlot;

  bool canTapSlot(int slot) =>
      _loaded &&
      !isBusy &&
      slot >= 0 &&
      slot < amounts.length &&
      amounts[slot] > 0 &&
      (!isFreeSlot(slot) || freeCooldownRemaining == Duration.zero);

  List<double> get amounts => List.unmodifiable(
    (_data['prizes'] as List? ?? const []).map((v) => (v as num).toDouble()),
  );
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Map<String, dynamic> _read(String key) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(_prefs!.getString(key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
    await _refresh();
    _loaded = true;
    _notify();
  }

  int _cooldownMillis(Map<String, dynamic> source) {
    final value = source['freeCooldownUntil'];
    return value is num && value.isFinite && value > 0 ? value.toInt() : 0;
  }

  Map<String, dynamic> _snapshot(
    PCPigProgress progress,
    int nextGeneration, {
    required int freeCooldownUntil,
  }) => {
    'generation': nextGeneration,
    'level': progress.level,
    'amount': progress.amount,
    'config': jsonEncode(PCNumberHelpers().model.toJson()),
    'freeCooldownUntil': freeCooldownUntil,
    'prizes': List.generate(
      3,
      (_) => PCNumberHelpers().pc_prizeForLevel(
        progress.level,
        progress.amount,
        random: _random,
      ),
    ),
  };

  Future<void> _refresh() async {
    await _prefs!.reload();
    // 本次运行写入途中失败后也可恢复，不能等下次冷启动才补回冷却和奖励。
    final journal = _read(journalKey);
    if (journal['snapshot'] is Map) await _applyJournal(journal);
    await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
    final progress = await PCPigProgress.sync(_prefs!);
    final saved = _read(storageKey);
    final prizes = saved['prizes'];
    final valid =
        prizes is List &&
        prizes.length == 3 &&
        // 旧版金砖满10时缓存了三个0；升级后必须重新按末档生成，不能复用。
        prizes.every((v) => v is num && v.isFinite && v > 0);
    if (valid &&
        saved['level'] == progress.level &&
        saved['amount'] == progress.amount &&
        saved['config'] == jsonEncode(PCNumberHelpers().model.toJson())) {
      _data = saved;
      _updateCooldownTimer();
      return;
    }
    final next = _snapshot(
      progress,
      (saved['generation'] as int? ?? 0) + 1,
      freeCooldownUntil: _cooldownMillis(saved),
    );
    await _stored(_prefs!.setString(storageKey, jsonEncode(next)));
    _data = next;
    _updateCooldownTimer();
  }

  void _updateCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    if (_disposed || freeCooldownRemaining == Duration.zero) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (freeCooldownRemaining == Duration.zero) {
        timer.cancel();
        _cooldownTimer = null;
      }
      _notify();
    });
  }

  /// 普通重建不重新随机；阶段、余额或配置改变时才刷新。
  Future<void> refresh() async {
    await load();
    if (_busy) return;
    final existing = _refreshing;
    if (existing != null) return existing;
    final work = _refresh();
    _refreshing = work;
    try {
      await work;
    } finally {
      _refreshing = null;
      _notify();
    }
  }

  PCQuizReward? rewardAt(int slot) {
    if (!_loaded ||
        slot < 0 ||
        slot >= amounts.length ||
        amounts[slot] <= 0 ||
        (isFreeSlot(slot) && freeCooldownRemaining > Duration.zero)) {
      return null;
    }
    return _rewardAt(slot);
  }

  PCQuizReward _rewardAt(int slot, {String? id}) {
    return PCQuizReward(
      id: id ?? 'bubble_${generation}_$slot',
      type: PCQuizRewardType.values[level],
      amount: amounts[slot],
      questionIndex: -1,
    );
  }

  /// 免费入口先预留本次领奖并开始冷却，不增加余额。
  ///
  /// 只有返回的奖励可在冷却中领取；关闭后继续计时，下次打开生成新的预留ID。
  /// 其他奖励或配置变化生成新一代时自动作废旧预留，不能跨代补发。
  Future<PCQuizReward?> reserveFreeReward() async {
    if (_busy || _claimInFlight) return null;
    _claimInFlight = true;
    _busy = true;
    _notify();
    try {
      await load();
      await _refreshing;
      await _refresh();
      final reward = rewardAt(freeSlot);
      if (reward == null) return null;
      final oldSequence = _data['freeReservationSequence'];
      final sequence = (oldSequence is num ? oldSequence.toInt() : 0) + 1;
      final reserved = _rewardAt(
        freeSlot,
        id: '${reward.id}_reserved_$sequence',
      );
      final next = {
        ..._data,
        'freeCooldownUntil': _now().add(freeCooldown).millisecondsSinceEpoch,
        'freeReservedRewardId': reserved.id,
        'freeReservationSequence': sequence,
      };
      await _stored(_prefs!.setString(storageKey, jsonEncode(next)));
      _data = next;
      _updateCooldownTimer();
      return reserved;
    } finally {
      _claimInFlight = false;
      _busy = false;
      _notify();
    }
  }

  Future<PCQuizReward?> beginFreeReward() => reserveFreeReward();

  Future<PCQuizReward?> claim(PCQuizReward reward) async {
    if (_busy || _claimInFlight) return null;
    _claimInFlight = true;
    _busy = true;
    _notify();
    try {
      await load();
      await _refreshing;
      await _prefs!.reload();
      final pending = _read(journalKey);
      if (pending['snapshot'] is Map) await _applyJournal(pending);
      final saved = _read(storageKey);
      if (saved['generation'] != generation) {
        await _refresh();
        return null;
      }
      // 同代也可能已被另一个页面重新预留，必须使用最新落盘的预留ID及截止时间。
      _data = saved;
      _updateCooldownTimer();
      final isReserved = _data['freeReservedRewardId'] == reward.id;
      final slot =
          List.generate(
            3,
            (slot) => _rewardAt(
              slot,
              id: isFreeSlot(slot) && isReserved ? reward.id : null,
            ),
          ).indexWhere(
            (r) =>
                r.id == reward.id &&
                r.amount == reward.amount &&
                r.type == reward.type,
          );
      if (slot < 0) return null;
      if (isFreeSlot(slot) &&
          !isReserved &&
          freeCooldownRemaining > Duration.zero) {
        return null;
      }
      await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
      final before = await PCPigProgress.sync(_prefs!);
      // 页面展示期间被其他入口改变了阶段/数量时，拒绝旧气泡，避免按旧档位发奖。
      if (before.level != level ||
          before.amount != collected ||
          _data['config'] != jsonEncode(PCNumberHelpers().model.toJson())) {
        await _refresh();
        return null;
      }
      double add(double value, double target) =>
          min(target, ((value + reward.amount) * 100).round() / 100);
      final balance = reward.type == PCQuizRewardType.cash
          ? add(before.balance, PCNumberHelpers().pc_firstTarget)
          : before.balance;
      final diamonds = reward.type == PCQuizRewardType.diamond
          ? ((before.diamonds + reward.amount) * 100).round() / 100
          : before.diamonds;
      final gold = reward.type == PCQuizRewardType.gold
          ? ((before.gold + reward.amount) * 100).round() / 100
          : before.gold;
      final nextLevel = max(
        before.level,
        gold > 0
            ? 2
            : balance >= PCNumberHelpers().pc_firstTarget || diamonds > 0
            ? 1
            : 0,
      );
      final journal = <String, dynamic>{
        'rewardId': reward.id,
        if (reward.type == PCQuizRewardType.cash) 'balanceAfter': balance,
        'diamondsAfter': diamonds,
        'goldAfter': gold,
        'snapshot': _snapshot(
          PCPigProgress(nextLevel, diamonds, gold, balance),
          generation + 1,
          freeCooldownUntil: isFreeSlot(slot) && !isReserved
              ? _now().add(freeCooldown).millisecondsSinceEpoch
              : _cooldownMillis(_data),
        ),
      };
      await _stored(_prefs!.setString(journalKey, jsonEncode(journal)));
      await _applyJournal(journal);
      await onSync?.call();
      return reward;
    } finally {
      _claimInFlight = false;
      _busy = false;
      _notify();
    }
  }

  Future<void> _applyJournal(Map<String, dynamic> journal) async {
    if (journal['balanceAfter'] is num) {
      await _stored(
        _prefs!.setDouble(
          'pc_dollar_number',
          max(
            _prefs!.getDouble('pc_dollar_number') ?? 0,
            (journal['balanceAfter'] as num).toDouble(),
          ),
        ),
      );
    }
    await PCPigProgress.sync(
      _prefs!,
      diamonds: (journal['diamondsAfter'] as num).toDouble(),
      gold: (journal['goldAfter'] as num).toDouble(),
    );
    final next = Map<String, dynamic>.from(journal['snapshot'] as Map);
    await _stored(_prefs!.setString(storageKey, jsonEncode(next)));
    _data = next;
    _updateCooldownTimer();
    await _stored(_prefs!.remove(journalKey));
  }

  Future<void> _stored(Future<bool> operation) async {
    if (!await operation) throw StateError('Home reward could not be saved');
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
