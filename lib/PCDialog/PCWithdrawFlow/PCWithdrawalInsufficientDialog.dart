import '../../PCTool/PCAnalytics.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/PCNoticeMessage.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCWithdrawalDialogWidgets.dart';

/// 提现余额不足（Insufficient Balance，Figma 236:975）。
/// 显示所选档位与真实余额的差额，Keep Earning返回true去答题，关闭返回false。
class PCWithdrawalInsufficientDialog extends StatelessWidget {
  const PCWithdrawalInsufficientDialog({
    super.key,
    required this.balance,
    required this.withdrawalTarget,
  });
  final double balance;
  final double withdrawalTarget;

  @override
  Widget build(BuildContext context) => PCWithdrawalWhiteCard(
    height: 316,
    title: 'Insufficient Balance',
    onClose: () => Navigator.of(context).pop(false),
    children: [
      Positioned(
        left: 62,
        top: 64,
        width: 180,
        height: 116,
        child: PCWithdrawalPaymentCard(
          amount: withdrawalTarget,
          insufficient: true,
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        top: 200,
        height: 24,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PCText(
                text: 'Only ',
                size: 16,
                color: Color(0xFFFF4C4C),
                weight: FontWeight.w400,
              ),
              PCStrokeText(
                key: const ValueKey('pcWithdrawalInsufficientAmount'),
                text: PCNoticeMessage.money(
                  math.max(0, withdrawalTarget - balance),
                ),
                size: 14,
                color: const Color(0xFFFFDF28),
                weight: FontWeight.w600,
                skColor: const Color(0xFF9B5C00),
                skWidth: .5,
              ),
              const PCText(
                text: ' left to withdraw',
                size: 16,
                color: Color(0xFFFF4C4C),
                weight: FontWeight.w400,
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 20,
        right: 20,
        bottom: 20,
        height: 52,
        child: PCWithdrawalBlueButton(
          key: const ValueKey('pcWithdrawalKeepEarning'),
          text: 'Keep Earning',
          onTap: () {
            PCAnalytics.event('cash_not_pop_c');
            Navigator.of(context).pop(true);
          },
        ),
      ),
    ],
  );
}
