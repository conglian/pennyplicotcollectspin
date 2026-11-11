import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../PCTool/PCAdaptiveLayout.dart';

import '../PCTool/PCPigMotion.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_shine.dart';

/// Figma「启动页」：背景、品牌标题、金色底座、动画小猪和加载进度分层显示。
class PCLaunchView extends StatelessWidget {
  const PCLaunchView({super.key, required this.progress});

  final Widget progress;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF002C19),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const PCImg(name: 'pc_luanch_bg', fit: BoxFit.cover),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = PCAdaptiveLayout.fitScale(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                designHeight: 430,
              );
              // 保留标题和插画比例，小屏先收紧上下留白。
              final gapScale = ((constraints.maxHeight - 430 * scale) / 350)
                  .clamp(math.min(.08, scale), scale)
                  .toDouble();
              final extra = math.max(0.0, constraints.maxHeight - 780 * scale);
              return SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: 360 * scale,
                    child: Column(
                      children: [
                        SizedBox(height: 80 * gapScale + extra * .25),
                        PCShine(
                          width: 268 * scale,
                          height: 96 * scale,
                          duration: const Duration(milliseconds: 720),
                          pause: const Duration(milliseconds: 2800),
                          axis: Axis.horizontal,
                          child: const PCImg(name: 'pc_launch_title'),
                        ),
                        SizedBox(height: 65 * gapScale),
                        SizedBox(
                          width: 360 * scale,
                          height: 292 * scale,
                          child: const FittedBox(
                            child: SizedBox(
                              width: 360,
                              height: 292,
                              child: ClipRect(
                                clipper: _HeroClipper(),
                                child: _LaunchHero(),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 85 * gapScale),
                        SizedBox(
                          width: 200 * scale,
                          height: 42 * scale,
                          child: FittedBox(
                            child: SizedBox(
                              width: 200,
                              height: 42,
                              child: progress,
                            ),
                          ),
                        ),
                        SizedBox(height: 120 * gapScale + extra * .75),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// 给起跳和伸展预留顶部空间，底座光晕仍按设计区域裁切。
class _HeroClipper extends CustomClipper<Rect> {
  const _HeroClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -48, size.width, size.height);

  @override
  bool shouldReclip(_HeroClipper oldClipper) => false;
}

/// 底座和脚底阴影固定，小猪及其光晕一起运动，保留脚踩在台上的感觉。
class _LaunchHero extends StatelessWidget {
  const _LaunchHero();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 16,
        top: 157,
        width: 328,
        height: 118,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 11.65, sigmaY: 11.65),
          child: const PCImg(name: 'pc_launch_platform'),
        ),
      ),
      Positioned(
        left: 24,
        top: 157,
        width: 312,
        height: 112,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.3, sigmaY: 2.3),
          child: const PCImg(name: 'pc_launch_platform'),
        ),
      ),
      const Positioned(
        left: 24,
        top: 157,
        width: 312,
        height: 112,
        child: PCImg(name: 'pc_launch_platform'),
      ),
      const Positioned(
        left: 95.6667,
        top: 144.6667,
        width: 168.6666,
        height: 62.5778,
        child: PCImg(name: 'pc_launch_shadow'),
      ),
      const Positioned(
        left: 92,
        top: 23,
        width: 176,
        height: 163,
        child: PCPigMotion(
          jumpHeight: 22,
          showShadow: false,
          child: _GlowingPig(),
        ),
      ),
    ],
  );
}

class _GlowingPig extends StatelessWidget {
  const _GlowingPig();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: -6,
        top: -6,
        width: 187,
        height: 174,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 11.65, sigmaY: 11.65),
          child: const PCImg(name: 'pc_launch_pig'),
        ),
      ),
      Positioned(
        left: -2,
        top: 0,
        width: 179,
        height: 166,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.3, sigmaY: 2.3),
          child: const PCImg(name: 'pc_launch_pig'),
        ),
      ),
      const PCImg(name: 'pc_launch_pig'),
    ],
  );
}
