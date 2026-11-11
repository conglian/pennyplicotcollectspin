import 'package:flutter/material.dart';

import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/PCReviewPresentationController.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCProcessDialogWidgets.dart';
import 'PCWithdrawalDialogWidgets.dart';

/// 首次提现的审核验证页（Speed Up Your Payout，Figma 223:409）。
/// 审核视觉从0分段走到40%，与实际钻石数量分开显示，不修改已缓存审核进度。
/// 动画结束保持页面；Continue返回true继续引导，关闭返回false。
class PCWithdrawalReviewVerificationDialog extends StatefulWidget {
  const PCWithdrawalReviewVerificationDialog({
    super.key,
    required this.collected,
    this.reviewProgress = 40,
    this.target = 20,
    this.animationDuration = const Duration(seconds: 3),
    this.reviewPresentation,
  });
  final double collected;
  final int reviewProgress;
  final double target;
  final Duration animationDuration;
  final PCReviewPresentationController? reviewPresentation;

  @override
  State<PCWithdrawalReviewVerificationDialog> createState() =>
      _PCWithdrawalReviewVerificationDialogState();
}

class _PCWithdrawalReviewVerificationDialogState
    extends State<PCWithdrawalReviewVerificationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );
  // 先加速到10%，稍停后继续到约27%，再逐渐收敛到40%。
  // 仅控制视觉节奏，审核缓存与真实钻石数量不随这些中间值变化。
  late final Animation<double> _progress = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: .25,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween(.25), weight: 10),
    TweenSequenceItem(
      tween: Tween(
        begin: .25,
        end: .68,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 28,
    ),
    TweenSequenceItem(tween: ConstantTween(.68), weight: 9),
    TweenSequenceItem(
      tween: Tween(
        begin: .68,
        end: .9,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 20,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: .9,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 13,
    ),
  ]).animate(_motion);
  bool _started = false;
  bool _closed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _motion.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closed && _motion.value < 1) _motion.forward();
    });
  }

  void _close(bool proceed) {
    if (_closed || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closed = true;
    _motion.stop();
    Navigator.of(context).pop(proceed);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final displayedProgress =
          widget.reviewProgress.clamp(0, 100) * _progress.value;
      return PCWithdrawalWhiteCard(
        height: 524,
        title: 'Speed Up Your Payout?',
        onClose: () => _close(false),
        children: [
          const Positioned(
            top: 60,
            left: 16,
            right: 16,
            height: 20,
            child: PCText(
              text: 'Diamond Boost Activated',
              size: 14,
              weight: FontWeight.w400,
              color: Color(0xFF393939),
              height: 20 / 14,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            top: 94,
            left: 96,
            width: 112,
            height: 112,
            child: PCProcessDiamondRing(
              key: const ValueKey('pcWithdrawalVerificationRing'),
              collected: widget.collected,
              progress: displayedProgress / 100,
            ),
          ),
          Positioned(
            top: 212,
            left: 24,
            right: 24,
            height: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PCText(
                    text: 'Current Review Process: ',
                    size: 16,
                    color: Color(0xFF13395F),
                    weight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                  PCGradientText(
                    key: const ValueKey('pcWithdrawalVerificationProgress'),
                    '${displayedProgress.round()}%',
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    height: 40 / 28,
                    strokeWidth: 1,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [.1875, .796875],
                      colors: [Color(0xFFFFDF28), Color(0xFFFFA11E)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 264,
            left: 16,
            right: 16,
            height: 168,
            child: PCProcessReviewChecklist(
              presentation: widget.reviewPresentation,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            height: 52,
            child: PCWithdrawalBlueButton(
              key: const ValueKey('pcWithdrawalVerificationContinue'),
              text: 'Continue',
              onTap: () => _close(true),
            ),
          ),
        ],
      );
    },
  );
}
