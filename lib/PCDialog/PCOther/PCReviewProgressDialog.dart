import 'package:flutter/material.dart';

import '../../PCTool/pc_GradientNumber.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/PCReviewPresentationController.dart';
import '../../PCTool/pc_text.dart';
import 'PCProcessDialogWidgets.dart';

/// 3.7 审核进度弹窗（Speed Up Your Payout，Figma 223:409）。
/// 滚动展示本次审核进度，完成后保留页面；Continue 返回 true，关闭返回 false。
class PCReviewProgressDialog extends StatefulWidget {
  const PCReviewProgressDialog({
    super.key,
    required this.collected,
    required this.fromProgress,
    required this.toProgress,
    this.reviewPresentation,
  });
  final double collected;
  final int fromProgress;
  final int toProgress;
  final PCReviewPresentationController? reviewPresentation;

  @override
  State<PCReviewProgressDialog> createState() => _PCReviewProgressDialogState();
}

class _PCReviewProgressDialogState extends State<PCReviewProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;
  bool _closed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
  }

  void _close(bool proceed) {
    if (_closed || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(proceed);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.fromProgress.clamp(0, 100);
    final to = widget.toProgress.clamp(from, 100);
    return PCProcessWhiteCard(
      height: 524,
      title: 'Speed Up Your Payout?',
      buttonText: 'Continue',
      onAction: () => _close(true),
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
          child: AnimatedBuilder(
            animation: _animation,
            builder: (_, child) => PCProcessDiamondRing(
              collected: widget.collected,
              progress:
                  (from +
                      (to - from) *
                          Curves.easeOut.transform(_animation.value)) /
                  100,
            ),
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
              children: [
                const PCText(
                  text: 'Current Review Process: ',
                  size: 16,
                  color: Color(0xFF13395F),
                  weight: FontWeight.w600,
                  height: 24 / 16,
                ),
                PCGradientNumberRoller(
                  key: const ValueKey('pcReviewProgressNumber'),
                  value: to,
                  currentValue: from,
                  duration: MediaQuery.disableAnimationsOf(context) ? 0 : 1800,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  gradientBegin: Alignment.topCenter,
                  gradientEnd: Alignment.bottomCenter,
                  decimalPlaces: 0,
                  showDolas: false,
                  gradientColors: const [Color(0xFFFFDF28), Color(0xFFFFA11E)],
                ),
                const PCGradientText(
                  '%',
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 40 / 28,
                  strokeWidth: 1,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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
      ],
    );
  }
}
