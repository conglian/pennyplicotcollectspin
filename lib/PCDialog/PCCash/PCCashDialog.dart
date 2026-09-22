import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

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
        final double widthScale = availableWidth / designWidth;
        final double heightScale =
            (availableHeight - contentTop - safePadding.bottom - 8) /
            designHeight;
        final double scale = math.max(
          0.1,
          math.min(math.min(widthScale, heightScale), 1.4),
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
                child: Transform.scale(
                  scale: scale,
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
                          left: 110,
                          top: 190,
                          child: PCImg(
                            name: 'pc_guang_s',
                            width: 140,
                            height: 140,
                          ),
                        ),
                        const Positioned(
                          left: 80,
                          top: 218,
                          child: PCImg(
                            name: 'pc_dollars_icon',
                            width: 200,
                            height: 84,
                          ),
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
                            onTap: () => _close(context),
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

class _CashStep extends StatelessWidget {
  final String iconName;
  final String text;

  const _CashStep({required this.iconName, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PCImg(name: iconName, width: 24, height: 24),
        const SizedBox(width: 12),
        PCText(
          text: text,
          size: 15,
          color: Colors.white,
          weight: FontWeight.w500,
        ),
      ],
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

class PCAccountFeedbackDialog extends StatelessWidget {
  final String maskedUserId;
  final double remainingAmount;
  final VoidCallback? onContinue;

  const PCAccountFeedbackDialog({
    super.key,
    this.maskedUserId = '1***2334',
    this.remainingAmount = 4,
    this.onContinue,
  });

  void _close(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _continue(BuildContext context) {
    _close(context);
    onContinue?.call();
  }

  String get _amountText {
    final value = remainingAmount < 0 ? 0.0 : remainingAmount;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '\$$formatted';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 304,
              height: 340,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 20,
                      right: 20,
                      top: 16,
                      height: 24,
                      child: Center(
                        child: PCText(
                          text: 'Official Notice',
                          size: 18,
                          color: Colors.black,
                          weight: FontWeight.w600,
                          align: TextAlign.center,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 10,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _close(context),
                        child: const Center(
                          child: Icon(
                            Icons.close_rounded,
                            size: 24,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 60,
                      child: PCText(
                        text: 'Dear User $maskedUserId:',
                        size: 14,
                        color: Colors.black,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const Positioned(
                      left: 20,
                      top: 92,
                      width: 264,
                      child: PCText(
                        text:
                            'Your payment information has been confirmed successfully, You are a new user, it will be super easy to withdraw cash today!',
                        size: 14,
                        color: Color(0xFF393939),
                        weight: FontWeight.w400,
                        maxLines: 4,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 184,
                      height: 28,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const PCText(
                            text: 'Only ',
                            size: 20,
                            color: Colors.black,
                            weight: FontWeight.w700,
                          ),
                          PCGradientText(
                            _amountText,
                            fontSize: 20,
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFDF28), Color(0xFFFFA11E)],
                            ),
                          ),
                          const PCText(
                            text: ' left to withdraw',
                            size: 20,
                            color: Colors.black,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 20,
                      right: 20,
                      top: 228,
                      child: PCText(
                        text: 'Want to stack up more cash? Keep earning now!',
                        size: 12,
                        color: Color(0xFF8A8A8A),
                        weight: FontWeight.w400,
                        align: TextAlign.center,
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 268,
                      width: 264,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1486F8), Color(0xFF2365EA)],
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: () => _continue(context),
                            child: const Center(
                              child: PCText(
                                text: 'Continue',
                                size: 16,
                                color: Colors.white,
                                weight: FontWeight.w700,
                                align: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
