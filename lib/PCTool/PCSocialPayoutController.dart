import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';
import 'PCSocialPayoutNotice.dart';

/// 3.7 站内通知调度：新用户前10分钟每2–5分钟，超过50%后每5–10分钟。
/// 首次活跃时间、窗口次数及文案游标落本地；后台不显示、不补发积压通知。
class PCSocialPayoutController extends ChangeNotifier {
  PCSocialPayoutController({
    SharedPreferences? preferences,
    Random? random,
    DateTime Function()? now,
    List<int> Function()? withdrawalAmounts,
  }) : _preferences = preferences,
       _random = random ?? Random(),
       _now = now ?? DateTime.now,
       _withdrawalAmounts =
           withdrawalAmounts ?? (() => PCNumberHelpers().pc_eqRange);

  static const firstSeenKey = 'pc_social_payout_first_active_v1';
  static const cursorKey = 'pc_social_payout_cursor_v1';
  static const earlyCountKey = 'pc_social_payout_early_count_v1';
  static const nextDueKey = 'pc_social_payout_next_due_v1';
  static const nextModeKey = 'pc_social_payout_next_mode_v1';
  static const earlyWindow = Duration(minutes: 10);
  final Random _random;
  final DateTime Function() _now;
  final List<int> Function() _withdrawalAmounts;
  SharedPreferences? _preferences;
  Future<void>? _loading;
  DateTime? _firstActive;
  DateTime? _nextDue;
  String? _scheduledMode;
  Timer? _timer;
  bool _foreground = false;
  bool _guideComplete = false;
  double _progress = 0;
  bool _displaying = false;
  bool _disposed = false;
  int _cursor = 0;
  int _earlyCount = 0;
  PCSocialPayoutNotice? _pending;

  DateTime? get firstActive => _firstActive;
  DateTime? get nextDue => _nextDue;
  int get earlyCount => _earlyCount;
  int get cursor => _cursor;
  bool get isLoaded => _firstActive != null;
  bool get isDisplaying => _displaying;
  PCSocialPayoutNotice? get pending => _pending;
  bool get _enabled => _foreground && _guideComplete;

  String? get _mode {
    if (_firstActive == null) return null;
    final elapsed = _now().difference(_firstActive!);
    if (!elapsed.isNegative && elapsed < earlyWindow && _earlyCount < 10) {
      return 'early';
    }
    return _progress > .5 ? 'progress' : null;
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    if (_disposed) return;
    _preferences = prefs;
    final first = prefs.getInt(firstSeenKey);
    _firstActive = first == null
        ? _now()
        : DateTime.fromMillisecondsSinceEpoch(first);
    if (first == null) {
      await prefs.setInt(firstSeenKey, _firstActive!.millisecondsSinceEpoch);
    }
    if (_disposed) return;
    _cursor =
        (prefs.getInt(cursorKey) ?? 0) % PCSocialPayoutNotice.templates.length;
    _earlyCount = (prefs.getInt(earlyCountKey) ?? 0).clamp(0, 10);
    final due = prefs.getInt(nextDueKey);
    _nextDue = due == null ? null : DateTime.fromMillisecondsSinceEpoch(due);
    _scheduledMode = prefs.getString(nextModeKey);
    _arm();
  }

  /// 页面、引导和前后台由唯一Host同步；重复刷新不会重置原有倒计时。
  void setEnvironment({
    required bool foreground,
    required bool guideComplete,
    required double progress,
  }) {
    final wasEnabled = _enabled;
    final oldMode = _mode;
    _foreground = foreground;
    _guideComplete = guideComplete;
    _progress = progress.isFinite ? progress : 0;
    if (!_enabled) {
      _timer?.cancel();
      _timer = null;
      _pending = null;
      return;
    }
    if (!wasEnabled || oldMode != _mode) {
      _timer?.cancel();
      _timer = null;
      // 离开App期间到期的计划重新间隔，不在回前台时集中弹出。
      if (_nextDue != null && !_nextDue!.isAfter(_now())) _nextDue = null;
    }
    _arm();
  }

  void _arm() {
    if (_disposed ||
        !isLoaded ||
        !_enabled ||
        _displaying ||
        _pending != null ||
        _timer != null) {
      return;
    }
    final mode = _mode;
    if (mode == null) {
      _nextDue = null;
      _scheduledMode = null;
      return;
    }
    if (_nextDue == null || _scheduledMode != mode) {
      final minMinutes = mode == 'early' ? 2 : 5;
      final spanMinutes = mode == 'early' ? 3 : 5;
      _nextDue = _now().add(
        Duration(
          seconds: minMinutes * 60 + _random.nextInt(spanMinutes * 60 + 1),
        ),
      );
      _scheduledMode = mode;
      _saveSchedule();
    }
    final boundary = _firstActive!.add(earlyWindow);
    final due = mode == 'early' && _nextDue!.isAfter(boundary)
        ? boundary
        : _nextDue!;
    final remaining = due.difference(_now());
    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _due);
  }

  void _due() {
    _timer = null;
    if (_disposed || !_enabled || _displaying) return;
    if (_mode != _scheduledMode) {
      _nextDue = null;
      _arm();
      return;
    }
    final amounts = _withdrawalAmounts().where((value) => value > 0).toList();
    if (amounts.isEmpty) {
      _nextDue = null;
      _arm();
      return;
    }
    final template = PCSocialPayoutNotice.templates[_cursor];
    _pending = PCSocialPayoutNotice(
      sequence: _cursor,
      name: template.$1,
      title: template.$2,
      bodyTemplate: template.$3,
      amount: amounts[_random.nextInt(amounts.length)].toDouble(),
      avatarName:
          'pc_rank_avatar_${(_random.nextInt(20) + 1).toString().padLeft(2, '0')}',
    );
    notifyListeners();
  }

  /// Host取得全局展示权后才计一次，排队等待不会消耗轮询次数。
  PCSocialPayoutNotice? beginPresentation() {
    if (_disposed || !_enabled || _pending == null || _displaying) return null;
    // 早期窗口在等待其他业务弹窗时也可能结束，不展示过期的早期请求。
    if (_mode != _scheduledMode) {
      _pending = null;
      _nextDue = null;
      _arm();
      return null;
    }
    final notice = _pending;
    _pending = null;
    _displaying = true;
    if (_scheduledMode == 'early') _earlyCount++;
    _cursor = (_cursor + 1) % PCSocialPayoutNotice.templates.length;
    _nextDue = null;
    final prefs = _preferences!;
    unawaited(prefs.setInt(cursorKey, _cursor));
    unawaited(prefs.setInt(earlyCountKey, _earlyCount));
    unawaited(prefs.remove(nextDueKey));
    unawaited(prefs.remove(nextModeKey));
    return notice;
  }

  void finishPresentation() {
    _displaying = false;
    _arm();
  }

  void _saveSchedule() {
    final prefs = _preferences!;
    unawaited(prefs.setInt(nextDueKey, _nextDue!.millisecondsSinceEpoch));
    unawaited(prefs.setString(nextModeKey, _scheduledMode!));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
