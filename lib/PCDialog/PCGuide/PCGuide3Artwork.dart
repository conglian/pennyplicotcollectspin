import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/pc_extension_help.dart';
import 'PCGuideBrandMarquee.dart';

/// 引导3的分层动效：品牌循环滚动，底部 AD 与美元播放本地 guide_3.zip。
///
/// Lottie 已包含金币底座与收益文案，按原插画区域等比显示，避免重复叠图。
class PCGuide3Artwork extends StatelessWidget {
  const PCGuide3Artwork({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        left: 0,
        top: 21,
        width: 360,
        height: 166.7045,
        child: PCGuideBrandMarquee(),
      ),
      Positioned(
        left: 40,
        top: 204,
        width: 280,
        height: 192,
        child: RepaintBoundary(
          child: Lottie.asset(
            'guide_3.zip'.files(),
            fit: BoxFit.contain,
            repeat: true,
            animate: !MediaQuery.disableAnimationsOf(context),
          ),
        ),
      ),
    ],
  );
}
