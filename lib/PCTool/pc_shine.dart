import 'package:flutter/material.dart';

/// 沿组件自身透明轮廓掠过的高光，可设置扫光方向、时长和两次之间的停顿。
class PCShine extends StatefulWidget {
  const PCShine({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.duration = const Duration(milliseconds: 2000),
    this.pause = Duration.zero,
    this.axis = Axis.vertical,
  });

  final Widget child;
  final double? width;
  final double? height;
  final Duration duration;
  final Duration pause;
  final Axis axis;

  @override
  State<PCShine> createState() => _PCShineState();
}

class _PCShineState extends State<PCShine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsEnabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration + widget.pause,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(PCShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.pause != widget.pause) {
      _controller.duration = widget.duration + widget.pause;
      if (_animationsEnabled == true) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final activeFraction =
              widget.duration.inMicroseconds /
              (widget.duration + widget.pause).inMicroseconds;
          final phase = _controller.value / activeFraction;
          if (_animationsEnabled != true || phase >= 1) return child!;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final horizontal = widget.axis == Axis.horizontal;
              final extent = horizontal ? bounds.width : bounds.height;
              final band = extent * .55;
              final offset = -band + (extent + 2 * band) * phase;
              return const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Color(0x18FFFFFF),
                  Color(0xD9FFFFFF),
                  Color(0x18FFFFFF),
                  Colors.transparent,
                ],
                stops: [0, .38, .5, .62, 1],
              ).createShader(
                horizontal
                    ? Rect.fromLTWH(offset, 0, band, bounds.height)
                    : Rect.fromLTWH(0, offset, bounds.width, band),
              );
            },
            child: child,
          );
        },
      ),
    ),
  );
}
