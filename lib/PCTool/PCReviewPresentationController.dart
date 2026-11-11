import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 两种审核页共用的实际展示记录：首次完成一项，其后完成前两项。
/// 由弹窗队列的onPresented调用，排队或组件重建不增加次数。
class PCReviewPresentationController extends ValueNotifier<int> {
  PCReviewPresentationController() : super(1);

  static const storageKey = 'pc_review_checklist_presentations_v1';
  static Future<void> _pending = Future<void>.value();
  bool _recorded = false;
  bool _disposed = false;

  Future<void> recordPresentation() {
    if (_recorded) return Future<void>.value();
    _recorded = true;
    final work = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getInt(storageKey) ?? 0;
      final completedSteps = previous > 0 ? 2 : 1;
      if (!await prefs.setInt(storageKey, completedSteps)) {
        _recorded = false;
        throw StateError('Unable to save review presentation');
      }
      if (!_disposed) value = completedSteps;
    });
    _pending = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return work;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
