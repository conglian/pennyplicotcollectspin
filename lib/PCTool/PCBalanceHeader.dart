import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'PCAdaptiveLayout.dart';
import 'PCNumberManager.dart';
import 'PCQuizConfig.dart';
import 'pc_GradientNumber.dart';
import 'pc_LocalProvider.dart';
import 'pc_extension_help.dart';
import 'pc_img.dart';
import 'pc_text.dart';

/// 首页、答题和转盘共用的阶段余额栏。
/// 粉猪沿用答题美元样式；钻石/金猪的收集量读取本地阶段缓存，分别以20/10为目标。
class PCBalanceHeader extends StatelessWidget {
  const PCBalanceHeader({super.key, required this.provider, this.rewardTarget});

  final PCLocalProvider provider;
  final GlobalKey? rewardTarget;

  @override
  Widget build(BuildContext context) {
    if (provider.pc_pig_level > 0) {
      return _PCCollectibleBalanceHeader(
        provider: provider,
        rewardTarget: rewardTarget,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 字号、图标和背景只按本栏实际约束缩放一次，不叠加全屏.sp/.h。
        final scale = PCAdaptiveLayout.fitScale(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          designWidth: 328,
          designHeight: 108,
        );
        return Center(
          child: SizedBox(
            width: 328 * scale,
            height: 108 * scale,
            child: FittedBox(
              child: SizedBox(
                width: 328,
                height: 108,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          image: PCDImg('pc_quiz_top_bg'),
                        ),
                        child: _cashContent(),
                      ),
                    ),
                    Positioned(
                      top: -14,
                      right: -3.5,
                      width: 175,
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          image: PCDImg('pc_quiz_top_tips'),
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: PCText(
                                text: 'Super Easy Cash Today!',
                                size: 14,
                                color: '#9B620C'.color(),
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      right: 136.5,
                      width: 8,
                      height: 8,
                      child: PCImg(name: 'pc_quiz_top_tips_bottom'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cashContent() {
    final withdrawTarget = PCNumberHelpers().pc_firstTarget;
    final balance = provider.pc_dollar_number;
    final remaining = math.max(0.0, withdrawTarget - balance);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PCText(
                      text: 'My Account: ',
                      size: 16,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ),
                    PCGradientNumberRoller(
                      key: rewardTarget,
                      value: balance,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      gradientColors: ['#FFD21C'.color(), '#FFAF00'.color()],
                      borderWidth: 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 232,
              height: 16,
              decoration: BoxDecoration(image: PCDImg('pc_quiz_top_pro')),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (balance / withdrawTarget).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: '#FFDD1E'.color()),
                  ),
                ),
              ),
            ),
            SizedBox(width: 4),
            Container(
              width: 68,
              height: 24,
              decoration: BoxDecoration(image: PCDImg('pc_act_s_0')),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PCImg(
                      name:
                          'pc_act_${provider.pc_account_seled_index.clamp(0, 3)}',
                      width: 16,
                      height: 16,
                    ),
                    SizedBox(width: 6),
                    PCText(
                      text: '\$${PCQuizReward.format(withdrawTarget)}',
                      size: 14,
                      color: Colors.white,
                      weight: FontWeight.w900,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: '#C87B7D'.color(),
              height: 1.15,
              fontFamily: 'CarlsbergSansBlack',
            ),
            children: [
              const TextSpan(text: 'Only \$'),
              TextSpan(
                text: PCQuizReward.format(remaining),
                style: TextStyle(color: '#FFDD1D'.color()),
              ),
              TextSpan(
                text:
                    ' Left To Withdraw \$${PCQuizReward.format(withdrawTarget)}',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }
}

class _PCCollectibleBalanceHeader extends StatelessWidget {
  const _PCCollectibleBalanceHeader({
    required this.provider,
    this.rewardTarget,
  });

  final PCLocalProvider provider;
  final GlobalKey? rewardTarget;

  @override
  Widget build(BuildContext context) {
    final diamond = provider.pc_pig_level == 1;
    final stageName = diamond ? 'diamond' : 'gold';
    final target = diamond
        ? PCQuizConfig.diamondTarget
        : PCQuizConfig.goldTarget;
    // sync 已把精确的钻石/金砖数量写入此缓存；旧整数字段会丢失小数。
    final collected = math.max(0.0, provider.pc_pig_level_index);
    final left = math.max(0.0, ((target - collected) * 100).round() / 100);
    final withdrawTarget = PCNumberHelpers().pc_firstTarget;
    final progress = (collected / target).clamp(0.0, 1.0);
    final accent = diamond ? '#53E9FF'.color() : '#FFDD1D'.color();
    final colors = diamond
        ? ['#2EEFFC'.color(), '#1162F9'.color()]
        : ['#FFDF2D'.color(), '#DA5000'.color()];

    // 背板铺满父级；猪、图标和文字共用等比尺寸，避免矮屏独立拉伸高宽。
    // 轨道使用横向剩余空间，游标始终留在轨道内，两端都与主猪、支付角标分开。
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / 328,
          constraints.maxHeight / 112,
        );
        final top = (constraints.maxHeight - 112 * scale) / 2;
        final trackLeft = 68 * scale;
        final trackWidth = constraints.maxWidth - 160 * scale;
        final markerSize = 24 * scale;
        double y(double value) => top + value * scale;

        return Stack(
          children: [
            const Positioned.fill(child: PCImg(name: 'pc_stage_balance_bg')),
            Positioned(
              left: 12 * scale,
              top: y(12),
              width: 48 * scale,
              height: 40 * scale,
              child: PCImg(name: 'pc_stage_pig_$stageName'),
            ),
            Positioned(
              left: trackLeft,
              top: y(24),
              width: trackWidth,
              height: 16 * scale,
              child: const PCImg(name: 'pc_stage_progress_track'),
            ),
            Positioned(
              left: trackLeft + 2 * scale,
              top: y(26),
              width: trackWidth - 4 * scale,
              height: 12 * scale,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6 * scale),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: trackLeft + (trackWidth - markerSize) * progress,
              top: y(20),
              width: markerSize,
              height: markerSize,
              child: PCImg(name: 'pc_stage_progress_$stageName'),
            ),
            Positioned(
              left: trackLeft + 26 * scale,
              top: y(26),
              width: trackWidth - 52 * scale,
              height: 12 * scale,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _number(
                      collected,
                      Colors.white,
                      size: 11 * scale,
                      outlined: true,
                    ),
                    PCText(
                      text: '/${PCQuizReward.format(target)}',
                      size: 11 * scale,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Color(0xFF003000), blurRadius: 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12 * scale,
              top: y(20),
              width: 72 * scale,
              height: 24 * scale,
              child: DecoratedBox(
                key: const ValueKey('pc_stage_payment_badge'),
                decoration: BoxDecoration(image: PCDImg('pc_pp_bg')),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                  child: Row(
                    children: [
                      PCImg(
                        name:
                            'pc_act_${provider.pc_account_seled_index.clamp(0, 3)}',
                        width: 20 * scale,
                        height: 20 * scale,
                      ),
                      SizedBox(width: 2 * scale),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _number(
                            withdrawTarget,
                            '#FFAF00'.color(),
                            dollars: true,
                            size: 12 * scale,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12 * scale,
              right: 12 * scale,
              top: y(52),
              height: 16 * scale,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PCText(
                    text: "Money's In-Ready To Withdraw!",
                    size: 12 * scale,
                    color: Colors.white,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12 * scale,
              right: 12 * scale,
              top: y(72),
              height: 28 * scale,
              child: DecoratedBox(
                key: const ValueKey('pc_stage_collection_stats'),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .21),
                  borderRadius: BorderRadius.circular(6 * scale),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        'Collected:',
                        collected,
                        accent,
                        stageName,
                        rewardTarget,
                        scale,
                      ),
                    ),
                    Container(
                      width: .5 * scale,
                      height: 16 * scale,
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    Expanded(
                      child: _stat(
                        'Left:',
                        left,
                        accent,
                        stageName,
                        null,
                        scale,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(
    String label,
    double value,
    Color color,
    String stage,
    Key? numberKey,
    double scale,
  ) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PCText(
            text: label,
            size: 12 * scale,
            color: Colors.white,
            weight: FontWeight.w500,
          ),
          SizedBox(width: 4 * scale),
          _number(value, color, size: 13 * scale, numberKey: numberKey),
          SizedBox(width: 4 * scale),
          PCImg(
            name: 'pc_stage_collect_$stage',
            width: 18 * scale,
            height: 18 * scale,
          ),
        ],
      ),
    ),
  );

  Widget _number(
    double value,
    Color color, {
    bool dollars = false,
    double size = 10,
    Key? numberKey,
    bool outlined = false,
  }) => PCGradientNumberRoller(
    key: numberKey,
    value: value,
    currentValue: value,
    fontSize: size,
    fontWeight: FontWeight.w700,
    gradientColors: [color, color],
    borderWidth: outlined ? .8 : 0,
    borderColor: const Color(0xFF003000),
    showDolas: dollars,
    decimalPlaces: value == value.roundToDouble() ? 0 : 2,
  );
}
