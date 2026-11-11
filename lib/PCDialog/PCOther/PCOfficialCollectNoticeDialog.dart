import 'package:flutter/material.dart';

import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_text.dart';
import 'PCProcessDialogWidgets.dart';

/// 3.7 官方钻石收集通知（Official Notice，复用 Figma 172:487 白卡样式）。
/// 文案展示当前还需收集的钻石，Continue 和关闭仅收起通知，不改余额或发奖。
class PCOfficialCollectNoticeDialog extends StatelessWidget {
  const PCOfficialCollectNoticeDialog({super.key, required this.remaining});
  final double remaining;

  @override
  Widget build(BuildContext context) => PCProcessWhiteCard(
    height: 340,
    title: 'Official Notice',
    buttonText: 'Continue',
    onAction: () => Navigator.of(context).pop(false),
    onClose: () => Navigator.of(context).pop(false),
    children: [
      const Positioned(
        top: 60,
        left: 20,
        right: 20,
        height: 20,
        child: PCText(
          text: 'Dear User:',
          size: 14,
          color: Colors.black,
          weight: FontWeight.w500,
        ),
      ),
      const Positioned(
        top: 92,
        left: 20,
        right: 20,
        height: 84,
        child: PCText(
          text:
              'Your payment information has been confirmed. Keep collecting diamonds to complete your payout review.',
          size: 14,
          weight: FontWeight.w400,
          color: Color(0xFF393939),
          maxLines: 4,
        ),
      ),
      Positioned(
        top: 184,
        left: 20,
        right: 20,
        height: 32,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              const PCText(
                text: 'Only ',
                size: 20,
                color: Colors.black,
                weight: FontWeight.w700,
              ),
              PCGradientText(
                '×${pcProcessAmount(remaining.clamp(0.0, 20.0).toDouble())}',
                fontSize: 20,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFDF28), Color(0xFFFFA11E)],
                ),
              ),
              const PCText(
                text: ' diamonds left',
                size: 20,
                color: Colors.black,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
      const Positioned(
        top: 232,
        left: 20,
        right: 20,
        height: 20,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: PCText(
            text: 'Keep answering to collect more diamonds!',
            size: 12,
            weight: FontWeight.w400,
            color: Color(0xFF8A8A8A),
          ),
        ),
      ),
    ],
  );
}
