import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'PCAudioUtils.dart';
import 'PCAdaptiveLayout.dart';
import 'PCPigMotion.dart';
import 'PCQuizConfig.dart';
import 'pc_GradientNumber.dart';
import 'pc_img.dart';
import 'pc_stroke_text.dart';
import 'pc_text.dart';

/// 领奖后，小猪跳动，奖励素材依次飞向当前页面的余额，弹窗自动收缩退场。
/// 首次出现播放一次到账音效，美元、钻石、金砖共用；重建不重复播放。
/// 动画结束后通知页面显示浮动消息；减少动画设置下使用静态猪图。
/// 黑色圆角底板只覆盖弹窗，开始收缩时移除；点击拦截保留到动画结束。
class PCQuizRewardAnimation extends StatefulWidget {
  const PCQuizRewardAnimation({
    super.key,
    required this.reward,
    required this.balance,
    required this.onFinished,
    this.targetKey,
  });
  final PCQuizReward reward;
  final double balance;
  final VoidCallback onFinished;

  /// 当前页面的美元余额或阶段收集数字；与弹窗内部金额无关。
  final GlobalKey? targetKey;
  @override
  State<PCQuizRewardAnimation> createState() => _PCQuizRewardAnimationState();
}

class _PCQuizRewardAnimationState extends State<PCQuizRewardAnimation>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1800);
  static const _cardCenter = Offset(180, 200);
  static const _shrinkStart = .65;

  static double _entranceScale(double elapsed) => math.max(
    .01,
    Curves.easeOutBack.transform((elapsed / .2).clamp(0.0, 1.0)),
  );

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onFinished();
        });
  // 扫光素材本身只有一秒；与小猪、飞入素材共用弹窗时钟。
  late final Animation<double> _pigGloss = _controller.drive(
    CurveTween(curve: const Interval(0, 1000 / 1800)),
  );

  String get _displayedReward {
    final amount = widget.reward.amountText;
    final decimal = amount.contains('.') ? amount : '$amount.0';
    return widget.reward.type == PCQuizRewardType.cash
        ? '+\$$decimal'
        : '×$decimal';
  }

  Offset? _pageBalanceCenter(BuildContext overlay) {
    final target = widget.targetKey?.currentContext?.findRenderObject();
    final box = overlay.findRenderObject();
    if (target is RenderBox &&
        target.attached &&
        target.hasSize &&
        box is RenderBox &&
        box.attached &&
        box.hasSize) {
      final center = box.globalToLocal(
        target.localToGlobal(target.size.center(Offset.zero)),
      );
      if (center.isFinite) return center;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        unawaited(PCAudioUtils().playRewardAudio());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.duration = const Duration(milliseconds: 300);
    }
    if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final isCash = widget.reward.type == PCQuizRewardType.cash;
      final balance = PCQuizReward.format(widget.balance).split('.');
      final width = constraints.maxWidth, height = constraints.maxHeight;
      final scale = PCAdaptiveLayout.fitScale(
        width: width - 16,
        height: height - 24,
        designHeight: 400,
      );
      final start = Offset(width / 2, height * .52);
      Offset? destination() => _pageBalanceCenter(context);
      return AbsorbPointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (_, child) {
                // 用实际时间比较边界，避免1170/1800的浮点误差让遮罩晚一帧消失。
                final elapsed = _controller.value;
                final shrinking =
                    (_controller.lastElapsedDuration ?? Duration.zero) >=
                    _controller.duration! * _shrinkStart;
                final fly = Curves.easeInOutCubic.transform(
                  ((elapsed - _shrinkStart) / (1 - _shrinkStart)).clamp(0, 1),
                );
                final end = shrinking
                    ? destination() ?? Offset(width * .45, height * .16)
                    : start;
                final center = Offset.lerp(start, end, fly)!;
                return Align(
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: center - _cardCenter * scale,
                    child: SizedBox(
                      width: 360 * scale,
                      height: 400 * scale,
                      child: Opacity(
                        opacity: 1 - fly,
                        child: Transform.scale(
                          scale: _entranceScale(elapsed) * (1 - .92 * fly),
                          child: FittedBox(
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 8,
                                  top: 4,
                                  width: 344,
                                  height: 388,
                                  child: DecoratedBox(
                                    key: const ValueKey(
                                      'pcRewardCardBackground',
                                    ),
                                    decoration: BoxDecoration(
                                      color: shrinking
                                          ? Colors.transparent
                                          : const Color(0xDC000000),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                                child!,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: 360,
                height: 400,
                child: Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 28,
                      height: 48,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            PCText(
                              text: isCash
                                  ? 'My Account: '
                                  : 'Pending Account: ',
                              size: 24,
                              color: Color(0xFFFFEBA8),
                              weight: FontWeight.w900,
                            ),
                            PCGradientNumberRoller(
                              value: widget.balance,
                              currentValue: widget.balance,
                              decimalPlaces: balance.length == 2
                                  ? balance.last.length
                                  : 0,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              borderWidth: 0,
                              gradientColors: const [
                                Color(0xFFFFDF28),
                                Color(0xFFFFA11E),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      top: 92,
                      width: 336,
                      height: 284,
                      child: PCImg(name: 'pc_awards_tong_center'),
                    ),
                    Positioned(
                      // 标题牌在底板图片内部，按绿色区域居中，长文案等比缩小。
                      left: 72,
                      right: 72,
                      top: 130,
                      height: 32,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PCStrokeText(
                          text: widget.reward.title,
                          size: 21,
                          color: Colors.white,
                          weight: FontWeight.w800,
                          skWidth: 1.5,
                          skColor: const Color(0xFF355E00),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 96,
                      top: 160,
                      width: 168,
                      height: 140,
                      child: reduceMotion
                          ? PCImg(name: widget.reward.pigAsset)
                          : PCPigMotion.hero(
                              progress: _controller,
                              child: Lottie.asset(
                                widget.reward.pigAnimationAsset,
                                controller: _pigGloss,
                                fit: BoxFit.contain,
                                frameBuilder: (context, child, composition) =>
                                    composition == null
                                    ? PCImg(name: widget.reward.pigAsset)
                                    : child,
                                errorBuilder: (context, error, stackTrace) =>
                                    PCImg(name: widget.reward.pigAsset),
                              ),
                            ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 317,
                      child: PCStrokeText(
                        text: _displayedReward,
                        size: 32,
                        color: const Color(0xFFFFCA00),
                        weight: FontWeight.w900,
                        skWidth: 2,
                        skColor: const Color(0xFF385500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!reduceMotion && widget.targetKey != null)
              Positioned.fill(
                child: _PCRewardFlight(
                  progress: _controller,
                  destination: destination,
                  cardCenter: start,
                  cardScale: scale,
                  asset: isCash ? 'pc_dollar_icon' : widget.reward.asset,
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// 同一奖励的素材错峰起飞。仅重绘粒子，不在每帧重建图片或布局。
class _PCRewardFlight extends StatelessWidget {
  const _PCRewardFlight({
    required this.progress,
    required this.destination,
    required this.cardCenter,
    required this.cardScale,
    required this.asset,
  });

  final Animation<double> progress;
  final Offset? Function() destination;
  final Offset cardCenter;
  final double cardScale;
  final String asset;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Flow(
        delegate: _PCRewardFlightPainter(
          progress,
          destination,
          cardCenter,
          cardScale,
        ),
        children: List.generate(
          _PCRewardFlightPainter.particles.length,
          (_) => PCImg(name: asset, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}

class _PCRewardFlightPainter extends FlowDelegate {
  _PCRewardFlightPainter(
    this.progress,
    this.destination,
    this.cardCenter,
    this.cardScale,
  ) : super(repaint: progress);

  final Animation<double> progress;
  final Offset? Function() destination;
  final Offset cardCenter;
  final double cardScale;

  // 在构建动画时确定每枚素材的起点、速度和路线，逐帧保持连续。
  static final particles = _createParticles();

  static List<_PCRewardParticle> _createParticles() {
    final random = math.Random(177);
    return List.generate(24, (i) {
      final side = i.isEven ? 1 : -1;
      return (
        start: .075 + i * .020 + random.nextDouble() * .016,
        duration: .385 + random.nextDouble() * .07,
        origin: Offset(
          130 + random.nextDouble() * 100,
          215 + random.nextDouble() * 55,
        ),
        arc: side * (32 + random.nextDouble() * 68),
        size: 18 + random.nextDouble() * 17,
        rotation: side * (.28 + random.nextDouble() * .6),
        landing: Offset(
          random.nextDouble() * 26 - 13,
          random.nextDouble() * 9 - 4.5,
        ),
      );
    });
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(particles[i].size));

  @override
  void paintChildren(FlowPaintingContext context) {
    final elapsed = progress.value;
    final target = destination();
    if (target == null) return;
    for (var i = 0; i < context.childCount; i++) {
      final particle = particles[i];
      final life = (elapsed - particle.start) / particle.duration;
      if (life <= 0 || life >= 1) continue;

      // 前段散开，中段汇向金额，抵达后留一小段时间逐个缩小淡出。
      final flight = Curves.easeInOutSine.transform((life / .86).clamp(0, 1));
      final rest = 1 - flight;
      // 起点取素材出发时的卡片位置，随后在页面坐标中独立飞行。
      final launchScale =
          _PCQuizRewardAnimationState._entranceScale(particle.start) *
          cardScale;
      final from =
          cardCenter +
          (particle.origin - _PCQuizRewardAnimationState._cardCenter) *
              launchScale;
      final to = target + particle.landing * cardScale;
      final drift = math.sin(flight * math.pi * 2) * 7;
      final x =
          from.dx * rest +
          to.dx * flight +
          math.sin(flight * math.pi) * (particle.arc + drift) * cardScale;
      final y =
          from.dy * rest +
          to.dy * flight -
          math.sin(flight * math.pi) * 25 * cardScale;
      final fadeIn = (life / .16).clamp(0.0, 1.0);
      final fadeOut = ((1 - life) / .20).clamp(0.0, 1.0);
      final scale =
          (.68 + .48 * math.sin(math.pi * flight)) *
          (.45 + .55 * fadeOut) *
          cardScale;
      final half = particle.size / 2;
      context.paintChild(
        i,
        opacity: fadeIn * fadeOut,
        transform: Matrix4.identity()
          ..translateByDouble(x, y, 0, 1)
          ..rotateZ(particle.rotation * math.cos(flight * math.pi))
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-half, -half, 0, 1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PCRewardFlightPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      destination != oldDelegate.destination ||
      cardCenter != oldDelegate.cardCenter ||
      cardScale != oldDelegate.cardScale;
}

typedef _PCRewardParticle = ({
  double start,
  double duration,
  Offset origin,
  double arc,
  double size,
  double rotation,
  Offset landing,
});
