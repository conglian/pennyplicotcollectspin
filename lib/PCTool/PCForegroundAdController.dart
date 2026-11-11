import 'package:flutter/widgets.dart';

/// 用户真实离开后返回前台时直接请求一次插屏，缓存及失败原因交给广告管理器处理。
///
/// 调用方转发生命周期，并提供引导/路由可见性和弹窗协调器状态。没有延时、排队
/// 或自动重试，初始化、权限窗口的 inactive/resumed 不视为一次前台回流。
class PCForegroundAdController {
  PCForegroundAdController({
    required bool Function() adShowing,
    required int Function() adSessionVersion,
    required DateTime? Function() lastAdFinishedAt,
    required bool Function() canPresent,
    required Future<bool> Function(String placement) requestInterstitial,
    VoidCallback Function()? holdPresentation,
    DateTime Function()? now,
  }) : _adShowing = adShowing,
       _adSessionVersion = adSessionVersion,
       _lastAdFinishedAt = lastAdFinishedAt,
       _canPresent = canPresent,
       _requestInterstitial = requestInterstitial,
       _holdPresentation = holdPresentation,
       _now = now ?? DateTime.now;

  static const placement = 'nkmdl_launch';
  // 原生关闭回调与 Flutter 生命周期回调的顺序因 SDK 而异；只用于过滤一次回切，
  // 绝不设置计时器或在冷却结束后自动补播。
  static const _nativeReturnWindow = Duration(seconds: 1);

  final bool Function() _adShowing;
  final int Function() _adSessionVersion;
  final DateTime? Function() _lastAdFinishedAt;
  final bool Function() _canPresent;
  final Future<bool> Function(String placement) _requestInterstitial;
  final VoidCallback Function()? _holdPresentation;
  final DateTime Function() _now;
  _BackgroundVisit? _background;
  bool _requesting = false;
  bool _disposed = false;

  Future<bool> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_disposed) return false;
    if (state == AppLifecycleState.detached) {
      _background = null;
      return false;
    }
    if (state == AppLifecycleState.paused) {
      // 重复 paused 不能丢掉当时已有原生广告展示的记录。
      _background ??= _BackgroundVisit(
        startedAt: _now(),
        adSession: _adSessionVersion(),
        blocked: _requesting || _adShowing() || _recentlyFinishedAd(),
      );
      return false;
    }
    if (state != AppLifecycleState.resumed) return false;

    final visit = _background;
    _background = null; // 一次回前台只请求一次；失败不定时补播。
    if (visit == null ||
        visit.blocked ||
        _requesting ||
        _adShowing() ||
        visit.adSession != _adSessionVersion() ||
        _adFinishedDuring(visit) ||
        _recentlyFinishedAd() ||
        !_canPresent()) {
      return false;
    }

    _requesting = true;
    VoidCallback? release;
    try {
      // 不在外层检查缓存，持有展示权直到广告管理器返回真实关闭或失败。
      release = _holdPresentation?.call();
      return await _requestInterstitial(placement);
    } catch (_) {
      return false;
    } finally {
      release?.call();
      _requesting = false;
    }
  }

  bool _adFinishedDuring(_BackgroundVisit visit) {
    final finished = _lastAdFinishedAt();
    return finished != null && !finished.isBefore(visit.startedAt);
  }

  bool _recentlyFinishedAd() {
    final finished = _lastAdFinishedAt();
    if (finished == null) return false;
    final elapsed = _now().difference(finished);
    return elapsed.isNegative || elapsed <= _nativeReturnWindow;
  }

  void dispose() {
    _disposed = true;
    _background = null;
  }
}

class _BackgroundVisit {
  const _BackgroundVisit({
    required this.startedAt,
    required this.adSession,
    required this.blocked,
  });

  final DateTime startedAt;
  final int adSession;
  final bool blocked;
}
