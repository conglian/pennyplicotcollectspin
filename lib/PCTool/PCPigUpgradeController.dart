import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 猪升级提示状态：升级后等待当前领奖结束，确认或稍后处理后本地记为已展示。
/// 冷启动恢复尚未处理的阶段；阶段只前进，重复刷新不重复弹出。
class PCPigUpgradeController extends ChangeNotifier {
  static final instance = PCPigUpgradeController();
  static const seenKey = 'pc_pig_upgrade_seen_level_v1';
  int _level = 0, _seen = 0, _holds = 0;
  bool _presenting = false;
  int? get pendingLevel => _level > _seen ? _level : null;
  bool get isBlocked => _holds > 0;
  bool get isPresenting => _presenting;

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    _level = (prefs.getInt('pc_pig_level') ?? 0).clamp(0, 2);
    _seen = (prefs.getInt(seenKey) ?? 0).clamp(0, 2);
    notifyListeners();
  }

  /// 领奖弹窗及到账动画期间暂缓升级展示；返回的释放函数可安全重复调用。
  VoidCallback holdPresentation() {
    _holds++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _holds--;
      notifyListeners();
    };
  }

  void setPresenting(bool value) {
    if (_presenting == value) return;
    _presenting = value;
    notifyListeners();
  }

  Future<void> acknowledge(int level) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = max(prefs.getInt(seenKey) ?? 0, level.clamp(0, 2));
    await prefs.setInt(seenKey, seen);
    _seen = seen;
    notifyListeners();
  }
}
