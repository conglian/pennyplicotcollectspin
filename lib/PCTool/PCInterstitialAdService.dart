import 'PCAdOutcome.dart';

export 'PCAdOutcome.dart';

/// 插屏展示入口；与激励结果分开，关闭奖励框时只影响广告展示，不参与发奖。
class PCInterstitialAdService {
  static final instance = PCInterstitialAdService();
  Future<bool> Function(String placement)? _handler;
  Future<bool> Function(String placement)? _cachedHandler;
  Future<PCAdOutcome> Function(String placement)? _outcomeHandler;
  Future<PCAdOutcome> Function(String placement)? _cachedOutcomeHandler;

  Future<bool> Function(String placement)? get handler => _handler;
  set handler(Future<bool> Function(String placement)? value) {
    _handler = value;
    _outcomeHandler = null;
  }

  Future<bool> Function(String placement)? get cachedHandler => _cachedHandler;
  set cachedHandler(Future<bool> Function(String placement)? value) {
    _cachedHandler = value;
    _cachedOutcomeHandler = null;
  }

  void bindOutcomeHandler(
    Future<PCAdOutcome> Function(String placement) value,
  ) {
    _outcomeHandler = value;
    _handler = (placement) async => (await value(placement)).isSuccess;
  }

  void bindCachedOutcomeHandler(
    Future<PCAdOutcome> Function(String placement) value,
  ) {
    _cachedOutcomeHandler = value;
    _cachedHandler = (placement) async => (await value(placement)).isSuccess;
  }

  Future<bool> request(String placement) async =>
      (await requestOutcome(placement)).isSuccess;

  Future<PCAdOutcome> requestOutcome(String placement) =>
      _requestOutcome(placement, cachedOnly: false);

  /// 显式只用缓存的调用；冷启动和回前台使用正常request，由管理器报告无缓存原因。
  Future<bool> requestCached(String placement) async =>
      (await requestCachedOutcome(placement)).isSuccess;

  Future<PCAdOutcome> requestCachedOutcome(String placement) =>
      _requestOutcome(placement, cachedOnly: true);

  Future<PCAdOutcome> _requestOutcome(
    String placement, {
    required bool cachedOnly,
  }) async {
    try {
      final typed = cachedOnly ? _cachedOutcomeHandler : _outcomeHandler;
      if (typed != null) return await typed(placement);
      final legacy = cachedOnly ? _cachedHandler : _handler;
      return await legacy?.call(placement) == true
          ? PCAdOutcome.success
          : PCAdOutcome.failed;
    } catch (_) {
      return PCAdOutcome.failed;
    }
  }
}
