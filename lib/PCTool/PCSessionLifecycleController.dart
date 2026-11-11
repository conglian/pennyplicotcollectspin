import 'package:flutter/widgets.dart';

/// 冷启动、进入后台及返回前台分别记录session，与广告缓存和业务回调分开。
class PCSessionLifecycleController {
  PCSessionLifecycleController({
    required this.isNativeAdShowing,
    required this.onSession,
  });

  final bool Function() isNativeAdShowing;
  final void Function(String source) onSession;
  bool _started = false;
  bool _backgrounded = false;
  bool _backgroundWasNativeAd = false;

  void start() {
    if (_started) return;
    _started = true;
    onSession('cold_start');
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _backgrounded = false;
      _backgroundWasNativeAd = false;
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (!_backgrounded) {
        // 仅记录离开时已有的原生广告。返回后新开的回流插屏不能吞掉session。
        _backgroundWasNativeAd = isNativeAdShowing();
        _backgrounded = true;
        if (!_backgroundWasNativeAd) onSession('background_enter');
      }
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      final wasNativeAd = _backgroundWasNativeAd;
      _backgroundWasNativeAd = false;
      if (!wasNativeAd) onSession('foreground_return');
    }
  }
}
