import 'dart:async';

import 'package:flutter/material.dart';

import 'PCDialogCoordinator.dart';
import 'PCAnalytics.dart';
import 'PCNewUserGuideController.dart';
import 'PCNoticeHelp.dart';
import 'PCNoticeMessage.dart';
import 'PCNotificationCard.dart';
import 'PCNumberManager.dart';
import 'PCProcessFlowController.dart';
import 'PCWithdrawalController.dart';
import 'PCSocialPayoutCard.dart';
import 'PCAdaptiveLayout.dart';
import 'PCSocialPayoutController.dart';
import 'PCSocialPayoutNotice.dart';
import 'pc_LocalProvider.dart';

/// App内通知唯一展示位：原余额提醒优先于3.7社交播报，8秒后收起。
/// 与其他提示共享展示权；用户操作页面时立即让出，不吞掉本次点击。
class PCInAppNotificationHost extends StatefulWidget {
  const PCInAppNotificationHost({
    super.key,
    required this.child,
    this.notifier,
    this.onAction,
    this.socialController,
    this.coordinator,
    this.enableSocialNotices = true,
    this.socialReady,
    this.socialProgress,
    this.onSocialAction,
    this.processFlow,
  });
  final Widget child;
  final ValueNotifier<PCNoticeMessage?>? notifier;
  final ValueChanged<PCNoticeMessage>? onAction;
  final PCSocialPayoutController? socialController;
  final PCDialogCoordinator? coordinator;
  final bool enableSocialNotices;

  /// 预览与测试可注入，生产等待新用户引导和首页导航均就绪。
  final bool Function()? socialReady;
  final double Function()? socialProgress;
  final VoidCallback? onSocialAction;
  final PCProcessFlowController? processFlow;

  @override
  State<PCInAppNotificationHost> createState() =>
      _PCInAppNotificationHostState();
}

class _PCInAppNotificationHostState extends State<PCInAppNotificationHost>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _dismissTimer;
  Timer? _socialPriorityTimer;
  late AnimationController _animation;
  PCSocialPayoutController? _social;
  bool _ownsSocial = false;
  Object? _visible;
  VoidCallback? _releasePresentation;
  bool _exiting = false;
  bool _syncScheduled = false;
  bool _foreground = true;
  double _dragDistance = 0;
  ValueNotifier<PCNoticeMessage?> get _notifier =>
      widget.notifier ?? PCNoticeHelp.instance.banner;
  PCDialogCoordinator get _coordinator =>
      widget.coordinator ?? PCDialogCoordinator.instance;

  PCProcessFlowController get _process =>
      widget.processFlow ?? PCProcessFlowController.instance;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _notifier.addListener(_changed);
    _coordinator.addListener(_changed);
    _process.addListener(_changed);
    PCWithdrawalController.instance.addListener(_changed);
    PCNewUserGuideController.instance.addListener(_environmentChanged);
    PCLocalProvider.instance.addListener(_environmentChanged);
    PCNoticeHelp.instance.navigationReady.addListener(_environmentChanged);
    _attachSocial();
    _changed();
  }

  void _attachSocial() {
    if (!widget.enableSocialNotices) return;
    _ownsSocial = widget.socialController == null;
    _social = widget.socialController ?? PCSocialPayoutController();
    _social!.addListener(_changed);
    _environmentChanged();
    unawaited(
      _social!.load().then((_) {
        if (mounted) _environmentChanged();
      }),
    );
  }

  void _detachSocial() {
    _social?.removeListener(_changed);
    _social?.setEnvironment(
      foreground: false,
      guideComplete: false,
      progress: 0,
    );
    if (_ownsSocial) _social?.dispose();
    _social = null;
  }

  @override
  void didUpdateWidget(covariant PCInAppNotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier = oldWidget.notifier ?? PCNoticeHelp.instance.banner;
    if (oldNotifier != _notifier) {
      oldNotifier.removeListener(_changed);
      _notifier.addListener(_changed);
    }
    final oldCoordinator =
        oldWidget.coordinator ?? PCDialogCoordinator.instance;
    if (oldCoordinator != _coordinator) {
      oldCoordinator.removeListener(_changed);
      _coordinator.addListener(_changed);
    }
    if (oldWidget.socialController != widget.socialController ||
        oldWidget.enableSocialNotices != widget.enableSocialNotices) {
      if (_visible is PCSocialPayoutNotice) unawaited(_dismiss());
      _detachSocial();
      _attachSocial();
    }
    final oldProcess =
        oldWidget.processFlow ?? PCProcessFlowController.instance;
    if (oldProcess != _process) {
      oldProcess.removeListener(_changed);
      _process.addListener(_changed);
    }
    _environmentChanged();
  }

  void _environmentChanged() {
    _social?.setEnvironment(
      foreground: _foreground,
      guideComplete:
          widget.socialReady?.call() ??
          (PCNewUserGuideController.instance.isComplete &&
              PCNoticeHelp.instance.navigationReady.value),
      progress:
          widget.socialProgress?.call() ??
          PCLocalProvider.instance.pc_dollar_number /
              PCNumberHelpers().pc_firstTarget,
    );
    _changed();
  }

  bool get _otherPresentation =>
      _coordinator.isPresenting ||
      _coordinator.pendingCount > 0 ||
      _coordinator.holdCount > (_releasePresentation == null ? 0 : 1);

  void _changed() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    scheduleMicrotask(() {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  void _sync() {
    if (_exiting) return;
    if (_visible != null) {
      final social = _visible is PCSocialPayoutNotice;
      final noLongerReady =
          social &&
          !(widget.socialReady?.call() ??
              (PCNewUserGuideController.instance.isComplete &&
                  PCNoticeHelp.instance.navigationReady.value));
      if (!_foreground ||
          _otherPresentation ||
          PCWithdrawalController.instance.hasPending ||
          noLongerReady ||
          (social && (_notifier.value != null || _process.hasPending))) {
        unawaited(_dismiss(consumeAccount: false));
      } else if (_visible is PCNoticeMessage && _notifier.value == null) {
        unawaited(_dismiss());
      } else if (_visible is PCNoticeMessage &&
          !identical(_visible, _notifier.value)) {
        setState(() => _visible = _notifier.value);
      }
      return;
    }
    if (!_foreground ||
        _coordinator.isBusy ||
        PCWithdrawalController.instance.hasPending) {
      _socialPriorityTimer?.cancel();
      _socialPriorityTimer = null;
      return;
    }
    final account = _notifier.value;
    if (account != null) {
      _present(account);
      return;
    }
    if (_social?.pending != null && !_process.hasPending) {
      // 社交播报优先级最低，留出业务弹窗及答题横幅请求展示权的时机。
      _socialPriorityTimer ??= Timer(const Duration(milliseconds: 150), () {
        _socialPriorityTimer = null;
        if (!mounted ||
            _visible != null ||
            !_foreground ||
            _coordinator.isBusy ||
            _notifier.value != null ||
            _process.hasPending) {
          return;
        }
        final notice = _social?.beginPresentation();
        if (notice != null) _present(notice);
      });
    }
  }

  void _present(Object message) {
    if (!mounted || _coordinator.isBusy) return;
    _releasePresentation = _coordinator.holdPresentation();
    setState(() => _visible = message);
    PCAnalytics.event('push_appin_p');
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _animation.value = 1;
    } else {
      unawaited(_animation.forward(from: 0));
    }
    _dismissTimer?.cancel();
    _dismissTimer = Timer(
      const Duration(seconds: 8),
      () => unawaited(_dismiss()),
    );
  }

  Future<void> _dismiss({
    bool consumeAccount = true,
    VoidCallback? after,
    bool immediate = false,
  }) async {
    if ((_exiting && !immediate) || _visible == null) return;
    _exiting = true;
    _dismissTimer?.cancel();
    final previous = _visible;
    final previousSocial = previous is PCSocialPayoutNotice ? _social : null;
    if (consumeAccount &&
        previous is PCNoticeMessage &&
        identical(_notifier.value, previous)) {
      _notifier.value = null;
    }
    if (immediate) {
      _animation.stop();
      _animation.value = 0;
    } else if (mounted &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      try {
        await _animation.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    } else {
      _animation.value = 0;
    }
    if (!mounted || !identical(_visible, previous)) return;
    setState(() {
      _visible = null;
      _exiting = false;
    });
    previousSocial?.finishPresentation();
    final release = _releasePresentation;
    _releasePresentation = null;
    release?.call();
    after?.call();
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _environmentChanged();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissTimer?.cancel();
    _socialPriorityTimer?.cancel();
    _notifier.removeListener(_changed);
    _coordinator.removeListener(_changed);
    _process.removeListener(_changed);
    PCWithdrawalController.instance.removeListener(_changed);
    PCNewUserGuideController.instance.removeListener(_environmentChanged);
    PCLocalProvider.instance.removeListener(_environmentChanged);
    PCNoticeHelp.instance.navigationReady.removeListener(_environmentChanged);
    if (_visible is PCSocialPayoutNotice) _social?.finishPresentation();
    _detachSocial();
    _animation.dispose();
    _releasePresentation?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          // 在业务按钮的 onTap 前同步释放展示权，首次点击即可正常执行。
          onPointerDown: (_) => unawaited(_dismiss(immediate: true)),
          child: widget.child,
        ),
        if (visible != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 328 * PCAdaptiveLayout.maxCanvasScale + 32,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SlideTransition(
                      position:
                          Tween(
                            begin: const Offset(0, -1.15),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animation,
                              curve: Curves.easeOutCubic,
                              reverseCurve: Curves.easeInCubic,
                            ),
                          ),
                      child: IgnorePointer(
                        ignoring: _exiting,
                        child: GestureDetector(
                          key: ValueKey(
                            visible is PCSocialPayoutNotice
                                ? 'pcSocialInAppNotice'
                                : 'pcInAppNotice',
                          ),
                          onVerticalDragStart: (_) => _dragDistance = 0,
                          onVerticalDragUpdate: (details) =>
                              _dragDistance += details.delta.dy,
                          onVerticalDragEnd: (details) {
                            if (_dragDistance < -32 ||
                                (details.primaryVelocity ?? 0) < -100) {
                              unawaited(_dismiss());
                            }
                          },
                          child: visible is PCSocialPayoutNotice
                              ? PCSocialPayoutCard(
                                  notice: visible,
                                  onAction: () => unawaited(
                                    _dismiss(
                                      after: () =>
                                          (widget.onSocialAction ??
                                          () =>
                                              PCNoticeHelp.instance.openAction(
                                                PCNoticeAction.withdraw,
                                              ))(),
                                    ),
                                  ),
                                )
                              : PCNotificationCard(
                                  message: visible as PCNoticeMessage,
                                  inApp: true,
                                  onDismiss: () => unawaited(_dismiss()),
                                  onAction: () {
                                    _notifier.value = null;
                                    unawaited(
                                      _dismiss(
                                        after: () =>
                                            (widget.onAction ??
                                            PCNoticeHelp.instance.open)(
                                              visible,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
