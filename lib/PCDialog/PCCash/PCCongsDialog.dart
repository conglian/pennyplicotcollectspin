import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/PCAdaptiveLayout.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 提现准备完成弹窗（Congratulations / Confirm Now）。
///
/// 展示答题通过及后续提现步骤；确认按钮和关闭按钮均关闭当前弹窗。
class PCCongsDialog extends StatelessWidget {
  const PCCongsDialog({super.key});

  void _close(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size mediaSize = MediaQuery.sizeOf(context);
        final EdgeInsets safePadding = MediaQuery.paddingOf(context);
        final double availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaSize.width;
        final double availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaSize.height;
        const double designWidth = 360;
        const double designHeight = 608;
        final double contentTop = math.max(
          safePadding.top + 8,
          availableHeight * (92 / 812),
        );
        final double scale = PCAdaptiveLayout.fitScale(
          width: availableWidth,
          height: availableHeight - contentTop - safePadding.bottom - 8,
          designWidth: designWidth,
          designHeight: designHeight,
        );
        final double contentWidth = designWidth * scale;
        final double contentHeight = designHeight * scale;

        return SizedBox(
          width: availableWidth,
          height: availableHeight,
          child: Stack(
            children: [
              Positioned(
                left: (availableWidth - contentWidth) * 0.5,
                top: contentTop,
                width: contentWidth,
                height: contentHeight,
                // 先以完整设计尺寸布局再等比缩放，避免小屏绘制位置超出按钮命中范围。
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: designWidth,
                    height: designHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(
                          left: 20,
                          top: 116,
                          child: PCImg(
                            name: 'pc_congs_bottom_bg',
                            width: 320,
                            height: 472,
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          top: 0,
                          child: PCImg(
                            name: 'pc_congs_tops',
                            width: 336,
                            height: 152,
                          ),
                        ),
                        Positioned(
                          right: 13,
                          top: 0,
                          child: ParticleButton(
                            onTap: () => _close(context),
                            child: const PCImg(
                              name: 'pc_closes_btn',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 34,
                          top: 160,
                          child: Container(
                            width: 292,
                            height: 23,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: '#086600'.color(),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const PCText(
                              text:
                                  '28,783 Users Have Successfully Withdrawn Cash This Week',
                              size: 9,
                              color: Colors.white,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 80,
                          top: 190,
                          width: 200,
                          height: 140,
                          child: _CashArtwork(),
                        ),
                        const Positioned(
                          left: 20,
                          top: 336,
                          width: 320,
                          height: 26,
                          child: Center(
                            child: PCStrokeText(
                              text: "You're ready to cash out!",
                              size: 20,
                              color: Color(0xFFFFF8D2),
                              weight: FontWeight.w800,
                              align: TextAlign.center,
                              skWidth: 1.2,
                              skColor: Color(0xFF285200),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 42,
                          top: 368,
                          child: _CashStep(
                            iconName: 'pc_Ellips_s',
                            text: 'Quiz passed',
                          ),
                        ),
                        const Positioned(
                          left: 53,
                          top: 394,
                          child: PCImg(name: 'pc_line_s', width: 2, height: 16),
                        ),
                        const Positioned(
                          left: 42,
                          top: 416,
                          child: _CashStep(
                            iconName: 'pc_Ellips_n',
                            text: 'Now confirm your payout info.',
                          ),
                        ),
                        const Positioned(
                          left: 53,
                          top: 442,
                          child: PCImg(name: 'pc_line_n', width: 2, height: 16),
                        ),
                        const Positioned(
                          left: 42,
                          top: 464,
                          child: _CashStep(
                            iconName: 'pc_Ellips_n',
                            text: 'Fill your piggy bank, cash out instantly.',
                          ),
                        ),
                        Positioned(
                          left: 46,
                          top: 508,
                          child: ParticleButton(
                            onTap: () {
                              if (ModalRoute.of(context)?.isCurrent != true) {
                                return;
                              }
                              PCAnalytics.event('new_confirm_account_pop_c');
                              _close(context);
                            },
                            child: const _ConfirmButton(),
                          ),
                        ),
                        Positioned(
                          left: 270,
                          top: 520,
                          child: IgnorePointer(
                            child: Lottie.asset(
                              'shoushi.zip'.files(),
                              width: 90,
                              height: 90,
                              fit: BoxFit.fill,
                              repeat: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 提现资格的独立装饰层：光圈匀速旋转，现金图标轻柔呼吸。
class _CashArtwork extends StatefulWidget {
  const _CashArtwork();

  @override
  State<_CashArtwork> createState() => _CashArtworkState();
}

class _CashArtworkState extends State<_CashArtwork>
    with TickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: .5,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: .96,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOutSine));
  bool? _animating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_animating == enabled) return;
    _animating = enabled;
    if (enabled) {
      _rotation.repeat();
      _breath.repeat(reverse: true);
    } else {
      _rotation.stop();
      _rotation.value = 0;
      _breath.stop();
      _breath.value = .5;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        RepaintBoundary(
          child: RotationTransition(
            turns: _rotation,
            child: const PCImg(name: 'pc_guang_s', width: 140, height: 140),
          ),
        ),
        RepaintBoundary(
          child: ScaleTransition(
            scale: _scale,
            child: const PCImg(name: 'pc_dollars_icon', width: 200, height: 84),
          ),
        ),
      ],
    ),
  );
}

class _CashStep extends StatelessWidget {
  final String iconName;
  final String text;

  const _CashStep({required this.iconName, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 276,
      child: Row(
        children: [
          PCImg(name: iconName, width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PCText(
                text: text,
                size: 15,
                color: Colors.white,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: const [
          Positioned.fill(
            child: PCImg(name: 'pc_btn_bg', width: 268, height: 64),
          ),
          PCStrokeText(
            text: 'Confirm Now',
            size: 24,
            color: Colors.white,
            weight: FontWeight.w800,
            skWidth: 3,
            skColor: Color(0xFF173600),
          ),
        ],
      ),
    );
  }
}
