import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/PCAdaptiveLayout.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 引导1–3共用的页面骨架：独立背景、原生标题、分层插画和底部按钮。
class PCGuidePageLayout extends StatelessWidget {
  const PCGuidePageLayout({
    super.key,
    required this.title,
    required this.buttonText,
    required this.illustration,
    required this.onNext,
    this.isBusy = false,
    this.buttonTransitionBuilder,
  });

  final String title;
  final String buttonText;
  final Widget illustration;
  final VoidCallback onNext;
  final bool isBusy;

  /// 页面可按自己的时序显示按钮，保留按钮的布局位置。
  final Widget Function(Widget button)? buttonTransitionBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF055013),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PCImg(name: 'pc_guide_intro_bg', fit: BoxFit.cover),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = PCAdaptiveLayout.fitScale(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  designHeight: 534,
                );
                final fixedHeight = 534 * scale;
                // 先压缩留白，小屏保持文字和插画尺寸；极矮窗口允许滚动。
                final gapScale = ((constraints.maxHeight - fixedHeight) / 246)
                    .clamp(math.min(0.08, scale), scale)
                    .toDouble();
                final extra = math.max(
                  0.0,
                  constraints.maxHeight - 780 * scale,
                );

                return SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: 360 * scale,
                      child: Column(
                        children: [
                          SizedBox(height: 80 * gapScale + extra * 0.25),
                          SizedBox(
                            width: 320 * scale,
                            height: 56 * scale,
                            child: PCText(
                              text: title,
                              size: 20 * scale,
                              color: const Color(0xFFFFF987),
                              weight: FontWeight.w700,
                              maxLines: 2,
                              align: TextAlign.center,
                              height: 1.4,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 2),
                                  color: Color(0x5E000000),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20 * gapScale),
                          SizedBox(
                            width: 360 * scale,
                            height: 414 * scale,
                            child: FittedBox(
                              child: SizedBox(
                                width: 360,
                                height: 414,
                                child: ClipRect(child: illustration),
                              ),
                            ),
                          ),
                          SizedBox(height: 54 * gapScale),
                          buttonTransitionBuilder?.call(_buildButton(scale)) ??
                              _buildButton(scale),
                          SizedBox(height: 92 * gapScale + extra * 0.75),
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

  Widget _buildButton(double scale) => IgnorePointer(
    ignoring: isBusy,
    child: ParticleButton(
      onTap: onNext,
      child: Opacity(
        opacity: isBusy ? 0.65 : 1,
        child: SizedBox(
          width: 268 * scale,
          height: 64 * scale,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              const PCImg(name: 'pc_guide_intro_button'),
              Center(
                child: PCStrokeText(
                  text: buttonText,
                  size: 24 * scale,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  skWidth: 3 * scale,
                  skColor: const Color(0xFF173600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 按 Figma 实际渲染边界放置独立素材；坐标以插画区域顶部（画板 y=156）为原点。
class PCGuideArtwork extends StatelessWidget {
  const PCGuideArtwork({
    super.key,
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String name;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: PCImg(name: name, fit: BoxFit.fill),
  );
}
