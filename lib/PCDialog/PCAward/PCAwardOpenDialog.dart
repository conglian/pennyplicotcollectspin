import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/PCPigMotion.dart';
import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 存钱罐开启后的奖励展示弹窗（My Account / Earned）。
///
/// 显示当前账户余额、本次奖励 [award]，并播放存钱罐开启动画。
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
                          width: 168,
                          height: 140,
                          child: PCPigMotion.hero(
                            child: PCImg(name: 'pc_big_icon_0'),
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
