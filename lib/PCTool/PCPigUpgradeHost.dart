import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../PCDialog/PCCash/PCDiamondPigUpgradeDialog.dart';
import '../PCDialog/PCCash/PCGoldPigUpgradeDialog.dart';
import 'PCNewUserGuideController.dart';
import 'PCNumberManager.dart';
import 'PCPigUpgradeController.dart';
import 'pc_LocalProvider.dart';
import 'pc_extension_help.dart';

/// 全局升级弹窗入口：等待新用户流程、当前弹窗及领奖到账动画结束后展示。
/// 仅前台弹出，后台或冷启动保留待提示阶段；按钮关闭后持久化，不重复展示。
class PCPigUpgradeHost extends StatefulWidget {
  const PCPigUpgradeHost({
    super.key,
    required this.child,
    this.controller,
    this.onContinue,
    this.canPresent,
  });
  final Widget child;
  final PCPigUpgradeController? controller;
  final VoidCallback? onContinue;
  final bool Function()? canPresent;
  @override
  State<PCPigUpgradeHost> createState() => _PCPigUpgradeHostState();
}

class _PCPigUpgradeHostState extends State<PCPigUpgradeHost>
    with WidgetsBindingObserver {
  PCPigUpgradeController get _controller =>
      widget.controller ?? PCPigUpgradeController.instance;
  Timer? _retry;
  bool _open = false, _scheduled = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_schedule);
    PCNewUserGuideController.instance.addListener(_schedule);
    unawaited(_controller.refresh());
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
    final level = _controller.pendingLevel;
    if (level == null ||
        _open ||
        !_foreground ||
        _controller.isBlocked ||
        !(widget.canPresent?.call() ??
            PCNewUserGuideController.instance.isComplete)) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      _retry = Timer(const Duration(milliseconds: 400), _schedule);
      return;
    }
    _open = true;
    _controller.setPresenting(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final provider = PCLocalProvider.instance;
      final amount = PCNumberHelpers().pc_firstTarget;
      final paymentAsset =
          'pc_act_${provider.pc_account_seled_index.clamp(0, 3)}';
      final date =
          DateTime.tryParse(
            prefs.getString('pc_pig_upgrade_date_$level') ?? '',
          ) ??
          DateTime.now();
      final proceed = await context.tipShow2(
        level == 1
            ? PCDiamondPigUpgradeDialog(
                amount: amount,
                account: provider.pc_account_id,
                paymentAsset: paymentAsset,
              )
            : PCGoldPigUpgradeDialog(
                amount: amount,
                account: provider.pc_account_id,
                paymentAsset: paymentAsset,
                date: date,
                gold: prefs.getDouble('pc_quiz_gold') ?? 0,
              ),
        bc: Colors.black.withValues(alpha: .9),
        scaleContent: false,
      );
      if (!mounted) return;
      await _controller.acknowledge(level);
      if (mounted && proceed == true) widget.onContinue?.call();
    } finally {
      _open = false;
      _controller.setPresenting(false);
      if (mounted) _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_controller.refresh());
    } else {
      _retry?.cancel();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _controller.removeListener(_schedule);
    PCNewUserGuideController.instance.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
