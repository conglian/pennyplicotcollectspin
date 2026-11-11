import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'PCAudioUtils.dart';
import 'PCAdaptiveLayout.dart';
import 'PCQuizConfig.dart';
import 'pc_extension_help.dart';
import 'pc_GradientNumber.dart';
import 'pc_img.dart';
import 'pc_stroke_text.dart';
import 'pc_text.dart';

/// 领奖后的分层展示：按奖励阶段播放小猪扫光，再收缩飞向顶部余额。
/// 首次出现播放一次到账音效，美元、钻石、金砖共用；重建不重复播放。
/// 动画结束后通知页面显示浮动消息；减少动画设置下使用静态猪图。
/// 开始收缩时立即移除暗色背景，透明拦截层仍保留到动画结束。
class PCQuizRewardAnimation extends StatefulWidget {
  const PCQuizRewardAnimation({
    super.key,
    required this.reward,
    required this.balance,
    required this.onFinished,
    this.targetKey,
    this.cardBackgroundColor = const Color(0xDC000000),
  });
  final PCQuizReward reward;
  final double balance;
  final VoidCallback onFinished;
  final GlobalKey? targetKey;

  /// 主展示阶段的独立黑色卡底；开始收缩时与全屏遮罩一起变为透明。
  final Color cardBackgroundColor;
  @override
  State<PCQuizRewardAnimation> createState() => _PCQuizRewardAnimationState();
}

class _PCQuizRewardAnimationState extends State<PCQuizRewardAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      });

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
      final width = constraints.maxWidth, height = constraints.maxHeight;
      final scale = PCAdaptiveLayout.fitScale(
        width: width - 16,
        height: height - 24,
        designHeight: 400,
      );
      final start = Offset(width / 2, height * .52);
      var end = Offset(width * .45, height * .16);
      final target = widget.targetKey?.currentContext?.findRenderObject();
      final box = context.findRenderObject();
      if (target is RenderBox &&
          target.hasSize &&
          box is RenderBox &&
          box.hasSize) {
        end = box.globalToLocal(
          target.localToGlobal(target.size.center(Offset.zero)),
        );
      }
      return AnimatedBuilder(
        animation: _controller,
        builder: (_, child) {
          // 用实际时间比较边界，避免1170/1800的浮点误差让遮罩晚一帧消失。
          final shrinking =
              (_controller.lastElapsedDuration ?? Duration.zero) >=
              _controller.duration! * .65;
          final fly = Curves.easeInOutCubic.transform(
            ((_controller.value - .65) / .35).clamp(0, 1),
          );
          final pop = Curves.easeOutBack.transform(
            (_controller.value / .2).clamp(0, 1),
          );
          final center = Offset.lerp(start, end, fly)!;
          return AbsorbPointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    key: const ValueKey('pcRewardBackdrop'),
                    color: shrinking ? Colors.transparent : pcDialogBackdrop,
                  ),
                ),
                Positioned(
                  left: center.dx - 180 * scale,
                  top: center.dy - 200 * scale,
                  width: 360 * scale,
                  height: 400 * scale,
                  child: Opacity(
                    opacity: 1 - fly,
                    child: Transform.scale(
                      scale: math.max(.01, pop * (1 - .92 * fly)),
                      child: FittedBox(
                        child: Stack(
                          children: [
                            Positioned(
                              left: 8,
                              top: 4,
                              width: 344,
                              height: 388,
                              child: DecoratedBox(
                                key: const ValueKey('pcRewardCardBackground'),
                                decoration: BoxDecoration(
                                  color: shrinking
                                      ? Colors.transparent
                                      : widget.cardBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
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
              ],
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
                      const PCText(
                        text: 'My Account: ',
                        size: 24,
                        color: Color(0xFFFFEBA8),
                        weight: FontWeight.w900,
                      ),
                      PCGradientNumberRoller(
                        value: widget.balance,
                        currentValue: widget.balance,
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
                child: MediaQuery.disableAnimationsOf(context)
                    ? PCImg(name: widget.reward.pigAsset)
                    : Lottie.asset(
                        widget.reward.pigAnimationAsset,
                        fit: BoxFit.contain,
                        repeat: false,
                        frameBuilder: (context, child, composition) =>
                            composition == null
                            ? PCImg(name: widget.reward.pigAsset)
                            : child,
                        errorBuilder: (context, error, stackTrace) =>
                            PCImg(name: widget.reward.pigAsset),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 317,
                child: PCStrokeText(
                  text: widget.reward.type == PCQuizRewardType.cash
                      ? '+\$${widget.reward.amountText}'
                      : '×${widget.reward.amountText}',
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
      );
    },
  );
}
