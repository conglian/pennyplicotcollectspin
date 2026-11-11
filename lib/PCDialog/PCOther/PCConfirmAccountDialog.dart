import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/pc_LocalProvider.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../PCTool/PCNoticeMessage.dart';
import '../../PCTool/pc_GradientNumber.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 3.7账号确认邀请（Congratulations!，Figma 210:522）。
/// Confirm Account返回true进入资料表单；右上关闭返回false，不写入余额。
/// 背后仅播放本地guang_bg旋转光圈；减少动画或加载失败时保留静态光。
class PCConfirmAccountDialog extends StatelessWidget {
  const PCConfirmAccountDialog({super.key, required this.withdrawalTarget});
  final double withdrawalTarget;

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFE449),
        Color(0xFFFFF8CD),
        Color(0xFFFFE02E),
        Color(0xFFFF8F07),
      ],
      stops: [0, .45, .49, 1],
    );
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 360,
                height: 600,
                child: Stack(
                  children: [
                    Positioned(
                      right: 8,
                      top: 0,
                      child: IconButton(
                        key: const ValueKey('pcConfirmAccountClose'),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      right: 12,
                      top: 30,
                      height: 44,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PCGradientText(
                          'Congratulations!',
                          fontSize: 32,
                          gradient: gradient,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 74,
                      height: 30,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PCGradientText(
                          "You're About To Withdraw ${PCNoticeMessage.money(withdrawalTarget)}!",
                          fontSize: 18,
                          gradient: gradient,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 70,
                      top: 180,
                      width: 220,
                      height: 220,
                      child: IgnorePointer(
                        child: MediaQuery.disableAnimationsOf(context)
                            ? const PCImg(name: 'pc_process_account_cash_glow')
                            : Lottie.asset(
                                'guang_bg.zip'.files(),
                                key: const ValueKey('pcConfirmAccountGlow'),
                                fit: BoxFit.contain,
                                repeat: true,
                                frameBuilder: (context, child, composition) =>
                                    composition == null
                                    ? const PCImg(
                                        name: 'pc_process_account_cash_glow',
                                      )
                                    : child,
                                errorBuilder: (context, error, stackTrace) =>
                                    const PCImg(
                                      name: 'pc_process_account_cash_glow',
                                    ),
                              ),
                      ),
                    ),
                    const Positioned(
                      left: 70,
                      right: 70,
                      top: 178,
                      height: 20,
                      child: PCText(
                        text: 'Pending Balance',
                        size: 14,
                        color: Colors.white,
                        weight: FontWeight.w500,
                        align: TextAlign.center,
                      ),
                    ),
                    Positioned(
                      left: 70,
                      top: 210,
                      width: 220,
                      height: 160,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2762CC), Color(0xFF003087)],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              height: 68,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF48B0F0),
                                      Color(0xFF1B96E1),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: PCImg(
                                    name: 'pc_process_account_paypal',
                                    width: 160,
                                    height: 52,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              right: 10,
                              top: 84,
                              height: 56,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: PCGradientNumberRoller(
                                  value: withdrawalTarget,
                                  currentValue: withdrawalTarget,
                                  duration: 0,
                                  decimalPlaces:
                                      withdrawalTarget ==
                                          withdrawalTarget.roundToDouble()
                                      ? 0
                                      : 2,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  gradientColors: const [
                                    Colors.white,
                                    Colors.white,
                                  ],
                                  borderWidth: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 46,
                      top: 506,
                      width: 268,
                      height: 64,
                      child: ParticleButton(
                        key: const ValueKey('pcConfirmAccountAction'),
                        onTap: () {
                          PCAnalytics.event('process_confirm_account_pop_c', {
                            'type':
                                PCLocalProvider.instance.pc_account_id
                                    .trim()
                                    .isNotEmpty
                                ? 'yes'
                                : 'no',
                          });
                          Navigator.of(context).pop(true);
                        },
                        // ParticleButton内部会放松非定位子节点的约束；明确撑满
                        // 268×64，避免背景随文字缩成薄条。
                        child: SizedBox.expand(
                          child: Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              const Positioned.fill(
                                child: PCImg(name: 'pc_process_account_button'),
                              ),
                              PCStrokeText(
                                text: 'Confirm Account',
                                size: 24,
                                weight: FontWeight.w800,
                                color: Colors.white,
                                skColor: const Color(0xFF0B3D00),
                                skWidth: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 14,
                      top: 536,
                      width: 60,
                      height: 60,
                      child: IgnorePointer(
                        child: PCImg(name: 'pc_notice_hand'),
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
