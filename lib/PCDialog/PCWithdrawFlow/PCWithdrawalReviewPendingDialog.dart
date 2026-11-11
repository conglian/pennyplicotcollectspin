import 'package:flutter/material.dart';

import '../../PCTool/pc_text.dart';
import 'PCWithdrawalDialogWidgets.dart';

/// 首次提现审核弹窗（Advertiser Review Pending，Figma 221:251）。
/// 进度从传入起点自动走到40%后返回true；关闭返回false，不写入业务进度。
class PCWithdrawalReviewPendingDialog extends StatefulWidget {
  const PCWithdrawalReviewPendingDialog({
    super.key,
    required this.withdrawalTarget,
    this.fromProgress = 0,
    this.toProgress = 40,
    this.animationDuration = const Duration(seconds: 3),
  });
  final double withdrawalTarget;
  final int fromProgress;
  final int toProgress;
  final Duration animationDuration;

  @override
  State<PCWithdrawalReviewPendingDialog> createState() =>
      _PCWithdrawalReviewPendingDialogState();
}

class _PCWithdrawalReviewPendingDialogState
    extends State<PCWithdrawalReviewPendingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed) _close(true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 减少动画时仍保留完整阅读时间，仅取消渐进的视觉变化。
      _motion.forward();
    });
  }

  void _close(bool result) {
    if (!mounted || _closed) return;
    _closed = true;
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PCWithdrawalWhiteCard(
    height: 288,
    title: '⚡ Advertiser Review\nPending',
    onClose: () => _close(false),
    children: [
      Positioned(
        left: 62,
        top: 88,
        width: 180,
        height: 116,
        child: PCWithdrawalPaymentCard(amount: widget.withdrawalTarget),
      ),
      Positioned(
        left: 20,
        right: 20,
        top: 228,
        height: 16,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (_, child) {
            final from = widget.fromProgress.clamp(0, 100);
            final to = widget.toProgress.clamp(from, 100);
            final t = MediaQuery.disableAnimationsOf(context)
                ? 1.0
                : Curves.easeInOut.transform(_motion.value);
            final progress = (from + (to - from) * t).round();
            return PCWithdrawalProgressBar(
              key: const ValueKey('pcWithdrawalPendingProgress'),
              progress: progress / 100,
              label: '$progress%',
            );
          },
        ),
      ),
      const Positioned(
        left: 20,
        right: 20,
        top: 252,
        height: 16,
        child: PCText(
          text: 'Review in progress...',
          size: 12,
          color: Colors.black,
          weight: FontWeight.w400,
          align: TextAlign.center,
        ),
      ),
    ],
  );
}
