import 'PCAdOutcome.dart';

export 'PCAdOutcome.dart';

/// 激励广告结果入口；仅真实激励成功可领奖，正常取消和播放失败分别返回。
class PCRewardedAdService {
  static final instance = PCRewardedAdService();
  Future<bool> Function(String placement)? _handler;
  Future<PCAdOutcome> Function(String placement)? _outcomeHandler;

  Future<bool> Function(String placement)? get handler => _handler;
  set handler(Future<bool> Function(String placement)? value) {
    _handler = value;
    _outcomeHandler = null;
  }

  void bindOutcomeHandler(
    Future<PCAdOutcome> Function(String placement) value,
  ) {
    _outcomeHandler = value;
    _handler = (placement) async => (await value(placement)).isSuccess;
  }

  Future<bool> request(String placement) async =>
      (await requestOutcome(placement)).isSuccess;

  Future<PCAdOutcome> requestOutcome(String placement) async {
    try {
      final typed = _outcomeHandler;
      if (typed != null) return await typed(placement);
      return await _handler?.call(placement) == true
          ? PCAdOutcome.success
          : PCAdOutcome.failed;
    } catch (_) {
      return PCAdOutcome.failed;
    }
  }
}
