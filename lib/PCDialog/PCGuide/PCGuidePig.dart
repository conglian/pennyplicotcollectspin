import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/pc_extension_help.dart';

/// 引导1的小猪及钞票动效，循环播放本地 guide_1.zip。
///
/// 仅显示动画中的小猪区域，箭头、说明文字和底部人物沿用页面独立组件。
class PCGuidePig extends StatelessWidget {
  const PCGuidePig({super.key});

  @override
  Widget build(BuildContext context) => FittedBox(
    child: SizedBox(
      width: 510,
      height: 435,
      child: Stack(
        // 钞票向上飞出小猪的布局范围，保留飞向余额卡片的动画。
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -220,
            top: -240,
            width: 940,
            height: 1110,
            child: ClipPath(
              clipper: const _PigAnimationClipper(),
              child: Lottie.asset(
                'guide_1.zip'.files(),
                fit: BoxFit.fill,
                repeat: true,
                animate: !MediaQuery.disableAnimationsOf(context),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 按动画原始 940×1110 画布裁切，保留猪脚阴影并避开两侧箭头和下方文字。
class _PigAnimationClipper extends CustomClipper<Path> {
  const _PigAnimationClipper();

  @override
  Path getClip(Size size) => Path()
    ..addRect(const Rect.fromLTWH(220, 0, 510, 570))
    ..addRect(const Rect.fromLTWH(280, 570, 410, 105));

  @override
  bool shouldReclip(_PigAnimationClipper oldClipper) => false;
}
