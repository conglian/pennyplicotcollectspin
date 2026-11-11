import 'package:flutter/material.dart';

import '../../PCTool/pc_GradientNumber.dart';
import '../../PCTool/PCNewUserGuideController.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideIdentity.dart';
import 'PCGuidePageLayout.dart';
import 'PCGuidePig.dart';

/// Figma「引导页1」：介绍广告主、存钱罐与用户之间的收益关系。
///
/// 点击 Got It 交由引导控制器保存进度并进入引导2，不处理实际奖励。
class PCGuide1Page extends StatelessWidget {
  const PCGuide1Page({super.key, required this.onNext, this.isBusy = false});

  final VoidCallback onNext;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => PCGuidePageLayout(
    title: 'We Partner With Advertisers —\nYou Earn The Rewards”',
    buttonText: 'Got It',
    onNext: onNext,
    isBusy: isBusy,
    illustration: Stack(
      children: const [
        Positioned(
          left: 16,
          top: 0,
          width: 328,
          height: 76,
          child: _BalanceCard(),
        ),
        Positioned(
          left: 97,
          top: 124,
          width: 168,
          height: 140,
          child: PCGuidePig(),
        ),
        PCGuideArtwork(
          name: 'pc_guide_intro_arrow_left',
          left: 41,
          top: 234,
          width: 72,
          height: 72,
        ),
        PCGuideArtwork(
          name: 'pc_guide_intro_arrow_right',
          left: 249,
          top: 234,
          width: 72,
          height: 72,
        ),
        Positioned(
          left: 24,
          top: 268,
          width: 312,
          height: 20,
          child: _DiagramLabel(text: pcGuideAppName),
        ),
        PCGuideArtwork(
          name: 'pc_guide_intro_ad',
          left: 29,
          top: 318,
          width: 72,
          height: 72,
        ),
        PCGuideArtwork(
          name: 'pc_guide_intro_user',
          left: 261,
          top: 318,
          width: 72,
          height: 72,
        ),
        Positioned(
          left: 10,
          top: 394,
          width: 108,
          height: 20,
          child: _DiagramLabel(text: 'Advertisers'),
        ),
        Positioned(
          left: 261,
          top: 394,
          width: 72,
          height: 20,
          child: _DiagramLabel(text: 'You'),
        ),
      ],
    ),
  );
}

class _DiagramLabel extends StatelessWidget {
  const _DiagramLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => PCText(
    text: text,
    size: 14,
    height: 20 / 14,
    color: const Color(0xFFFFF45E),
    weight: FontWeight.w700,
    align: TextAlign.center,
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 3500),
    builder: (context, progress, _) => _content(context, progress),
  );

  Widget _content(BuildContext context, double progress) {
    final target = PCNewUserGuideController.instance.config.withdrawalTarget;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33FFFFFF)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF003087), Color(0xFF0082D2)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 12,
            top: 12,
            width: 52,
            height: 52,
            child: PCImg(name: 'pc_guide_intro_paypal'),
          ),
          Positioned(
            left: 72,
            right: 12,
            top: 12,
            height: 28,
            child: Row(
              children: [
                const SizedBox(
                  width: 114,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PCText(
                      text: 'Growing Balance:',
                      size: 14,
                      height: 1.2,
                      color: Colors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PCGradientNumberRoller(
                      value: target,
                      currentValue: MediaQuery.disableAnimationsOf(context)
                          ? target
                          : 0,
                      duration: 3500,
                      fontSize: 22,
                      decimalPlaces: 0,
                      borderWidth: 0,
                      gradientBegin: Alignment.topCenter,
                      gradientEnd: Alignment.bottomCenter,
                      gradientColors: [Color(0xFFFFDA50), Color(0xFFFFAF00)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 72,
            right: 12,
            top: 50,
            height: 16,
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF002B73),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDD1E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 金额按完整文本占宽，进度条使用剩余空间；长金额仅缩小，不省略。
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: PCText(
                      text:
                          '\$${(target * progress).round()}/\$${target.toStringAsFixed(0)}',
                      size: 14,
                      height: 1.15,
                      color: Colors.white,
                      weight: FontWeight.w500,
                      align: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
