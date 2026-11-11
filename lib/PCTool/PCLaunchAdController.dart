import 'dart:async';

/// 冷启动广告门禁：启动时快照完整新用户进度，加载结束后最多尝试一次插屏。
///
/// 不在外层判断缓存，符合开屏条件即调用展示并由管理器记录chance和失败原因。
/// 通常等待广告关闭；本地读取、权限或SDK遗漏回调时有界退让，不能把用户留在100%。
/// 兜底只释放启动页自己的展示权，不关闭原生广告、不抢占广告管理器owner。
class PCLaunchAdController {
  PCLaunchAdController({
    required Future<bool> Function() loadGuideComplete,
    required Future<bool> Function(String placement) requestInterstitial,
    required Future<void> Function() continueToApp,
    required bool Function() canContinue,
    Future<void> Function()? waitForStartupPermission,
    Future<void> Function()? prepareApp,
    void Function() Function()? holdPresentation,
    bool Function()? isNativeAdShowing,
    bool Function()? canRequestInterstitial,
    void Function(String phase)? onWaitTimeout,
    Duration dependencyWait = defaultDependencyWait,
    Duration metadataWait = defaultMetadataWait,
    Duration interstitialWait = defaultInterstitialWait,
    Duration nativeInterstitialWait = defaultNativeInterstitialWait,
  }) : _requestInterstitial = requestInterstitial,
       _continueToApp = continueToApp,
       _canContinue = canContinue,
       _waitForStartupPermission = waitForStartupPermission,
       _prepareApp = prepareApp,
       _holdPresentation = holdPresentation,
       _isNativeAdShowing = isNativeAdShowing,
       _canRequestInterstitial = canRequestInterstitial,
       _onWaitTimeout = onWaitTimeout,
       _dependencyWait = dependencyWait,
       _metadataWait = metadataWait,
       _interstitialWait = interstitialWait,
       _nativeInterstitialWait = nativeInterstitialWait {
    // 在构造时开始读取，不能在新用户流程结束后再重新判断。
    _eligibleAtLaunch = _readEligibility(loadGuideComplete);
  }

  static const placement = 'nkmdl_launch';
  static const defaultDependencyWait = Duration(seconds: 8);
  static const defaultMetadataWait = Duration(seconds: 2);
  static const defaultInterstitialWait = Duration(seconds: 8);
  static const defaultNativeInterstitialWait = Duration(seconds: 120);

  late final Future<bool> _eligibleAtLaunch;
  final Future<bool> Function(String placement) _requestInterstitial;
  final Future<void> Function() _continueToApp;
  final bool Function() _canContinue;
  final Future<void> Function()? _waitForStartupPermission;
  final Future<void> Function()? _prepareApp;
  final void Function() Function()? _holdPresentation;
  final bool Function()? _isNativeAdShowing;
  final bool Function()? _canRequestInterstitial;
  final void Function(String phase)? _onWaitTimeout;
  final Duration _dependencyWait, _metadataWait;
  final Duration _interstitialWait, _nativeInterstitialWait;
  final Set<void Function()> _cancelWaits = {};
  Future<void>? _finishing;
  bool _disposed = false;

  Future<bool> _readEligibility(Future<bool> Function() load) async {
    // 状态不明确时保护新用户，不把安装标记当作引导完成，也不等缓存插件无限回调。
    return _bounded(
      Future<bool>.sync(load),
      timeout: _dependencyWait,
      fallback: false,
      phase: 'guide_state',
    );
  }

  /// 由启动进度完成触发；重建或重复回调共用同一流程，不再次请求或导航。
  Future<void> finish() => _finishing ??= _finish();

  Future<void> _finish() async {
    final eligible = await _eligibleAtLaunch;
    if (!_mayContinue) return;
    // 系统调用抛错已经结束等待；只有仍未返回的超时才跳过本次广告，避免压住权限窗口。
    final permissionSettled = await _bounded(
      Future<void>.sync(
        () => _waitForStartupPermission?.call(),
      ).then((_) => true, onError: (Object _, StackTrace _) => true),
      timeout: _dependencyWait,
      fallback: false,
      phase: 'notification_permission',
    );
    if (!_mayContinue) return;
    if (eligible && permissionSettled && _mayRequestInterstitial) {
      void Function()? release;
      try {
        release = _holdPresentation?.call();
        await _waitForInterstitial();
      } catch (_) {
        // 开屏失败只继续首页，不显示普通业务的广告失败面板。
      } finally {
        release?.call();
      }
    }
    if (!_mayContinue) return;
    if (_prepareApp != null) {
      await _bounded(
        Future<void>.sync(_prepareApp).then((_) => true),
        timeout: _metadataWait,
        fallback: false,
        phase: 'launch_metadata',
      );
    }
    if (_mayContinue) await _continueToApp();
  }

  Future<T> _bounded<T>(
    Future<T> operation, {
    required Duration timeout,
    required T fallback,
    required String phase,
  }) {
    final result = Completer<T>();
    Timer? timer;
    late void Function() cancel;
    void finish(T value) {
      if (result.isCompleted) return;
      timer?.cancel();
      _cancelWaits.remove(cancel);
      result.complete(value);
    }

    cancel = () => finish(fallback);
    if (_disposed) {
      finish(fallback);
    } else {
      _cancelWaits.add(cancel);
      timer = Timer(timeout, () {
        _reportTimeout(phase);
        finish(fallback);
      });
    }
    // 即使先超时，仍消费迟到的异常；迟到结果不能再次完成或重新触发启动流程。
    operation.then(
      finish,
      onError: (Object _, StackTrace _) => finish(fallback),
    );
    return result.future;
  }

  bool get _nativeShowing {
    try {
      return _isNativeAdShowing?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get _mayRequestInterstitial {
    try {
      return _canRequestInterstitial?.call() ?? true;
    } catch (_) {
      return false;
    }
  }

  void _reportTimeout(String phase) {
    try {
      _onWaitTimeout?.call(phase);
    } catch (_) {
      // 诊断日志失败不能阻断启动兜底。
    }
  }

  Future<void> _waitForInterstitial() {
    final done = Completer<void>();
    Timer? callbackTimer, nativeLimit, poll;
    late void Function() finish;
    finish = () {
      if (done.isCompleted) return;
      callbackTimer?.cancel();
      nativeLimit?.cancel();
      poll?.cancel();
      _cancelWaits.remove(finish);
      done.complete();
    };
    _cancelWaits.add(finish);
    callbackTimer = Timer(_interstitialWait, () {
      if (!_nativeShowing) {
        _reportTimeout('interstitial_callback');
        finish();
        return;
      }
      // 原生已接管时继续等关闭；SDK先清展示标志但漏业务Future也可正常离开。
      poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!_nativeShowing) finish();
      });
    });
    nativeLimit = Timer(_nativeInterstitialWait, () {
      _reportTimeout('native_interstitial_callback');
      // SDK状态卡死时只更换Flutter底页，不修改/清除任何SDK owner或强行关闭广告。
      finish();
    });
    Future<bool>.sync(
      () => _requestInterstitial(placement),
    ).then((_) => finish(), onError: (Object _, StackTrace _) => finish());
    return done.future;
  }

  bool get _mayContinue => !_disposed && _canContinue();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final cancel in _cancelWaits.toList()) {
      cancel();
    }
  }
}
