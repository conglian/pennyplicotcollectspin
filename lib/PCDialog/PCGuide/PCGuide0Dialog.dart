import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../PCMainVC/PCHome.dart' show pcHomeCheckInTargetKey;
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/PCCheckInBubble.dart';
import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_shou_icon.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideIdentity.dart';

/// 引导5：高亮首页签到气泡（Tap to Claim），带呼吸和手势提示。
///
/// 点击后返回调度器，进入签到弹窗。
class PCGuide0Dialog extends StatefulWidget {
  const PCGuide0Dialog({super.key});

  @override
  State<PCGuide0Dialog> createState() => PCGuide0DialogState();
}

class PCGuide0DialogState extends State<PCGuide0Dialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  Size? _lastSize;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_lastSize != size) {
      _lastSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
      _breath.value = .5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Rect _fallbackCheckInRect(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double homeHeight = math.max(
      0,
      screenSize.height -
          PCAdaptiveLayout.navigationBarHeight(screenSize.width) -
          MediaQuery.paddingOf(context).bottom,
    );
    final double widthScale = screenSize.width / 375;
    final double heightScale = homeHeight / 650;
    final double scale = math.min(widthScale, heightScale).clamp(0.78, 1.22);
    final double size = 64 * scale;

    return Rect.fromLTWH(
      screenSize.width - (6 * widthScale) - size,
      MediaQuery.paddingOf(context).top + (98 * heightScale),
      size,
      size,
    );
  }

  Rect _checkInRect(BuildContext context) {
    final RenderObject? targetRenderObject = pcHomeCheckInTargetKey
        .currentContext
        ?.findRenderObject();
    if (targetRenderObject is RenderBox &&
        targetRenderObject.attached &&
        targetRenderObject.hasSize) {
      return targetRenderObject.localToGlobal(Offset.zero) &
          targetRenderObject.size;
    }
    return _fallbackCheckInRect(context);
  }

  bool _leaving = false;
  void _finishGuide() {
    if (_leaving || ModalRoute.of(context)?.isCurrent != true) return;
    _leaving = true;
    PCAnalytics.event('new_sign_guide_c');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect checkInRect = _checkInRect(context);
    final double checkInSize = checkInRect.width;
    final double guideScale = checkInSize / 64;
    final double handSize = 60 * guideScale;
    final double handLeft = math.min(
      17 * guideScale,
      math.max(0, screenSize.width - checkInRect.left - handSize),
    );
    final double handTop = 47 * guideScale;
    final double checkInGuideWidth = math.max(checkInSize, handLeft + handSize);
    final double checkInGuideHeight = math.max(checkInSize, handTop + handSize);

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 25.w,
            top: 308.h,
            width: 270.w,
            height: 104.h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: PCImg(
                    name: 'pc_un_tip_bg',
                    width: 270.w,
                    height: 104.h,
                  ),
                ),
                Positioned(
                  left: 12.w,
                  top: 33.h,
                  child: const SizedBox(
                    width: 237,
                    child: PCText(
                      text:
                          'Tap to Claim\n7-Day Streak = GUARANTEED Cash Out\nGrab your first payout NOW',
                      size: 13,
                      color: Color(0xFF9B620C),
                      weight: FontWeight.w700,
                      maxLines: 4,
                    ),
                  ),
                ),
                Positioned(
                  left: 20.w,
                  top: -25.h,
                  child: PCImg(
                    name: pcGuideAvatarAsset,
                    width: 50.w,
                    height: 50.w,
                  ),
                ),
                Positioned(
                  left: 23.w,
                  top: -37.h,
                  child: PCImg(
                    name: 'pc_guang_icon',
                    width: 20.w,
                    height: 20.w,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: checkInRect.left,
            top: checkInRect.top,
            width: checkInGuideWidth,
            height: checkInGuideHeight,
            child: ParticleButton(
              onTap: _finishGuide,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: .94,
                        end: 1.06,
                      ).animate(_breath),
                      child: PCCheckInBubble(size: checkInSize),
                    ),
                  ),
                  Positioned(
                    left: handLeft,
                    top: handTop,
                    child: PCShouIcon(size: handSize),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
