import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 领奖按钮的呼吸：围绕视觉中心在0.94至1.06倍之间平滑放大缩小，不上下移动。
/// 原点击框和业务防重保持不变；禁用、离开可见页或减少动画时恢复原尺寸。
class PCBreathing extends StatefulWidget {
  const PCBreathing({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PCBreathing> createState() => _PCBreathingState();
}

class _PCBreathingState extends State<PCBreathing>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  void _sync() {
    if (widget.enabled &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PCBreathing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final scale = 1 + math.sin(_controller.value * math.pi * 2) * .06;
      return Transform.scale(
        scale: scale,
        transformHitTests: false,
        child: child,
      );
    },
  );
}
