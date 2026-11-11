import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';
import 'PCPigProgress.dart';
import 'PCQuizConfig.dart';
import 'PCWheelOpportunityStore.dart';

/// 普通答题流程：正确次数、题目、转盘机会、待领奖励和三阶段数量持久化。
/// 领取与放弃均先写恢复日志；失败或关闭后清除当前待奖，题目进度不回退。
class PCQuizController extends ChangeNotifier {
  PCQuizController({Random? random, this.onSync})
    : _random = random ?? Random() {
    if (kDebugMode) _debugInstances.add(this);
  }
  static final Set<PCQuizController> _debugInstances = {};
  static const storageKey = 'pc_quiz_flow_v1';
  static const journalKey = 'pc_quiz_reward_journal_v1';
  final Random _random;
  final Future<void> Function()? onSync;
  SharedPreferences? _prefs;
  Future<void>? _loading;
  Map<String, dynamic> _data = {};
  bool _loaded = false;
  bool _busy = false;
  Completer<void>? _mutationFinished;
  bool _disposed = false;
  PCQuizConfig config = const PCQuizConfig();
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  int get questionIndex =>
      (_data['questionIndex'] as int? ?? 0).clamp(0, 1 << 30);
  int get correctCount =>
      (_data['correctCount'] as int? ?? 0).clamp(0, 1 << 30);
  double get balance => _prefs?.getDouble('pc_dollar_number') ?? 0;
  // 转盘也会增加阶段数量；读取同一份精确缓存，避免常驻答题页按旧数量采样奖励。
  double get diamonds => max(
    (_data['diamonds'] as num? ?? 0).toDouble(),
    _prefs?.getDouble('pc_quiz_diamonds') ?? 0,
  );
  double get gold => max(
    (_data['gold'] as num? ?? 0).toDouble(),
    _prefs?.getDouble('pc_quiz_gold') ?? 0,
  );
  int get spins => _prefs?.getInt('pc_wheel_number') ?? 0;

  /// 保留旧调用兼容；金砖达到提现目标后答题和奖励仍继续。
  bool get isComplete => false;
  PCQuizRewardType get stage =>
      PCQuizRewardType.values[(_prefs?.getInt('pc_pig_level') ?? 0).clamp(
        0,
        2,
      )];
  PCQuizReward? get pendingReward {
    final raw = _data['pendingReward'];
    return raw is Map
        ? PCQuizReward.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  Set<int> get openedMilestones =>
      (_data['openedMilestones'] as List? ?? const [])
          .whereType<int>()
          .where((i) => i >= 0)
          .toSet();
  static int milestone(int index) => 2 + index * 3;
  static int opportunitiesAt(int correct) =>
      correct < 2 ? 0 : (correct - 2) ~/ 3 + 1;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    await PCNumberHelpers().pc_initNumberModel(preferences: prefs);
    config = PCQuizConfig.fromModel(PCNumberHelpers().model);
    Map<String, dynamic> decode(String? raw) {
      try {
        return Map<String, dynamic>.from(jsonDecode(raw ?? '{}') as Map);
      } catch (_) {
        return {};
      }
    }

    _data = decode(prefs.getString(storageKey));
    if (_data.isEmpty) {
      _data = {
        'questionIndex': prefs.getInt('pc_quiz_num_index') ?? 0,
        'correctCount': prefs.getInt('pc_quiz_all_num') ?? 0,
        'diamonds':
            prefs.getDouble('pc_quiz_diamonds') ??
            (prefs.getInt('pc_domand_number') ?? 0).toDouble(),
        'gold':
            prefs.getDouble('pc_quiz_gold') ??
            (prefs.getInt('pc_zhuan_number') ?? 0).toDouble(),
        'openedMilestones':
            (prefs.getStringList('pc_quiz_clicked_wheels') ?? [])
                .map(int.tryParse)
                .whereType<int>()
                .toList(),
      };
    }
    await _writeFlow(_data);
    final journal = decode(prefs.getString(journalKey));
    if (journal['flow'] is Map) await _applyJournal(journal);
    _loaded = true;
    await onSync?.call();
    _notify();
  }

  /// 所有会回写答题快照的操作串行；放弃须等待在途写入，避免旧快照复活待奖。
  Future<T> _mutate<T>(
    Future<T> Function() action, {
    required T busyValue,
    bool waitForIdle = false,
  }) async {
    while (_busy) {
      if (!waitForIdle) return busyValue;
      await _mutationFinished!.future;
    }
    _busy = true;
    final finished = _mutationFinished = Completer<void>();
    _notify();
    try {
      await load();
      return await action();
    } finally {
      _busy = false;
      _mutationFinished = null;
      finished.complete();
      _notify();
    }
  }

  Future<void> refreshBalance() => _mutate<void>(
    () async {
      await _prefs!.reload();
      await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
      config = PCQuizConfig.fromModel(PCNumberHelpers().model);
      await _writeFlow(_data);
    },
    busyValue: null,
    waitForIdle: true,
  );

  /// 仅调试改数后刷新常驻答题页，避免旧内存快照用max恢复已调低的数量。
  /// 等待已有答题事务结束，不重置题目、次数或待领奖励。
  static Future<void> debugReloadActiveProgress() async {
    if (!kDebugMode) return;
    for (final controller in _debugInstances.toList()) {
      if (controller._loading != null) await controller._loading;
      if (controller._disposed || !controller._loaded) continue;
      await controller._mutate<void>(
        () async {
          if (controller._disposed) return;
          await controller._prefs!.reload();
          controller._data = {
            ...controller._data,
            'diamonds': controller._prefs!.getDouble('pc_quiz_diamonds') ?? 0,
            'gold': controller._prefs!.getDouble('pc_quiz_gold') ?? 0,
          };
        },
        busyValue: null,
        waitForIdle: true,
      );
    }
  }

  Future<PCQuizReward?> answer({
    required bool correct,
    int? expectedQuestionIndex,
  }) => _mutate<PCQuizReward?>(() async {
    if (pendingReward != null ||
        isComplete ||
        (expectedQuestionIndex != null &&
            expectedQuestionIndex != questionIndex)) {
      return null;
    }
    final next = Map<String, dynamic>.from(_data)
      ..['questionIndex'] = questionIndex + 1;
    PCQuizReward? reward;
    if (correct) {
      final type = stage;
      final collected = switch (type) {
        PCQuizRewardType.cash => balance,
        PCQuizRewardType.diamond => diamonds,
        PCQuizRewardType.gold => gold,
      };
      reward = PCQuizReward(
        id: 'quiz_${correctCount + 1}',
        type: type,
        amount: config.prize(type, collected, _random),
        questionIndex: questionIndex,
      );
      next['correctCount'] = correctCount + 1;
      if (reward.amount > 0) {
        next['pendingReward'] = reward.toJson();
      } else {
        reward = null;
      }
      final extra =
          opportunitiesAt(correctCount + 1) - opportunitiesAt(correctCount);
      if (extra > 0) {
        // 记录真实答题事件，和每日赠送/转盘扣次共用账本，恢复不重复加次。
        next['spinAward'] = {'correctCount': correctCount + 1, 'amount': extra};
      }
    }
    await _writeFlow(next);
    await onSync?.call();
    return reward;
  }, busyValue: null);

  Future<PCQuizReward?> claim({String? expectedRewardId}) =>
      _mutate<PCQuizReward?>(() async {
        final reward = pendingReward;
        if (reward == null ||
            (expectedRewardId != null && reward.id != expectedRewardId)) {
          return null;
        }
        final flow = Map<String, dynamic>.from(_data)..remove('pendingReward');
        double afterBalance = balance;
        if (reward.type == PCQuizRewardType.cash) {
          afterBalance = ((balance + reward.amount) * 100).round() / 100;
        } else if (reward.type == PCQuizRewardType.diamond) {
          flow['diamonds'] = ((diamonds + reward.amount) * 100).round() / 100;
        } else {
          flow['gold'] = ((gold + reward.amount) * 100).round() / 100;
        }
        final journal = {
          'action': 'claim',
          'rewardId': reward.id,
          'balanceAfter': afterBalance,
          'flow': flow,
        };
        await _stored(_prefs!.setString(journalKey, jsonEncode(journal)));
        await _applyJournal(journal);
        await onSync?.call();
        return reward;
      }, busyValue: null);

  /// 放弃关闭或激励失败的当前待奖；不发奖、不回退题号/累计答题及已赠转盘次数。
  /// 持久化后才返回，旧弹窗的迟到回调不能删除新题奖励。
  Future<bool> discardPendingReward({String? expectedRewardId}) =>
      _mutate<bool>(
        () async {
          final reward = pendingReward;
          if (reward == null ||
              (expectedRewardId != null && reward.id != expectedRewardId)) {
            return false;
          }
          final journal = {
            'action': 'discard',
            'rewardId': reward.id,
            'flow': Map<String, dynamic>.from(_data)..remove('pendingReward'),
          };
          await _stored(_prefs!.setString(journalKey, jsonEncode(journal)));
          await _applyJournal(journal);
          await onSync?.call();
          return true;
        },
        busyValue: false,
        waitForIdle: true,
      );

  Future<void> _stored(Future<bool> operation) async {
    if (!await operation) throw StateError('Unable to save quiz progress');
  }

  Future<void> _applyJournal(Map<String, dynamic> journal) async {
    if (journal['action'] != 'discard') {
      final after = (journal['balanceAfter'] as num).toDouble();
      await _stored(_prefs!.setDouble('pc_dollar_number', max(balance, after)));
    }
    await _writeFlow(Map<String, dynamic>.from(journal['flow'] as Map));
    await _stored(_prefs!.remove(journalKey));
  }

  Future<void> _writeFlow(Map<String, dynamic> next) async {
    await PCWheelOpportunityStore.transaction(_prefs!, (ledger) async {
      final progress = await PCPigProgress.sync(
        _prefs!,
        diamonds: (next['diamonds'] as num?)?.toDouble(),
        gold: (next['gold'] as num?)?.toDouble(),
      );
      next = {...next, 'diamonds': progress.diamonds, 'gold': progress.gold};
      await _stored(_prefs!.setString(storageKey, jsonEncode(next)));
      _data = next;
      await _prefs!.setInt('pc_quiz_num_index', questionIndex);
      await _prefs!.setInt('pc_quiz_all_num', correctCount);
      await _prefs!.setDouble('pc_quiz_diamonds', diamonds);
      await _prefs!.setDouble('pc_quiz_gold', gold);
      await _prefs!.setInt('pc_domand_number', diamonds.floor());
      await _prefs!.setInt('pc_zhuan_number', gold.floor());
      final spinTarget = next['spinTarget'] as int?;
      final spinAward = next['spinAward'];
      if (spinAward is Map) {
        await ledger.awardQuiz(
          correctCount: spinAward['correctCount'] as int,
          amount: spinAward['amount'] as int,
        );
      } else if (spinTarget != null) {
        await ledger.awardQuiz(
          correctCount: correctCount,
          amount: 0,
          legacyTarget: spinTarget,
        );
      }
      if (spinTarget != null || spinAward is Map) {
        _data = Map<String, dynamic>.from(_data)
          ..remove('spinTarget')
          ..remove('spinAward');
        await _stored(_prefs!.setString(storageKey, jsonEncode(_data)));
      }
    });
  }

  Future<bool> openMilestone(int index) => _mutate<bool>(() async {
    if (index < 0 ||
        correctCount < milestone(index) ||
        openedMilestones.contains(index)) {
      return false;
    }
    final opened = openedMilestones..add(index);
    await _writeFlow(
      Map<String, dynamic>.from(_data)..['openedMilestones'] = opened.toList(),
    );
    await _prefs!.setInt('pc_quiz_tap_index', index);
    return true;
  }, busyValue: false);

  @override
  void dispose() {
    if (kDebugMode) _debugInstances.remove(this);
    _disposed = true;
    super.dispose();
  }
}
