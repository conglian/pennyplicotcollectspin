import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/PCProcessBannerArtwork.dart';

/// 提现通道激活横幅（Withdrawal Boost Access Unlocked，Figma 225:542）。
/// 从左侧进入，完整停留后原路退出并返回true；不修改提现或奖励状态。
class PCWithdrawalChannelActivatedDialog extends StatefulWidget {
  const PCWithdrawalChannelActivatedDialog({
    super.key,
    required this.withdrawalTarget,
    this.displayDuration = const Duration(seconds: 2),
  });
  final double withdrawalTarget;
  final Duration displayDuration;

  @override
  State<PCWithdrawalChannelActivatedDialog> createState() =>
      _PCWithdrawalChannelActivatedDialogState();
}

class _PCWithdrawalChannelActivatedDialogState
    extends State<PCWithdrawalChannelActivatedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    if (!mounted) return;
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
    _timer = Timer(widget.displayDuration, () async {
      if (!mounted || _finished) return;
      if (!reduced) {
        try {
          await _motion.reverse().orCancel;
        } on TickerCanceled {
          return;
        }
      }
      if (!mounted || _finished) return;
      _finished = true;
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true) Navigator.of(context).pop(true);
    });
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
        final width = math.min(
          math.min(constraints.maxWidth, 460.0),
          constraints.maxHeight * 360 / 332,
        );
        return Center(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (_, child) => Transform.translate(
              key: const ValueKey('pcWithdrawalChannelSlide'),
              offset: Offset(
                -(constraints.maxWidth + width) *
                    (1 - Curves.easeInOutCubic.transform(_motion.value)),
                0,
              ),
              child: child,
            ),
            child: SizedBox(
              width: width,
              height: width * 332 / 360,
              child: const PCProcessBannerArtwork.channelActivated(),
            ),
          ),
        );
      },
    ),
  );
}
