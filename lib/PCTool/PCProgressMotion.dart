import 'package:flutter/widgets.dart';

/// 进度从起始值缓慢填充，更新时从当前显示的位置继续过渡。
class PCProgressMotion extends StatelessWidget {
  const PCProgressMotion({
    super.key,
    required this.value,
    required this.builder,
    this.initialValue = 0,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeInOutCubic,
    this.child,
  });

  final double value;
  final double initialValue;
  final Duration duration;
  final Curve curve;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = value.isFinite ? value : 0.0;
    if (duration == Duration.zero || MediaQuery.disableAnimationsOf(context)) {
      return builder(context, target, child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: initialValue, end: target),
      duration: duration,
      curve: curve,
      builder: builder,
      child: child,
    );
  }
}
