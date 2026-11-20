import '../../PCTool/PCProgressMotion.dart';
import '../../PCTool/PCAnalytics.dart';
import 'package:flutter/material.dart';

import '../../PCTool/PCQuizConfig.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_text.dart';
import 'PCPigUpgradeWidgets.dart';

/// 收集满 20 钻石后的金猪升级弹窗（Release Amount）。
/// 展示收款信息和 10 金砖进度；主按钮关闭后继续答题收集金砖，Maybe Later 仅关闭。
class PCGoldPigUpgradeDialog extends StatelessWidget {
  const PCGoldPigUpgradeDialog({
    super.key,
    required this.amount,
    required this.account,
    required this.paymentAsset,
    required this.date,
    this.gold = 0,
  });
  final double amount, gold;
  final String account, paymentAsset;
  final DateTime date;
  @override
  Widget build(BuildContext context) => PCPigUpgradeCanvas(
    contentHeight: 632,
    scrollKey: const ValueKey('pcGoldUpgradeContent'),
    footer: SizedBox(
      key: const ValueKey('pcGoldUpgradeFooter'),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          PCPigUpgradeButton(
            key: const ValueKey('pcGoldUpgradeContinue'),
            text: 'Collect Gold Bricks To Speed Up',
            fontSize: 16,
            onTap: () {
              PCAnalytics.event('gold_pig_getpop_c');
              Navigator.of(context).pop(true);
            },
          ),
          SizedBox(
            key: const ValueKey('pcGoldUpgradeLater'),
            width: 200,
            height: 44,
            child: PCUnderlineTextButton(
              text: 'Maybe Later',
              fontSize: 14,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
    children: [
      Positioned(
        left: 0,
        top: 40,
        width: 360,
        height: 80,
        child: Semantics(
          image: true,
          label: 'Advertiser PayOut Sent',
          child: const PCImg(
            key: ValueKey('pcGoldUpgradeHeader'),
            name: 'pc_gold_upgrade_header',
          ),
        ),
      ),
      const Positioned(
        left: 20,
        right: 20,
        top: 128,
        height: 24,
        child: Center(
          child: PCText(
            text: 'Transfer Submitted',
            size: 16,
            color: Colors.white,
            weight: FontWeight.w500,
          ),
        ),
      ),
      Positioned(
        left: 96,
        top: 168,
        child: PCPigUpgradeHero(level: 2, amount: amount),
      ),
      const Positioned(
        left: 20,
        right: 20,
        top: 348,
        height: 32,
        child: Center(
          child: PCGradientText(
            'Release Amount',
            fontSize: 24,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFE449),
                Color(0xFFFFF8CD),
                Color(0xFFFFE02E),
                Color(0xFFFF8F07),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        left: 20,
        top: 392,
        width: 320,
        height: 144,
        child: PCPigUpgradeAccountCard(
          key: const ValueKey('pcGoldUpgradeAccount'),
          account: account,
          paymentAsset: paymentAsset,
          date: date,
        ),
      ),
      Positioned(
        left: 20,
        top: 544,
        width: 320,
        height: 88,
        child: Container(
          key: const ValueKey('pcGoldUpgradeProgress'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE09A46), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF6D5), Color(0xFFFFE59A)],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: PCImg(name: 'pc_zhuan_icons'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: PCText(
                            text: '10 Golden Bricks',
                            size: 16,
                            color: Color(0xFF704300),
                            weight: FontWeight.w600,
                          ),
                        ),
                        PCText(
                          text: '${PCQuizReward.format(gold.clamp(0, 10))}/10',
                          size: 12,
                          color: const Color(0xFF704300),
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                    const PCText(
                      text: 'Speed Up Release',
                      size: 12,
                      color: Color(0xFF9B620C),
                      weight: FontWeight.w400,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: PCProgressMotion(
                        value: gold.clamp(0, 10) / 10,
                        builder: (_, animatedProgress, _) =>
                            LinearProgressIndicator(
                              value: animatedProgress,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFD9C386),
                              color: const Color(0xFFFFAC14),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
