import 'package:flutter/material.dart';

import '../../PCTool/PCBalanceHeader.dart';
import '../../PCTool/PCBreathing.dart';
import '../../PCTool/PCQuizConfig.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCOtherDialogWidgets.dart';

/// 转盘原稿底部的钻石与金砖获得界面。主按钮播放激励广告；钻石下方放弃，金砖下方领单倍。
/// 广告、入账和关闭由 PCAwardDialog 串行处理，此处只展示数据和转发点击。
class PCCollectibleAwardDialog extends StatelessWidget {
  const PCCollectibleAwardDialog({
    super.key,
    required this.type,
    required this.amount,
    required this.collected,
    required this.withdrawalTarget,
    required this.paymentAsset,
    required this.lightRotation,
    required this.busy,
    required this.onRewardedClaim,
    required this.onSecondaryAction,
  });

  final PCQuizRewardType type;
  final double amount, collected, withdrawalTarget;
  final String paymentAsset;
  final Animation<double> lightRotation;
  final bool busy;
  final VoidCallback onRewardedClaim, onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final gold = type == PCQuizRewardType.gold;
    // 原稿金砖画板的标题仍使用 “Diamonds”；金额和顶部收集类型按本次奖励绘制。
    final goal = PCQuizReward.format(
      gold ? PCQuizConfig.goldTarget : PCQuizConfig.diamondTarget,
    );
    final viewport = MediaQuery.of(context);
    final availableHeight = viewport.size.height - viewport.padding.vertical;
    return PCResponsiveDialog(
      // 小屏压缩画板底部留白，让两个按钮都保留至少 44 的点击高度。
      designHeight: availableHeight < 560 ? 700 : 780,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 52,
            width: 328,
            height: 112,
            child: PCCollectibleBalanceHeader(
              type: type,
              collected: collected,
              withdrawalTarget: withdrawalTarget,
              paymentAsset: paymentAsset,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 188,
            height: 64,
            child: Center(
              child: PCText(
                key: const ValueKey('pcCollectibleAwardTitle'),
                text: 'Just ',
                size: 28,
                color: const Color(0xFFFFDD38),
                weight: FontWeight.w900,
                height: 32 / 28,
                maxLines: 2,
                align: TextAlign.center,
                shadows: const [
                  Shadow(
                    color: Color(0xFF583205),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
                spans: [
                  TextSpan(
                    text: goal,
                    style: const TextStyle(color: Color(0xFFFF433D)),
                  ),
                  const TextSpan(text: ' Diamonds To\nCash Out!'),
                ],
              ),
            ),
          ),
          Positioned(
            left: 100,
            top: 286,
            width: 160,
            height: 160,
            child: RotationTransition(
              key: const ValueKey('pcCollectibleAwardRays'),
              turns: lightRotation,
              child: const PCImg(name: 'pc_collectible_award_rays'),
            ),
          ),
          Positioned(
            left: 110,
            top: 296,
            width: 140,
            height: 140,
            child: PCBreathing(
              key: const ValueKey('pcAwardArtwork'),
              child: PCImg(
                name: gold
                    ? 'pc_collectible_award_gold'
                    : 'pc_collectible_award_diamond',
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 444,
            height: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCStrokeText(
                text: '×${PCQuizReward.format(amount)}',
                size: 28,
                color: const Color(0xFFFFCA00),
                weight: FontWeight.w900,
                skWidth: 2,
                skColor: const Color(0xFF684300),
              ),
            ),
          ),
          Positioned(
            left: 46,
            top: 556,
            width: 268,
            height: 64,
            child: ParticleButton(
              key: const ValueKey('pcQuizClaimReward'),
              onTap: onRewardedClaim,
              enabled: !busy,
              breathing: !busy,
              child: SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(child: PCImg(name: 'pc_btn_bg')),
                    PCStrokeText(
                      text: gold ? 'Claim Double' : 'Collect',
                      size: 24,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      skWidth: 3,
                      skColor: const Color(0xFF173600),
                    ),
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: PCImg(name: 'pc_ad_icon', size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 46,
            right: 46,
            top: 620,
            height: 64,
            child: TextButton(
              key: ValueKey(gold ? 'pcAwardSingleClaim' : 'pcQuizCloseReward'),
              onPressed: busy ? null : onSecondaryAction,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(
                gold ? 'Claim' : 'Give Up',
                style: TextStyle(
                  fontFamily: text_fontName,
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
