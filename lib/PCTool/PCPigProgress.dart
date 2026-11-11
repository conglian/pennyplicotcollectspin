import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';

/// 本地猪阶段：0 粉猪、1 钻石猪、2 金猪；升级后不会因余额扣减而降级。
/// 钻石收集满20后才开始到下一本地午夜的倒计时；数量仍可继续累计。
class PCPigProgress {
  const PCPigProgress(this.level, this.diamonds, this.gold, this.balance);
  static const diamondEnteredKey = 'pc_diamond_entered_at_v1';
  static const diamondDeadlineKey = 'pc_diamond_deadline_v1';
  static const diamondCountdownStartedKey =
      'pc_diamond_countdown_started_at_v2';
  static bool _syncing = false;
  static final List<Completer<void>> _waiters = [];
  final int level;
  final double diamonds, gold, balance;
  double get amount => level == 0
      ? balance
      : level == 1
      ? diamonds
      : gold;

  /// 各奖励来源串行镜像，避免并发旧快照覆盖刚完成的阶段和数量。
  static Future<PCPigProgress> sync(
    SharedPreferences prefs, {
    double? diamonds,
    double? gold,
    DateTime? now,
  }) async {
    while (_syncing) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _syncing = true;
    try {
      return await _sync(prefs, diamonds: diamonds, gold: gold, now: now);
    } finally {
      _syncing = false;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }

  static DateTime? diamondEnteredAt(SharedPreferences prefs) =>
      _date(prefs.getString(diamondEnteredKey));
  static DateTime? diamondDeadline(SharedPreferences prefs) =>
      diamondCountdownStartedAt(prefs) == null
      ? null
      : _date(prefs.getString(diamondDeadlineKey));
  static DateTime? diamondCountdownStartedAt(SharedPreferences prefs) =>
      _date(prefs.getString(diamondCountdownStartedKey));
  static DateTime? _date(String? raw) =>
      DateTime.tryParse(raw ?? '')?.toLocal();

  static Future<PCPigProgress> _sync(
    SharedPreferences prefs, {
    double? diamonds,
    double? gold,
    DateTime? now,
  }) async {
    final currentTime = (now ?? DateTime.now()).toLocal();
    final balance = prefs.getDouble('pc_dollar_number') ?? 0;
    final savedLevel = (prefs.getInt('pc_pig_level') ?? 0).clamp(0, 2);
    final legacyAmount = prefs.getDouble('pc_pig_level_index') ?? 0;
    double precise(double value) {
      if (!value.isFinite) return 0;
      value = max(0, value);
      return (value * 100).round() / 100;
    }

    final d = precise(
      max(
        diamonds ?? 0,
        max(
          prefs.getDouble('pc_quiz_diamonds') ??
              (prefs.getInt('pc_domand_number') ?? 0).toDouble(),
          savedLevel == 1
              ? legacyAmount
              : savedLevel == 2 &&
                    !prefs.containsKey('pc_quiz_diamonds') &&
                    !prefs.containsKey('pc_domand_number')
              ? 20
              : 0,
        ),
      ),
    );
    final g = precise(
      max(
        gold ?? 0,
        max(
          prefs.getDouble('pc_quiz_gold') ??
              (prefs.getInt('pc_zhuan_number') ?? 0).toDouble(),
          savedLevel == 2 ? legacyAmount : 0,
        ),
      ),
    );
    var level = max(
      savedLevel,
      g > 0
          ? 2
          : balance >= PCNumberHelpers().pc_firstTarget || d > 0
          ? 1
          : 0,
    );
    if (level >= 1) {
      final entered =
          diamondEnteredAt(prefs) ??
          _date(prefs.getString('pc_pig_upgrade_date_1')) ??
          currentTime;
      await _stored(
        prefs.setString(diamondEnteredKey, entered.toIso8601String()),
      );
      if (level == 1 && d >= PCNumberHelpers.diamondTarget) {
        // 旧档曾在入钻时写截止时间，只有新达标标记对应的截止时间才可升级。
        final started = diamondCountdownStartedAt(prefs) ?? currentTime;
        final deadline =
            diamondDeadline(prefs) ??
            DateTime(started.year, started.month, started.day + 1);
        await _stored(
          prefs.setString(diamondDeadlineKey, deadline.toIso8601String()),
        );
        await _stored(
          prefs.setString(
            diamondCountdownStartedKey,
            started.toIso8601String(),
          ),
        );
        if (!currentTime.isBefore(deadline)) level = 2;
      } else if (level == 1) {
        // 未满20时不计时；清理旧版本入钻即开启的截止时间。
        for (final key in [diamondDeadlineKey, diamondCountdownStartedKey]) {
          if (prefs.containsKey(key)) await _stored(prefs.remove(key));
        }
      }
    }
    final result = PCPigProgress(level, d, g, balance);
    if (level > savedLevel) {
      await _stored(
        prefs.setString(
          'pc_pig_upgrade_date_$level',
          currentTime.toIso8601String(),
        ),
      );
    }
    // 先存精确数量和新阶段镜像，再存level；中途中断不会把旧钻石镜像当成金砖。
    await _stored(prefs.setDouble('pc_quiz_diamonds', d));
    await _stored(prefs.setDouble('pc_quiz_gold', g));
    await _stored(prefs.setInt('pc_domand_number', d.floor()));
    await _stored(prefs.setInt('pc_zhuan_number', g.floor()));
    await _stored(prefs.setDouble('pc_pig_level_index', result.amount));
    await _stored(prefs.setInt('pc_pig_level', level));
    return result;
  }

  static Future<void> _stored(Future<bool> operation) async {
    if (!await operation) throw StateError('Pig progress could not be saved');
  }
}
