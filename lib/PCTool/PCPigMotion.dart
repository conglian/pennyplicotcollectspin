import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 小猪通用动效：蓄力、小跳、落地回弹，再配合呼吸和轻微摇摆。
///
/// 只变换独立小猪素材，脚底阴影留在原位；系统要求减少动画时保持静止。
class PCPigMotion extends StatefulWidget {
  const PCPigMotion({
    super.key,
    required this.child,
    this.jumpHeight = 24,
    this.showShadow = true,
  }) : progress = null,
       assert(jumpHeight > 0);

  /// 首页和弹窗主猪统一使用金猪升级页的轻跳、呼吸与漂浮节奏。
  /// 已有位移动画的素材不重复叠加；到账时可用弹窗进度播放单轮。
  const PCPigMotion.hero({super.key, required this.child, this.progress})
    : jumpHeight = 6,
      showShadow = false;

  final Widget child;
  final double jumpHeight;
  final bool showShadow;
  final Animation<double>? progress;

  @override
  State<PCPigMotion> createState() => _PCPigMotionState();
}

class _PCPigMotionState extends State<PCPigMotion>
    with SingleTickerProviderStateMixin {
  // 前36%完成一次带回弹的小跳，余下时间呼吸、摇摆，让节奏有停顿。
  static const _weights = [5.0, 8.0, 8.0, 4.0, 5.0, 6.0, 64.0];
  static const _curves = [
    Curves.easeInOutSine,
    Curves.easeOutCubic,
    Curves.easeInCubic,
    Curves.easeOutQuad,
    Curves.easeInQuad,
    Curves.easeOutCubic,
    Curves.linear,
  ];
  static final _height = _keyframes([0, 3, -24, 1, -8, 0, 0, 0]);
  static final _widthScale = _keyframes([1, 1.07, .96, 1.09, .98, 1.04, 1, 1]);
  static final _heightScale = _keyframes([1, .92, 1.07, .90, 1.04, .97, 1, 1]);
  static final _rotation = _keyframes([
    0,
    -.045,
    .075,
    -.028,
    .035,
    -.012,
    0,
    0,
  ]);

  late final AnimationController _controller;
  bool? _animationsEnabled;

  static TweenSequence<double> _keyframes(List<double> values) =>
      TweenSequence([
        for (var i = 0; i < _weights.length; i++)
          TweenSequenceItem(
            tween: Tween(
              begin: values[i],
              end: values[i + 1],
            ).chain(CurveTween(curve: _curves[i])),
            weight: _weights[i],
          ),
      ]);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLoop();
  }

  @override
  void didUpdateWidget(covariant PCPigMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) _updateLoop();
  }

  void _updateLoop() {
    final enabled =
        widget.progress == null && !MediaQuery.disableAnimationsOf(context);
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildMotion(
    MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation(0.0)
        : widget.progress ?? _controller,
  );

  Widget _buildMotion(Animation<double> animation) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        final phase = animation.value;
        final breath = math.sin(phase * math.pi * 4);
        final sway = math.sin(phase * math.pi * 2);
        final height = _height.transform(phase) * widget.jumpHeight / 24;
        final lift = (-height / widget.jumpHeight).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (widget.showShadow)
              Positioned(
                left: 0,
                right: 0,
                bottom: 1,
                height: 10,
                child: FractionallySizedBox(
                  widthFactor: .5,
                  child: Opacity(
                    opacity: 1 - lift * .5,
                    child: Transform.scale(
                      scaleX: 1 - lift * .24,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                          gradient: RadialGradient(
                            colors: [Color(0x45000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(sway * 1.8, height - breath * 1.8),
              child: Transform.rotate(
                angle: _rotation.transform(phase) + sway * .018,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scaleX: _widthScale.transform(phase) + breath * .012,
                  scaleY: _heightScale.transform(phase) + breath * .018,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
