import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';

/// 3.7 答题横幅策略：仅按配置答题次数触发，一次只保留一个请求。
/// 正确题等待领奖到账结束，满足次数后再等1秒；六条文案顺序轮换。
class PCQuizBannerController extends ChangeNotifier {
  PCQuizBannerController({
    int Function()? answerThreshold,
    double Function()? withdrawalTarget,
  }) : _answerThreshold =
           answerThreshold ?? (() => PCNumberHelpers().pc_quizConsole),
       _withdrawalTarget =
           withdrawalTarget ?? (() => PCNumberHelpers().pc_firstTarget);

  static const cursorKey = 'pc_quiz_banner_cursor_v1';
  final int Function() _answerThreshold;
  final double Function() _withdrawalTarget;
  SharedPreferences? _preferences;
  Timer? _answerTimer;
  bool _active = false;
  bool _displaying = false;
  bool _waitingForReward = false;
  bool _disposed = false;
  int _answerCount = 0;
  int _lastQuestionIndex = -1;
  int _cursor = 0;
  String? _pendingMessage;

  String? get pendingMessage => _pendingMessage;
  bool get isDisplaying => _displaying;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    if (_disposed) return;
    _preferences = preferences;
    _cursor = (preferences.getInt(cursorKey) ?? 0) % 6;
    _armTimers();
  }

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    _cancelTimers();
    if (active) {
      if (_pendingMessage != null) notifyListeners();
      _armTimers();
    }
  }

  /// 离开答题页或进入后台时丢弃已达门槛的旧提示，回到页面不补弹。
  /// 未达门槛的答题计数保留，后续仍由真实答题推进。
  void cancelPending() {
    _cancelTimers();
    _pendingMessage = null;
    if (_answerCount >= _answerThreshold().clamp(1, 100000)) {
      _answerCount = 0;
    }
  }

  void recordAnswer({required int questionIndex, required bool correct}) {
    if (questionIndex <= _lastQuestionIndex) return;
    _lastQuestionIndex = questionIndex;
    _answerCount++;
    _waitingForReward = correct;
    _armTimers();
  }

  void rewardFinished() {
    _waitingForReward = false;
    _armTimers();
  }

  /// 先取得全局展示权再调用，避免横幅在其他弹窗等待期间被计为已展示。
  void beginPresentation() {
    if (_pendingMessage == null || _displaying) return;
    _displaying = true;
    _pendingMessage = null;
    _answerCount = 0;
    _cursor = (_cursor + 1) % 6;
    _cancelTimers();
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setInt(cursorKey, _cursor));
    }
  }

  void finishPresentation() {
    _displaying = false;
    _armTimers();
  }

  void _armTimers() {
    if (_disposed ||
        _preferences == null ||
        !_active ||
        _displaying ||
        _pendingMessage != null ||
        _waitingForReward) {
      return;
    }
    if (_answerCount >= _answerThreshold().clamp(1, 100000)) {
      _answerTimer ??= Timer(const Duration(seconds: 1), _request);
    }
  }

  void _request() {
    _cancelTimers();
    if (_disposed || !_active || _displaying || _waitingForReward) return;
    final target = _withdrawalTarget();
    final amount = target == target.roundToDouble()
        ? target.toInt().toString()
        : target.toStringAsFixed(2);
    final cash = '\$$amount';
    final messages = [
      'Keep Answering! Today Super Easy Cash Out $cash',
      'Keep Going! $cash Is Within Reach — One Question Away',
      "Don't Stop Now! Today's $cash Awaits Your Next Answer",
      'Stay in the Game — $cash Is Heating Up with Every Question',
      "Keep Answering — Today's $cash Is Just a Few Questions Away",
      'Almost There! $cash Feels Closer with Every Right Answer',
    ];
    _pendingMessage = messages[_cursor];
    notifyListeners();
  }

  void _cancelTimers() {
    _answerTimer?.cancel();
    _answerTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
