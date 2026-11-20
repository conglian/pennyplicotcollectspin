import '../../PCTool/PCWithdrawValidation.dart';
import 'package:flutter/material.dart';
import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/PCPigMotion.dart';
import '../../PCTool/pc_GradientNumber.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 升级弹窗的设计画布：完整适配安全区域，避免小屏按钮超出底部。
class PCPigUpgradeCanvas extends StatelessWidget {
  const PCPigUpgradeCanvas({
    super.key,
    required this.children,
    this.contentHeight = 780,
    this.footer,
    this.footerDesignHeight = 124,
    this.scrollKey,
  });
  final List<Widget> children;
  final double contentHeight;
  final Widget? footer;
  final double footerDesignHeight;
  final Key? scrollKey;

  Widget _content() => SizedBox(
    width: 360,
    height: contentHeight,
    child: Stack(children: children),
  );

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (footer == null) {
            final scale = PCAdaptiveLayout.fitScale(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              designHeight: contentHeight,
            );
            return Center(
              child: SizedBox(
                width: 360 * scale,
                height: contentHeight * scale,
                child: FittedBox(fit: BoxFit.fill, child: _content()),
              ),
            );
          }
          // 正文可以滚动，底部操作与同一360设计画布共用倍率，宽屏不再固定360宽。
          final widthScale = PCAdaptiveLayout.widthScale(constraints.maxWidth);
          final fittedScale = PCAdaptiveLayout.fitScale(
            width: constraints.maxWidth,
            height: constraints.maxHeight - 16,
            designHeight: contentHeight + footerDesignHeight,
          );
          // 大屏先让正文和底部整体完整可见；高度不足时保持原字号并允许正文滚动。
          final scale = widthScale > 1
              ? fittedScale
                    .clamp(1.0, PCAdaptiveLayout.maxCanvasScale)
                    .toDouble()
              : widthScale;
          final width = 360 * scale;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      key: scrollKey,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: width,
                          height: contentHeight * scale,
                          child: FittedBox(fit: BoxFit.fill, child: _content()),
                        ),
                      ),
                    ),
                  ),
                  if (scale < 1)
                    // 小屏维持底部原有44像素最小命中高度，正文继续等比收紧。
                    footer!
                  else
                    SizedBox(
                      width: width,
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        child: SizedBox(width: 360, child: footer!),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// 独立红色丝带底图与动态标题，不把截图金额烘焙进图片。
class PCPigUpgradeRibbon extends StatelessWidget {
  const PCPigUpgradeRibbon({super.key, required this.lines});
  final List<String> lines;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    height: 80,
    child: Stack(
      children: [
        const Positioned.fill(child: PCImg(name: 'pc_pig_upgrade_ribbon')),
        Positioned(
          left: 60,
          right: 60,
          top: lines.length > 1 ? 15 : 29,
          bottom: 15,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in lines)
                  PCStrokeText(
                    text: line,
                    size: 18,
                    color: const Color(0xFFFFEF56),
                    weight: FontWeight.w900,
                    skWidth: 2,
                    skColor: const Color(0xFF7C2900),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// 升级专用美元存钱罐及金额牌：复用本地轻动效与渐变数字，素材与普通领奖区分。
class PCPigUpgradeHero extends StatelessWidget {
  const PCPigUpgradeHero({
    super.key,
    required this.level,
    required this.amount,
  });
  final int level;
  final double amount;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: 168,
            height: 140,
            child: PCPigMotion.hero(
              child: PCImg(
                name: level == 1
                    ? 'pc_pig_upgrade_diamond'
                    : 'pc_pig_upgrade_gold',
              ),
            ),
          ),
          const Positioned(
            left: 20.86,
            top: 118,
            width: 126.28,
            height: 48,
            child: PCImg(name: 'pc_pig_upgrade_amount_plate'),
          ),
          Positioned(
            left: 28,
            right: 28,
            top: 126,
            height: 26,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCGradientNumberRoller(
                value: amount,
                currentValue: amount,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                borderWidth: 1.5,
                borderColor: const Color(0xFF7C2900),
                gradientColors: const [Color(0xFFFFDA50), Color(0xFFFFAF00)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PCPigUpgradeButton extends StatelessWidget {
  const PCPigUpgradeButton({
    super.key,
    required this.text,
    required this.onTap,
    this.fontSize = 24,
  });
  final String text;
  final VoidCallback onTap;
  final double fontSize;
  @override
  Widget build(BuildContext context) => ParticleButton(
    onTap: onTap,
    child: SizedBox(
      width: 268,
      height: 64,
      child: Stack(
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_btn_bg')),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PCStrokeText(
                    text: text,
                    size: fontSize,
                    color: Colors.white,
                    weight: FontWeight.w900,
                    skWidth: 2.5,
                    skColor: const Color(0xFF134400),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PCPigUpgradeAccountCard extends StatelessWidget {
  const PCPigUpgradeAccountCard({
    super.key,
    required this.account,
    required this.paymentAsset,
    this.date,
  });
  final String account, paymentAsset;
  final DateTime? date;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF5F9FC), Color(0xFFE9F7FF)],
      ),
    ),
    child: date == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _label('Account:', 14),
                  const SizedBox(width: 4),
                  Expanded(child: _accountText()),
                  const SizedBox(width: 8),
                  Container(
                    width: 80,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1486F8), Color(0xFF2365EA)],
                      ),
                    ),
                    child: const PCText(
                      text: 'Verified',
                      size: 12,
                      color: Colors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _label('Payment Method:', 14),
                  const SizedBox(width: 6),
                  _payment(),
                ],
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const PCText(
                text: 'Release Information Confirm',
                size: 16,
                color: Colors.black,
                weight: FontWeight.w700,
              ),
              Row(
                children: [
                  _label('Method:', 14),
                  const SizedBox(width: 6),
                  _payment(),
                ],
              ),
              Row(
                children: [
                  _label('Account:', 14),
                  const SizedBox(width: 4),
                  Expanded(child: _accountText()),
                ],
              ),
              Row(
                children: [
                  _label('Date:', 14),
                  const SizedBox(width: 4),
                  PCText(
                    text: '${date!.month}/${date!.day}/${date!.year}',
                    size: 14,
                    color: Colors.black,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
            ],
          ),
  );
  Widget _accountText() => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: PCText(
      text: PCWithdrawValidation.displayAccount(account, fallback: 'Not set'),
      size: 14,
      color: Colors.black,
      weight: FontWeight.w500,
    ),
  );

  Widget _label(String text, double size) => PCText(
    text: text,
    size: size,
    color: const Color(0xFF13395F),
    weight: FontWeight.w600,
  );
  Widget _payment() => paymentAsset.isEmpty
      ? _label('Not set', 14)
      : SizedBox(
          width: 66,
          height: 24,
          child: PCImg(
            name: paymentAsset == 'pc_act_0'
                ? 'pc_pig_upgrade_paypal'
                : paymentAsset,
            fit: BoxFit.contain,
          ),
        );
}
