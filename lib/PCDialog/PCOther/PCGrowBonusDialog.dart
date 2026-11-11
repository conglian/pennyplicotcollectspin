import 'package:flutter/material.dart';

import '../PCGuide/PCGrowBonusContent.dart';

/// 老用户隔天回访弹窗（Grow Bonus Activated，Figma gba）。
///
/// Go Earn 返回 true，由入口关闭弹窗后切换答题页；右上角关闭仅返回 false。
/// 金额读取本地余额，按钮固定为 Go Earn，不触发通知权限申请或自动发奖。
class PCGrowBonusDialog extends StatelessWidget {
  const PCGrowBonusDialog({
    super.key,
    required this.savedAmount,
    required this.growPercent,
  });
  final double savedAmount;
  final double growPercent;

  @override
  Widget build(BuildContext context) => PCGrowBonusContent(
    savedAmount: savedAmount,
    growPercent: growPercent,
    actionLabel: 'Go Earn',
    redButton: true,
    onAction: () => Navigator.of(context).pop(true),
    onClose: () => Navigator.of(context).pop(false),
  );
}
