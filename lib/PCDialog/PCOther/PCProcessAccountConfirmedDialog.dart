import '../../PCTool/PCAnalytics.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/PCProcessBannerArtwork.dart';

/// 3.7收款信息确认横幅（Payout Details Confirmed，Figma 211:757）。
/// 共用倾斜红色横幅，从左屏外滑至中心、完整停留2秒，再原路退场并关闭一次。
/// [displayDuration] 供预览调整停留时长；默认不改变业务流程。
class PCProcessAccountConfirmedDialog extends StatefulWidget {
  const PCProcessAccountConfirmedDialog({
    super.key,
    required this.withdrawalTarget,
    this.displayDuration = const Duration(seconds: 2),
  });
  final double withdrawalTarget;
  final Duration displayDuration;

  @override
  State<PCProcessAccountConfirmedDialog> createState() =>
      _PCProcessAccountConfirmedDialogState();
}

class _PCProcessAccountConfirmedDialogState
    extends State<PCProcessAccountConfirmedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Timer? _timer;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    if (!mounted || _started) return;
    _started = true;
    PCAnalytics.event('confirm_account_toast');
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _motion.value = 1;
    } else {
      try {
        await _motion.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    // 完整入场后再开始停留计时，侧向运动不占用这2秒。
    _timer = Timer(widget.displayDuration, () async {
      if (!mounted || _finished) return;
      if (!reduced) {
        try {
          await _motion.reverse().orCancel;
        } on TickerCanceled {
          return;
        }
      }
      _closeOnce();
    });
  }

  void _closeOnce() {
    if (!mounted || _finished) return;
    _finished = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      // 外部导航插入了其他路由时只结束自己的横幅，不能误关上面的页面。
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _finished = true;
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heightLimitedWidth = constraints.maxHeight * 360 / 332;
        final width = math.min(
          math.min(constraints.maxWidth, 460.0),
          heightLimitedWidth,
        );
        final height = width * 332 / 360;
        return Center(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (_, child) => Transform.translate(
              key: const ValueKey('pcProcessAccountConfirmedSlide'),
              offset: Offset(
                -(constraints.maxWidth + width) *
                    (1 - Curves.easeInOutCubic.transform(_motion.value)),
                0,
              ),
              child: child,
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: PCProcessBannerArtwork.accountConfirmed(
                withdrawalTarget: widget.withdrawalTarget,
              ),
            ),
          ),
        );
      },
    ),
  );
}
