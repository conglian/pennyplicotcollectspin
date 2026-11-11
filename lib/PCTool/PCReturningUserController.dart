import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 老用户跨自然日回访记录；未展示的 Grow Bonus 可在冷启动后恢复。
/// 只记录展示日期，不发放奖励，也不修改美元、钻石或金砖余额。
class PCReturningUserController {
  PCReturningUserController({
    SharedPreferences? preferences,
    DateTime Function()? now,
  }) : _preferences = preferences,
       _now = now ?? DateTime.now;

  static const storageKey = 'pc_returning_user_flow_v1';
  final DateTime Function() _now;
  SharedPreferences? _preferences;
  String? _pendingDay;
  String? _lastOpenDay;
  String? _shownDay;

  String get today => dateKey(_now());
  bool get isPending => _pendingDay == today && _shownDay != today;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String? _validDay(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    return parsed != null && dateKey(parsed) == value ? value : null;
  }

  /// 启动或回前台时检查本地日期；新用户未完成引导时仅建立日期基线。
  /// 兼容旧版 pc_day_date，并将待展示、已展示和打开日期一起持久化。
  Future<void> prepareLaunch({required bool isExistingUser}) async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    Map<String, dynamic> saved = {};
    try {
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {
      // 旧记录异常时仍可从历史启动日期恢复，不能阻断应用启动。
    }
    final day = today;
    final previous =
        _validDay(saved['lastOpenDay']) ??
        _validDay(prefs.getString('pc_day_date'));
    final shown = _validDay(saved['shownDay']);
    final pending = _validDay(saved['pendingDay']);
    final eligible =
        isExistingUser &&
        shown != day &&
        ((previous != null && previous.compareTo(day) < 0) || pending == day);
    // 时钟回拨时保留较晚的打开日期，避免将同一次回访当成新的跨天。
    final lastOpen = previous != null && previous.compareTo(day) > 0
        ? previous
        : day;
    final next = <String, dynamic>{
      'lastOpenDay': lastOpen,
      'shownDay': ?shown,
      if (eligible) 'pendingDay': day,
    };
    await _save(next);
  }

  /// 弹窗路由创建后记录当天已展示；关闭和 Go Earn 均不再重复弹出。
  Future<void> markShown() async {
    if (!isPending) return;
    await _save({'lastOpenDay': _lastOpenDay ?? today, 'shownDay': today});
  }

  Future<void> _save(Map<String, dynamic> state) async {
    final prefs = _preferences!;
    final raw = jsonEncode(state);
    if (prefs.getString(storageKey) != raw &&
        !await prefs.setString(storageKey, raw)) {
      throw StateError('Unable to save returning user progress');
    }
    _lastOpenDay = state['lastOpenDay'] as String?;
    _shownDay = state['shownDay'] as String?;
    _pendingDay = state['pendingDay'] as String?;
  }
}
