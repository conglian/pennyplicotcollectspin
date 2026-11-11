import 'package:flutter/material.dart';

import 'pc_img.dart';
import 'pc_text.dart';

/// 首页每日签到气泡及引导高亮共用的入口，使用 Figma 日历素材和原生文案。
class PCCheckInBubble extends StatelessWidget {
  const PCCheckInBubble({super.key, this.size = 64, this.showAdBadge = false});

  final double size;
  final bool showAdBadge;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Daily check-in',
    button: true,
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: const PCImg(name: 'pc_checkin_bubble')),
          Positioned(
            left: 0,
            right: 0,
            top: size * .75,
            height: size * .1875,
            child: PCText(
              text: 'Daily Claim',
              size: size * 11 / 64,
              height: 12 / 11,
              color: Colors.white,
              weight: FontWeight.w700,
              align: TextAlign.center,
            ),
          ),
          if (showAdBadge)
            Positioned(
              top: 0,
              right: 0,
              width: size * 20 / 64,
              height: size * 20 / 64,
              child: const IgnorePointer(child: PCImg(name: 'pc_ad_icon')),
            ),
        ],
      ),
    ),
  );
}
