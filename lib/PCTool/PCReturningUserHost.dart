import 'dart:async';

import 'package:flutter/material.dart';

import '../PCDialog/PCOther/PCGrowBonusDialog.dart';
import 'PCNewUserGuideController.dart';
import 'PCPigUpgradeController.dart';
import 'PCReturningUserController.dart';
import 'PCAnalytics.dart';
import 'pc_LocalProvider.dart';
import 'pc_extension_help.dart';

/// 老用户回访弹窗入口：冷启动及隔天回前台检查，当天只显示一次。
/// 等待新用户流程和已有路由结束，展示期间暂缓猪升级提示。
class PCReturningUserHost extends StatefulWidget {
  const PCReturningUserHost({
    super.key,
    required this.controller,
    required this.child,
    required this.onGoEarn,
    this.canPresent,
  });
  final PCReturningUserController controller;
  final Widget child;
  final VoidCallback onGoEarn;
  final bool Function()? canPresent;

  @override
  State<PCReturningUserHost> createState() => _PCReturningUserHostState();
}

class _PCReturningUserHostState extends State<PCReturningUserHost>
    with WidgetsBindingObserver {
  Timer? _retry;
  VoidCallback? _releaseUpgrade;
  bool _open = false, _scheduled = false, _checking = false;
  bool _foreground = true;
  String? _attemptedDay;
  bool get _canPresent =>
      widget.canPresent?.call() ?? PCNewUserGuideController.instance.isComplete;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller.isPending) _holdUpgrade();
    _schedule();
  }

  void _holdUpgrade() {
    _releaseUpgrade ??= PCPigUpgradeController.instance.holdPresentation();
  }

  void _release() {
    _releaseUpgrade?.call();
    _releaseUpgrade = null;
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
    if (_open || _checking || !_foreground) return;
    if (!widget.controller.isPending ||
        !_canPresent ||
        _attemptedDay == widget.controller.today) {
      _release();
      return;
    }
    _holdUpgrade();
    if (ModalRoute.of(context)?.isCurrent != true) {
      _retry = Timer(const Duration(milliseconds: 400), _schedule);
      return;
    }
    _open = true;
    _attemptedDay = widget.controller.today;
    try {
      final guide = PCNewUserGuideController.instance;
      final closed = context.tipShow2(
        PCGrowBonusDialog(
          savedAmount: PCLocalProvider.instance.pc_dollar_number,
          growPercent: guide.config.growPercent,
        ),
        bc: Colors.black.withValues(alpha: .9),
        scaleContent: false,
        onPresented: () async =>
            PCAnalytics.event('grow_bonus_pop', {'pop_from': 'old'}),
      );
      try {
        await widget.controller.markShown();
      } catch (_) {
        // 写入失败时本会话不重复弹出，未处理记录留待下次冷启动重试。
      }
      final proceed = await closed;
      if (mounted && proceed == true) {
        PCAnalytics.event('grow_bonus_pop_c', {'pop_from': 'old'});
        widget.onGoEarn();
      }
    } finally {
      _open = false;
      _release();
    }
  }

  Future<void> _checkResume() async {
    if (_checking || _open) return;
    _checking = true;
    _holdUpgrade();
    try {
      await widget.controller.prepareLaunch(isExistingUser: _canPresent);
    } catch (_) {
      // 临时存储错误不阻断页面，下次进入前台再检查。
    } finally {
      _checking = false;
      if (mounted) {
        if (!widget.controller.isPending) _release();
        _schedule();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_checkResume());
    } else {
      _retry?.cancel();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _release();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
