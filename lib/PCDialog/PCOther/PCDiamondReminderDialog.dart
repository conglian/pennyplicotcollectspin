import 'package:flutter/material.dart';

import '../../PCTool/PCReviewPresentationController.dart';
import '../../PCTool/pc_text.dart';
import 'PCProcessDialogWidgets.dart';

/// 3.7 钻石收集提醒：复用审核进度白卡及钻石图，数量读取当前剩余钻石。
/// Collect 按钮返回 true 继续收集，右上角关闭返回 false，不发放奖励。
class PCDiamondReminderDialog extends StatelessWidget {
  const PCDiamondReminderDialog({
    super.key,
    required this.remaining,
    this.reviewPresentation,
  });
  final double remaining;
  final PCReviewPresentationController? reviewPresentation;

  @override
  Widget build(BuildContext context) {
    final left = remaining.isFinite
        ? remaining.clamp(0.0, 20.0).toDouble()
        : 20.0;
    final quantity = pcProcessAmount(left);
    return PCProcessWhiteCard(
      height: 524,
      title: 'Speed Up Your Payout?',
      buttonText: 'Collect ×$quantity Diamonds',
      onAction: () => Navigator.of(context).pop(true),
      onClose: () => Navigator.of(context).pop(false),
      children: [
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          height: 22,
          child: PCText(
            text: 'Only ×$quantity diamonds left',
            size: 14,
            weight: FontWeight.w400,
            color: const Color(0xFF393939),
            align: TextAlign.center,
          ),
        ),
        Positioned(
          top: 94,
          left: 96,
          width: 112,
          height: 112,
          child: PCProcessDiamondRing(
            collected: 20 - left,
            progress: (20 - left) / 20,
          ),
        ),
        const Positioned(
          top: 216,
          left: 24,
          right: 24,
          height: 40,
          child: PCText(
            text: 'Complete your diamond collection',
            size: 16,
            color: Color(0xFF13395F),
            weight: FontWeight.w600,
            align: TextAlign.center,
            maxLines: 2,
          ),
        ),
        Positioned(
          top: 264,
          left: 16,
          right: 16,
          height: 168,
          child: PCProcessReviewChecklist(presentation: reviewPresentation),
        ),
      ],
    );
  }
}
