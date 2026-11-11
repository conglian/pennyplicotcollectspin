import 'package:flutter/material.dart';

import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/PCPigMotion.dart';

import '../../PCTool/PCQuizConfig.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// Figma gba 的共用内容：丝带、底板、猪、动态金额和按钮分别搭建。
/// 新用户权限提示和老用户回访弹窗共用布局，由调用方提供按钮行为。
class PCGrowBonusContent extends StatelessWidget {
  const PCGrowBonusContent({
    super.key,
    required this.savedAmount,
    required this.growPercent,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
    this.redButton = false,
  });
  final double savedAmount;
  final double growPercent;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;
  final bool redButton;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = PCAdaptiveLayout.fitScale(
          width: constraints.maxWidth - 8,
          height: constraints.maxHeight - 16,
          designHeight: 500,
        );
        return Center(
          child: SizedBox(
            width: 360 * scale,
            height: 500 * scale,
            child: FittedBox(
              child: SizedBox(
                width: 360,
                height: 500,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 20,
                      top: 136,
                      width: 320,
                      height: 364,
                      child: PCImg(name: 'pc_grow_bonus_panel'),
                    ),
                    const Positioned(
                      left: 12,
                      top: 80,
                      width: 336,
                      height: 84,
                      child: PCImg(name: 'pc_grow_bonus_title_frame'),
                    ),
                    const Positioned(
                      left: 20,
                      top: 88,
                      width: 320,
                      height: 68,
                      child: PCImg(name: 'pc_grow_bonus_title_bg'),
                    ),
                    const Positioned(
                      left: 17.6,
                      top: 85.6,
                      width: 324.8,
                      height: 24.4,
                      child: PCImg(name: 'pc_grow_bonus_title_gloss'),
                    ),
                    const Positioned(
                      left: 19,
                      top: 12,
                      width: 322,
                      height: 88,
                      child: PCImg(name: 'pc_grow_bonus_bow'),
                    ),
                    Positioned(
                      left: 20,
                      top: 100,
                      width: 320,
                      height: 48,
                      child: Semantics(
                        label: 'Grow Bonus Activated!',
                        child: const PCGradientStrokeText(
                          text: '🎉 Grow Bonus Activated!',
                          gradientColors: [
                            Color(0xFFFFE449),
                            Color(0xFFFFF8CD),
                            Color(0xFFFFE02E),
                            Color(0xFFFF8F07),
                          ],
                          strokeColor: Color(0xFF3F2603),
                          strokeWidth: 1.5,
                          fontSize: 24,
                          width: 320,
                          height: 48,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 96,
                      top: 172,
                      width: 168,
                      height: 140,
                      child: PCPigMotion.hero(
                        child: PCImg(name: 'pc_grow_bonus_pig'),
                      ),
                    ),
                    Positioned(
                      left: 30,
                      right: 30,
                      top: 316,
                      height: 28,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PCStrokeText(
                              text: "You've saved ",
                              size: 20,
                              color: Color(0xFFFFF8CD),
                              weight: FontWeight.w900,
                              skWidth: 1.2,
                              skColor: Color(0xFF285200),
                            ),
                            PCStrokeText(
                              text: '\$${savedAmount.toStringAsFixed(2)}',
                              size: 20,
                              color: const Color(0xFFFFC21D),
                              weight: FontWeight.w900,
                              skWidth: 1.2,
                              skColor: const Color(0xFF285200),
                            ),
                            const PCStrokeText(
                              text: ' today',
                              size: 20,
                              color: Color(0xFFFFF8CD),
                              weight: FontWeight.w900,
                              skWidth: 1.2,
                              skColor: Color(0xFF285200),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 44,
                      top: 352,
                      width: 272,
                      height: 40,
                      child: PCText(
                        text:
                            '💡 Come back tomorrow to feed your\n'
                            'piggy again and get a +${PCQuizReward.format(growPercent)}% cash boost!',
                        size: 14,
                        color: Colors.white,
                        weight: FontWeight.w500,
                        align: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                    Positioned(
                      left: 46,
                      top: 412,
                      width: 268,
                      height: 64,
                      child: ParticleButton(
                        key: const ValueKey('pcGrowBonusAction'),
                        onTap: onAction,
                        child: SizedBox.expand(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: PCImg(
                                  name: redButton
                                      ? 'pc_grow_bonus_button'
                                      : 'pc_btn_bg',
                                ),
                              ),
                              PCStrokeText(
                                text: actionLabel,
                                size: 24,
                                color: Colors.white,
                                weight: FontWeight.w800,
                                skWidth: 2.5,
                                skColor: const Color(0xFF3A2600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      width: 48,
                      height: 48,
                      child: ParticleButton(
                        key: const ValueKey('pcGrowBonusClose'),
                        onTap: onClose,
                        child: const Center(
                          child: PCImg(
                            name: 'pc_closes_btn',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
