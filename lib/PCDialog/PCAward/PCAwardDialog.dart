import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

class PCAwardDialog extends StatelessWidget {
  final double award;

  const PCAwardDialog({super.key, required this.award});

  @override
  Widget build(BuildContext context) {
    final double balance = PCLocalProvider.instance.pc_dollar_number;
    return _WithdrawAwardView(award: award, balance: balance);
  }
}

class PCAwardOpenDialog extends StatelessWidget {
  final double award;

  const PCAwardOpenDialog({super.key, required this.award});

  @override
  Widget build(BuildContext context) {
    final double balance = PCLocalProvider.instance.pc_dollar_number;
    return _EarnedAwardView(award: award, balance: balance);
  }
}

class _EarnedAwardView extends StatelessWidget {
  final double award;
  final double balance;

  const _EarnedAwardView({required this.award, required this.balance});

  String _compactMoney(double value) {
    final double safeValue = value.abs() < 0.005 ? 0 : value;
    if (safeValue == safeValue.roundToDouble()) {
      return safeValue.toInt().toString();
    }
    return safeValue
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size mediaSize = MediaQuery.sizeOf(context);
        final double availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mediaSize.width;
        final double availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaSize.height;
        const double designWidth = 360;
        const double designHeight = 584;
        final double scale = math.min(
          availableWidth / designWidth,
          availableHeight / designHeight,
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
                top: 0,
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
                        Positioned(
                          left: 8,
                          top: 200,
                          child: Container(
                            width: 344,
                            height: 384,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 230,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const PCText(
                                text: 'My Account: ',
                                size: 28,
                                color: Colors.white,
                                weight: FontWeight.w800,
                              ),
                              PCStrokeText(
                                text: '\$${_compactMoney(balance)}',
                                size: 38,
                                color: '#FFD900'.color(),
                                weight: FontWeight.w900,
                                skWidth: 2,
                                skColor: '#446300'.color(),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          top: 300,
                          child: PCImg(
                            name: 'pc_awards_tong_center',
                            width: 336,
                            height: 284,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 324,
                          child: PCStrokeText(
                            text: 'Earned \$${_compactMoney(award)}',
                            size: 21,
                            color: Colors.white,
                            weight: FontWeight.w800,
                            skWidth: 1.5,
                            skColor: '#355E00'.color(),
                          ),
                        ),
                        const Positioned(
                          left: 96,
                          top: 366,
                          child: PCImg(
                            name: 'pc_big_icon_0',
                            width: 168,
                            height: 140,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 521,
                          child: PCStrokeText(
                            text: '+\$${award.toStringAsFixed(1)}',
                            size: 31,
                            color: '#FFCA00'.color(),
                            weight: FontWeight.w900,
                            skWidth: 2,
                            skColor: '#385500'.color(),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: -8,
                          child: IgnorePointer(
                            child: Lottie.asset(
                              'wallter_open.zip'.files(),
                              width: 360,
                              height: 360,
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

class _WithdrawAwardView extends StatelessWidget {
  final double award;
  final double balance;

  const _WithdrawAwardView({required this.award, required this.balance});

  String _formatMoney(double value) {
    final double safeValue = value.abs() < 0.005 ? 0 : value;
    if (safeValue == safeValue.roundToDouble()) {
      return safeValue.toInt().toString();
    }
    return safeValue
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _close(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double remaining = math.max(0, 100 - balance);

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
        const double contentWidth = 360;
        const double contentHeight = 602;
        final double contentTop = math.max(
          safePadding.top + 8,
          availableHeight * (80 / 812),
        );
        final double widthScale = math.max(
          0.1,
          (availableWidth - 16) / contentWidth,
        );
        final double heightScale = math.max(
          0.1,
          (availableHeight - contentTop - safePadding.bottom - 12) /
              contentHeight,
        );
        final double scale = math.min(math.min(widthScale, heightScale), 1.4);
        final double scaledWidth = contentWidth * scale;
        final double scaledHeight = contentHeight * scale;

        return SizedBox(
          width: availableWidth,
          height: availableHeight,
          child: Stack(
            children: [
              Positioned(
                left: (availableWidth - scaledWidth) * 0.5,
                top: contentTop,
                width: scaledWidth,
                height: scaledHeight,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: contentWidth,
                    height: contentHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 20,
                          top: 110,
                          child: _WithdrawPanel(
                            balance: balance,
                            remaining: remaining,
                            award: award,
                            formatMoney: _formatMoney,
                            onClose: () => _close(context),
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          top: 0,
                          child: PCImg(
                            name: 'pc_awards_top',
                            width: 360,
                            height: 80,
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

class _WithdrawPanel extends StatelessWidget {
  final double balance;
  final double remaining;
  final double award;
  final String Function(double value) formatMoney;
  final VoidCallback onClose;

  const _WithdrawPanel({
    required this.balance,
    required this.remaining,
    required this.award,
    required this.formatMoney,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 492,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: PCImg(name: 'pc_awards_bg', width: 320, height: 492),
          ),
          Positioned(
            left: 16,
            top: 15,
            child: _BalanceHeader(balanceText: formatMoney(balance)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PCText(
                  text: 'Only ',
                  size: 20,
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
                PCText(
                  text: '\$${formatMoney(remaining)}',
                  size: 22,
                  color: '#FFE500'.color(),
                  weight: FontWeight.w900,
                ),
                const PCText(
                  text: ' Left To Withdraw',
                  size: 20,
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
              ],
            ),
          ),
          const Positioned(left: 90, top: 101, child: _RotatingAwardLight()),
          const Positioned(
            left: 58,
            top: 126,
            child: PCImg(name: 'pc_dollars_icon', width: 204, height: 84),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 247,
            child: PCStrokeText(
              text: '+\$${formatMoney(award)}',
              size: 34,
              color: '#FFB800'.color(),
              weight: FontWeight.w900,
              skWidth: 2,
              skColor: '#4B4B00'.color(),
            ),
          ),
          const Positioned(
            left: 60,
            top: 293,
            child: _AwardCheckRow(text: 'Ensure safety'),
          ),
          const Positioned(
            left: 60,
            top: 325,
            child: _AwardCheckRow(text: 'Arrived within 24 hours'),
          ),
          const Positioned(
            left: 60,
            top: 357,
            child: _AwardCheckRow(text: '1M+ user trusted'),
          ),
          Positioned(
            left: 26,
            top: 404,
            child: ParticleButton(onTap: onClose, child: const _ClaimButton()),
          ),
          Positioned(
            right: -5,
            top: -6,
            child: ParticleButton(
              onTap: onClose,
              child: const PCImg(name: 'pc_closes_btn', width: 24, height: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingAwardLight extends StatefulWidget {
  const _RotatingAwardLight();

  @override
  State<_RotatingAwardLight> createState() => _RotatingAwardLightState();
}

class _RotatingAwardLightState extends State<_RotatingAwardLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const PCImg(name: 'pc_guang_s', width: 140, height: 140),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final String balanceText;

  const _BalanceHeader({required this.balanceText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: ['#FFFDF0'.color(), '#FFF09B'.color()],
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          const PCImg(name: 'pc_act_0', width: 36, height: 36),
          const SizedBox(width: 4),
          PCText(
            text: 'Payment',
            size: 16,
            color: '#0046A0'.color(),
            weight: FontWeight.w700,
          ),
          const SizedBox(width: 4),
          const PCImg(name: 'pc_dui_1_icon', width: 12, height: 12),
          const Spacer(),
          PCText(
            text: 'My Cash: ',
            size: 12,
            color: '#6F4B1D'.color(),
            weight: FontWeight.w700,
          ),
          PCText(
            text: '\$$balanceText',
            size: 18,
            color: '#00A51A'.color(),
            weight: FontWeight.w900,
          ),
        ],
      ),
    );
  }
}

class _AwardCheckRow extends StatelessWidget {
  final String text;

  const _AwardCheckRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PCImg(name: 'pc_dui_0_icon', width: 24, height: 24),
        const SizedBox(width: 12),
        PCText(
          text: text,
          size: 16,
          color: Colors.white,
          weight: FontWeight.w500,
        ),
      ],
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: PCImg(name: 'pc_btn_bg', width: 268, height: 64),
          ),
          const PCStrokeText(
            text: 'Claim',
            size: 27,
            color: Colors.white,
            weight: FontWeight.w800,
            skWidth: 3,
            skColor: Color(0xFF173600),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: PCImg(name: 'pc_ad_icon', width: 20, height: 20),
          ),
        ],
      ),
    );
  }
}
