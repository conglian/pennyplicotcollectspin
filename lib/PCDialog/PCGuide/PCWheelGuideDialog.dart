import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import '../../PCBasic/PCTbaBar.dart';
import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_shou_icon.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideIdentity.dart';

/// 引导14：转盘入口说明（Want Higher Earnings?）。
/// 读取底部 Wheel 的真实位置并复用导航项布局，避免高亮图标、文字错位重叠。
/// 点击高亮或空白后返回调度器，完成引导并切换到 Wheel 页面。
class PCWheelGuideDialog extends StatefulWidget {
  const PCWheelGuideDialog({super.key});

  @override
  State<PCWheelGuideDialog> createState() => _PCWheelGuideDialogState();
}

class _PCWheelGuideDialogState extends State<PCWheelGuideDialog> {
  Rect? _target;
  Size? _lastSize;
  Timer? _measureTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (size == _lastSize) return;
    _lastSize = size;
    _target = null;
    _measureTimer?.cancel();
    // 等待导航完成布局；全屏画布直接使用屏幕坐标，避免入场缩放干扰测量。
    _measureTimer = Timer(const Duration(milliseconds: 300), _measure);
  }

  void _measure() {
    if (!mounted) return;
    final anchor = pcWheelNavigationTargetKey.currentContext
        ?.findRenderObject();
    if (anchor is! RenderBox || !anchor.attached || !anchor.hasSize) return;
    setState(() => _target = anchor.localToGlobal(Offset.zero) & anchor.size);
  }

  @override
  void dispose() {
    _measureTimer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = PCAdaptiveLayout.widthScale(size.width, minScale: 1);
    final navScale = PCAdaptiveLayout.navigationScale(size.width);
    final navHeight = PCAdaptiveLayout.navigationBarHeight(size.width);
    final target =
        _target ??
        Rect.fromLTWH(
          size.width / 2,
          size.height - MediaQuery.paddingOf(context).bottom - navHeight,
          size.width / 4,
          navHeight,
        );
    final cardWidth = math.min(260.0 * scale, size.width - 32);
    final cardLeft = (target.center.dx - cardWidth * .6).clamp(
      16.0,
      size.width - cardWidth - 16,
    );
    final cardTop = math.max(
      MediaQuery.paddingOf(context).top + 48,
      target.top - 176 * scale,
    );
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardWidth,
            height: 140 * scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17 * scale),
                border: Border.all(
                  color: const Color(0xFFE09A46),
                  width: 2 * scale,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFAF6D5), Color(0xFFFFE59A)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10 * scale,
                  28 * scale,
                  10 * scale,
                  8 * scale,
                ),
                child: PCText(
                  text:
                      'Want Higher Earnings?\nSpin the wheel to unlock up to +50% interest bonus in your savings. More bonus, faster withdrawals!',
                  size: 14 * scale,
                  height: 20 / 14,
                  color: Color(0xFF9B620C),
                  weight: FontWeight.w500,
                  maxLines: 5,
                ),
              ),
            ),
          ),
          Positioned(
            left: cardLeft + 20 * scale,
            top: cardTop - 24 * scale,
            child: PCImg(
              name: pcGuideAvatarAsset,
              width: 48 * scale,
              height: 48 * scale,
            ),
          ),
          Positioned(
            left: cardLeft + 24 * scale,
            top: cardTop - 36 * scale,
            child: PCImg(
              name: 'pc_wheel_guide_crown',
              width: 20 * scale,
              height: 20 * scale,
            ),
          ),
          Positioned.fromRect(
            rect: target,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: PCNavBarItemView(
                key: const ValueKey('pcWheelGuideTarget'),
                isSelected: PigsTabController.currentIndex.value == 2,
                item: PersistentBottomNavBarItem(
                  icon: const PCImg(name: 'pc_wheel_n', fit: BoxFit.scaleDown),
                  inactiveIcon: const PCImg(
                    name: 'pc_wheel_s',
                    fit: BoxFit.scaleDown,
                  ),
                  title: 'Wheel',
                  activeColorPrimary: Colors.transparent,
                  inactiveColorPrimary: Colors.transparent,
                ),
              ),
            ),
          ),
          Positioned(
            left: math.min(
              size.width - 60 * navScale,
              target.left + target.width * .65,
            ),
            top: target.top - 20 * navScale,
            width: 60 * navScale,
            height: 60 * navScale,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -math.pi / 2,
                child: PCShouIcon(size: 60 * navScale),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
