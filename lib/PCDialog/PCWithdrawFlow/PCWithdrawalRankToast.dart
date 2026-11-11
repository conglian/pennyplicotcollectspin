import 'dart:ui';

import 'package:flutter/material.dart';

import '../../PCTool/pc_text.dart';

/// 提现队列排名反馈小卡（Figma 236:779），在现有排队弹窗内显示。
/// 不新增路由和遮罩，不修改排名；由外部控制出现和消失。
class PCWithdrawalRankToast extends StatelessWidget {
  const PCWithdrawalRankToast({super.key, required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 7.95, sigmaY: 7.95),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x97000000),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: SizedBox(
          width: 170,
          height: 44,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PCText(
                    text: 'Your Current rank: ',
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w400,
                  ),
                  PCText(
                    key: const ValueKey('pcWithdrawalRankToastValue'),
                    text: '$rank',
                    size: 14,
                    color: const Color(0xFFFF4C4C),
                    weight: FontWeight.w700,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
