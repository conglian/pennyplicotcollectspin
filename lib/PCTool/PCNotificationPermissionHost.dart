import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../PCDialog/PCOther/PCPushNotificationDialog.dart';
import 'PCDialogCoordinator.dart';
import 'PCAnalytics.dart';
import 'PCNewUserGuideController.dart';
import 'PCNoticeHelp.dart';
import 'PCNotificationPermissionSession.dart';
import 'PCPigUpgradeController.dart';
import 'PCProcessFlowController.dart';
import 'PCWithdrawalController.dart';
import 'PCWithdrawalNotifications.dart';
import 'pc_extension_help.dart';

/// 通知二次召回：每次冷启动未授权时展示一次，引导与提现等已有流程优先。
/// 回前台重新查询系统权限；设置中开启后关闭自己的引导，并恢复原有通知推送计划。
class PCNotificationPermissionHost extends StatefulWidget {
  const PCNotificationPermissionHost({
    super.key,
    required this.child,
    this.canPresent,
    this.isEnabled,
    this.openSettings,
    this.refreshSchedules,
    this.waitForStartupPermission,
    this.permissionSession,
    this.isHomeVisible = true,
  });

  final Widget child;
  final bool Function()? canPresent;
  final Future<bool> Function()? isEnabled;
  final Future<void> Function()? openSettings, refreshSchedules;
  final Future<void> Function()? waitForStartupPermission;
  final PCNotificationPermissionSession? permissionSession;
  final bool isHomeVisible;

  @override
  State<PCNotificationPermissionHost> createState() =>
      _PCNotificationPermissionHostState();
}

class _PCNotificationPermissionHostState
    extends State<PCNotificationPermissionHost>
    with WidgetsBindingObserver {
  final _dialogs = PCDialogCoordinator.instance;
  Timer? _retry;
  Route<dynamic>? _route;
  bool _foreground = true, _checking = false, _checkAgain = false;
  bool _scheduled = false, _showing = false;
  bool _openingSettings = false;
  Future<void>? _startupWait;
  bool _startupWaitExpired = false;
  bool? _enabled;
  PCNotificationPermissionSession get _session =>
      widget.permissionSession ?? PCNotificationPermissionSession.current;
  bool get _shown => _session.handled;
  bool get _ready =>
      widget.isHomeVisible &&
      (widget.canPresent?.call() ??
          (PCNewUserGuideController.instance.isLoaded &&
              PCNewUserGuideController.instance.isComplete &&
              !PCWithdrawalController.instance.hasPending &&
              !PCProcessFlowController.instance.hasPending &&
              !PCPigUpgradeController.instance.isBlocked &&
              !PCPigUpgradeController.instance.isPresenting));

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _dialogs.addListener(_schedule);
    PCNewUserGuideController.instance.addListener(_guideChanged);
    PCWithdrawalController.instance.addListener(_schedule);
    PCProcessFlowController.instance.addListener(_schedule);
    PCPigUpgradeController.instance.addListener(_schedule);
    PCNoticeHelp.instance.startupPermissionChanges.addListener(_startupChanged);
    unawaited(_checkPermission());
  }

  @override
  void didUpdateWidget(covariant PCNotificationPermissionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isHomeVisible != widget.isHomeVisible) _schedule();
  }

  void _startupChanged() => unawaited(_checkPermission());

  Future<void> _waitForStartupPermission() async {
    final startup =
        (widget.waitForStartupPermission ??
        PCNoticeHelp.instance.waitForStartupPermission)();
    if (identical(startup, _startupWait) && _startupWaitExpired) return;
    _startupWait = startup;
    _startupWaitExpired = false;
    await startup.timeout(
      PCNoticeHelp.startupPermissionLimit,
      onTimeout: () {
        _startupWaitExpired = true;
        // 同一笔失联回调只等一次；回前台可立即查询真实权限，晚返回时再核对。
        unawaited(
          startup.then((_) {
            if (!mounted || !identical(_startupWait, startup)) return;
            _startupWaitExpired = false;
            unawaited(_checkPermission());
          }, onError: (Object _) {}),
        );
      },
    );
  }

  Future<void> _checkPermission() async {
    _checkAgain = true;
    if (_checking) return;
    _checking = true;
    try {
      do {
        _checkAgain = false;
        // 等启动时的系统授权结束，避免用旧的未授权状态叠加自定义引导。
        await _waitForStartupPermission();
        if (!mounted) return;
        final enabled =
            await (widget.isEnabled ?? PCWithdrawalNotifications.isEnabled)()
                .timeout(PCNoticeHelp.startupPermissionLimit);
        if (!mounted) return;
        _enabled = enabled;
        if (enabled) _session.markHandled();
        if (enabled && _route?.isCurrent == true) {
          _route!.navigator?.pop(true);
        }
        // 计划入口会复用已有任务；权限撤回时也清理旧的系统通知计划。
        await (widget.refreshSchedules ??
                PCNoticeHelp.instance.refreshSchedules)()
            .timeout(PCNoticeHelp.startupPermissionLimit);
      } while (mounted && _checkAgain);
    } catch (_) {
      // 查询或系统调度异常留待下次回前台检查，不能误认为已授权。
    } finally {
      _checking = false;
      if (mounted) _schedule();
    }
  }

  void _guideChanged() {
    // 新手流程可能刚申请过权限，不能用冷启动时的未授权状态继续弹召回。
    if (!_shown && PCNewUserGuideController.instance.isComplete) {
      unawaited(_checkPermission());
    } else {
      _schedule();
    }
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_show());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _show() async {
    _retry?.cancel();
    if (!_foreground ||
        _checking ||
        _showing ||
        _shown ||
        _enabled != false ||
        !_ready ||
        _dialogs.isBusy) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      _retry = Timer(const Duration(milliseconds: 400), _schedule);
      return;
    }
    _showing = true;
    try {
      await context.tipShow2(
        Builder(
          builder: (dialogContext) {
            _route = ModalRoute.of(dialogContext);
            return PCPushNotificationDialog(onOpen: _openSettings);
          },
        ),
        scaleContent: false,
        canPresent: () =>
            mounted && _foreground && !_shown && _enabled == false && _ready,
        onPresented: () async {
          _session.markHandled();
          PCAnalytics.event('inform_back_pop');
        },
      );
    } finally {
      _route = null;
      _showing = false;
      if (mounted) _schedule();
    }
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    _openingSettings = true;
    try {
      await (widget.openSettings ??
          () => AppSettings.openAppSettings(
            type: AppSettingsType.notification,
          ))();
      if (mounted) await _checkPermission();
    } catch (_) {
      // 系统设置暂不可用时保留可关闭的引导，不阻断页面。
    } finally {
      _openingSettings = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_checkPermission());
    } else {
      _retry?.cancel();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _dialogs.removeListener(_schedule);
    PCNewUserGuideController.instance.removeListener(_guideChanged);
    PCWithdrawalController.instance.removeListener(_schedule);
    PCProcessFlowController.instance.removeListener(_schedule);
    PCPigUpgradeController.instance.removeListener(_schedule);
    PCNoticeHelp.instance.startupPermissionChanges.removeListener(
      _startupChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
