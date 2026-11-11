import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/pc_extension_help.dart';

/// 首笔奖励到账的飞美元动效：复用本地 guide_1.zip 的钞票层。
///
/// 钞票从广告图标左上方沿弧线飞入存钱罐，保留原动画的旋转、缩放及错峰节奏。
/// 隐藏动画包自带的说明插画，仅显示钞票。
class PCGuideDepositCash extends StatelessWidget {
  const PCGuideDepositCash({
    super.key,
    required this.start,
    required this.destination,
  });

  final Offset start;
  final Offset destination;

  @override
  Widget build(BuildContext context) {
    // 屏幕坐标转换到原始 940×1110 画布，钞票始终等比显示。
    final scale = MediaQuery.sizeOf(context).width / 940;
    final begin = start / scale;
    final end = destination / scale;
    final control = Offset(
      math.min(begin.dx, end.dx) - 300,
      (begin.dy + end.dy) * .5,
    );

    return IgnorePointer(
      child: RepaintBoundary(
        child: Lottie.asset(
          'guide_1.zip'.files(),
          fit: BoxFit.contain,
          repeat: true,
          animate: !MediaQuery.disableAnimationsOf(context),
          delegates: LottieDelegates(
            values: [
              ValueDelegate.transformOpacity(const [
                'Group 1000005376.png',
              ], value: 0),
              ValueDelegate.transformPosition(
                const ['Rectangle.png'],
                callback: (frame) {
                  final progress = frame.interpolatedKeyframeProgress;
                  final remaining = 1 - progress;
                  return begin * (remaining * remaining) +
                      control * (2 * remaining * progress) +
                      end * (progress * progress);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
