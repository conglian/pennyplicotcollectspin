import 'package:flutter/material.dart';

import 'PCQuizConfig.dart';
import 'pc_img.dart';
import 'pc_stroke_text.dart';

/// 首页纸钞、钻石、金砖奖励气泡；各阶段均保留一个未知奖励入口。
/// 激励入口显示AD；免费入口冷却时图案置灰并显示剩余时间。
class PCHomeRewardBubble extends StatelessWidget {
  const PCHomeRewardBubble({
    super.key,
    required this.type,
    required this.amount,
    this.mystery = false,
    this.size = 64,
    this.showAdBadge = true,
    this.cooldownSeconds = 0,
  });
  final PCQuizRewardType type;
  final double? amount;
  final bool mystery;
  final double size;
  final bool showAdBadge;
  final int cooldownSeconds;

  String get caption {
    if (cooldownSeconds > 0) {
      final minutes = (cooldownSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (cooldownSeconds % 60).toString().padLeft(2, '0');
      return '00:$minutes:$seconds';
    }
    if (amount == null) return '…';
    final prefix = type == PCQuizRewardType.cash ? r'$' : '×';
    return '$prefix${mystery ? '???' : PCQuizReward.format(amount!)}';
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: cooldownSeconds > 0
                ? const ColorFilter.matrix([
                    .2126,
                    .7152,
                    .0722,
                    0,
                    0,
                    .2126,
                    .7152,
                    .0722,
                    0,
                    0,
                    .2126,
                    .7152,
                    .0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    .65,
                    0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
            child: PCImg(
              name: switch (type) {
                PCQuizRewardType.cash => 'pc_doaller_icon',
                PCQuizRewardType.diamond => 'pc_home_bubble_diamond',
                PCQuizRewardType.gold => 'pc_home_bubble_gold',
              },
            ),
          ),
        ),
        Positioned(
          left: -3,
          right: -3,
          bottom: 0,
          height: size * .35,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCStrokeText(
                text: caption,
                size: size * (cooldownSeconds > 0 ? 15 : 18) / 64,
                color: cooldownSeconds > 0
                    ? Colors.white
                    : const Color(0xFFFFDD1D),
                weight: FontWeight.w800,
                skWidth: size * 1.5 / 64,
                skColor: const Color(0xFF174507),
              ),
            ),
          ),
        ),
        if (showAdBadge)
          Positioned(
            top: 0,
            right: 0,
            width: size * 20 / 64,
            height: size * 20 / 64,
            child: const IgnorePointer(
              child: PCImg(name: 'pc_ad_icon', fit: BoxFit.contain),
            ),
          ),
      ],
    ),
  );
}
