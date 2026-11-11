import 'package:flutter/material.dart';

import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCQuizConfig.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_text.dart';
import 'PCPigUpgradeWidgets.dart';

/// 美元达到首档提现门槛后的钻石猪升级弹窗（Confirm Withdrawal）。
/// 展示真实收款账户和已锁定金额；确认后关闭弹窗，由提现控制器继续审核、开箱和钻石倒计时流程。
class PCDiamondPigUpgradeDialog extends StatefulWidget {
  const PCDiamondPigUpgradeDialog({
    super.key,
    required this.amount,
    required this.account,
    required this.paymentAsset,
  });
  final double amount;
  final String account, paymentAsset;

  @override
  State<PCDiamondPigUpgradeDialog> createState() =>
      _PCDiamondPigUpgradeDialogState();
}

class _PCDiamondPigUpgradeDialogState extends State<PCDiamondPigUpgradeDialog> {
  bool _confirmed = false;

  void _confirm() {
    if (_confirmed || ModalRoute.of(context)?.isCurrent == false) return;
    _confirmed = true;
    PCAnalytics.event('diamond_pig_getpop_c');
    PCAnalytics.event('collect_diamond_pop_c');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => PCPigUpgradeCanvas(
    children: [
      Positioned(
        left: 0,
        top: 80,
        child: PCPigUpgradeRibbon(
          lines: [
            '🎉 \$${PCQuizReward.format(widget.amount)}',
            'Secured in Your Diamond Pig!',
          ],
        ),
      ),
      Positioned(
        left: 96,
        top: 220,
        child: PCPigUpgradeHero(level: 1, amount: widget.amount),
      ),
      Positioned(
        left: 20,
        top: 416,
        width: 320,
        height: 84,
        child: PCPigUpgradeAccountCard(
          account: widget.account,
          paymentAsset: widget.paymentAsset,
        ),
      ),
      Positioned(
        left: 46,
        top: 596,
        child: PCPigUpgradeButton(text: 'Confirm Withdrawal', onTap: _confirm),
      ),
      const Positioned(
        left: 62,
        right: 62,
        top: 672,
        height: 18,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: PCImg(name: 'pc_withdraw_safe_2x'),
              ),
              SizedBox(width: 4),
              PCText(
                text: 'Platform approved. Funds are ready.',
                size: 12,
                color: Colors.white,
                weight: FontWeight.w400,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
