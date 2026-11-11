import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 转盘机会共用事务：每日赠送、答题加次及转动扣次串行提交到单个账本。
/// pc_wheel_number仅作兼容镜像；先提交账本，重启时修复未完成的镜像写入。
abstract final class PCWheelOpportunityStore {
  static const storageKey = 'pc_wheel_opportunities_v1';
  static const dailySpins = 3;
  static bool _locked = false;
  static final List<Completer<void>> _waiters = [];

  static String dayKey(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  static Future<T> transaction<T>(
    SharedPreferences prefs,
    Future<T> Function(PCWheelOpportunityTransaction ledger) action,
  ) async {
    while (_locked) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _locked = true;
    try {
      await prefs.reload();
      final ledger = PCWheelOpportunityTransaction._(prefs);
      await ledger._initialize();
      return await action(ledger);
    } finally {
      _locked = false;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }
}

/// 只在PCWheelOpportunityStore.transaction回调内使用，不能跨事务保留。
class PCWheelOpportunityTransaction {
  PCWheelOpportunityTransaction._(this._prefs);
  final SharedPreferences _prefs;
  late Map<String, dynamic> _data;
  int get balance => (_data['balance'] as int? ?? 0).clamp(0, 1 << 30);

  Map<String, dynamic> _read(String key) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(_prefs.getString(key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _initialize() async {
    _data = _read(PCWheelOpportunityStore.storageKey);
    if (_data['balance'] is! int) {
      final quiz = _read('pc_quiz_flow_v1');
      final journal = _read('pc_wheel_transaction_v1');
      final oldStart =
          journal['action'] == 'start' &&
          journal['opportunityEvent'] != true &&
          journal['turn'] is Map;
      final turn = oldStart
          ? Map<String, dynamic>.from(journal['turn'] as Map)
          : <String, dynamic>{};
      final pending = _read('pc_wheel_pending_v1');
      var initial = math.max(0, _prefs.getInt('pc_wheel_number') ?? 0);
      // 旧扣次日志先恢复；已转动/待奖时不能被旧答题绝对目标补回消耗的次数。
      if (oldStart) {
        initial = math.max(0, turn['spinsAfter'] as int? ?? initial);
      } else if (pending.isEmpty && quiz['spinTarget'] is int) {
        initial = math.max(initial, quiz['spinTarget'] as int);
      }
      final award = quiz['spinAward'];
      final count = quiz['correctCount'] as int? ?? 0;
      _data = {
        'balance': initial,
        'lastGrantDay': '',
        'quizAwardThrough': award is Map ? math.max(0, count - 1) : count,
        'wheelAppliedId': (turn['reward'] as Map?)?['id'] ?? '',
      };
      await _commit();
    } else if (_prefs.getInt('pc_wheel_number') != balance) {
      await _stored(_prefs.setInt('pc_wheel_number', balance));
    }
  }

  Future<bool> grantDaily(DateTime now) async {
    final today = PCWheelOpportunityStore.dayKey(now);
    final last = _data['lastGrantDay'] as String? ?? '';
    if (last.compareTo(today) >= 0) return false;
    _data = {
      ..._data,
      'balance': balance + PCWheelOpportunityStore.dailySpins,
      'lastGrantDay': today,
    };
    await _commit();
    return true;
  }

  Future<void> awardQuiz({
    required int correctCount,
    required int amount,
    int? legacyTarget,
  }) async {
    if (correctCount <= (_data['quizAwardThrough'] as int? ?? 0)) return;
    _data = {
      ..._data,
      'balance': legacyTarget == null
          ? balance + math.max(0, amount)
          : math.max(balance, legacyTarget),
      'quizAwardThrough': correctCount,
    };
    await _commit();
  }

  Future<void> consumeWheel(String eventId, {int? legacyTarget}) async {
    if (_data['wheelAppliedId'] == eventId) return;
    if (legacyTarget == null && balance <= 0) {
      throw StateError('No wheel opportunities remain');
    }
    _data = {
      ..._data,
      'balance': legacyTarget == null ? balance - 1 : math.max(0, legacyTarget),
      'wheelAppliedId': eventId,
    };
    await _commit();
  }

  /// 仅Debug表单在统一事务中绝对改数，保留每日赠送日期和所有防重游标。
  Future<void> debugSetBalance(int value) async {
    if (!kDebugMode) throw UnsupportedError('仅Debug版本允许修改转盘次数');
    if (value < 0 || value > 1000000000) {
      throw const FormatException('转盘次数须为0到1000000000之间的整数');
    }
    _data = {..._data, 'balance': value};
    await _commit();
  }

  Future<void> _commit() async {
    await _stored(
      _prefs.setString(PCWheelOpportunityStore.storageKey, jsonEncode(_data)),
    );
    await _stored(_prefs.setInt('pc_wheel_number', balance));
  }

  Future<void> _stored(Future<bool> value) async {
    if (!await value) throw StateError('Unable to save wheel opportunities');
  }
}
