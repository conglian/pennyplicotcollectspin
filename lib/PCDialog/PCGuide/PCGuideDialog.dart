import 'dart:async';
import 'dart:math' as math;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:pennypilotcollectspin/PCTool/pc_text.dart';
import '../../PCMainVC/PCHome.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_shou_icon.dart';

Rect _homePigRect(BuildContext context) {
  final RenderObject? renderObject = pcHomePigTargetKey.currentContext
      ?.findRenderObject();
  if (renderObject is RenderBox &&
      renderObject.attached &&
      renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  final Size screenSize = MediaQuery.sizeOf(context);
  return Rect.fromLTWH((screenSize.width - 168.w) * 0.5, 218.h, 168.w, 140.h);
}

// 新手引导入口
class PCGuideDialog extends StatelessWidget {
  const PCGuideDialog({super.key});

  void _openGuide(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    navigator.context.tipShow(const PCGuide0Dialog(), blurSigma: 0);
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect pigRect = _homePigRect(context);

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pigRect.left,
            top: pigRect.top,
            child: PCImg(
              name: 'pc_big_icon_0',
              width: pigRect.width,
              height: pigRect.height,
            ),
          ),
          Positioned(
            left: (screenSize.width - 126.w) / 2,
            top: 337.h,
            child: Container(
              width: 126.w,
              height: 48.h,
              decoration: BoxDecoration(image: PCDImg('pc_dollar_icons')),
              alignment: Alignment.center,
              padding: EdgeInsets.only(bottom: 2.h),
              child: PCStrokeText(
                text: '\$20.00',
                size: 21.sp,
                color: '#FFD515'.color(),
                weight: FontWeight.w800,
                skWidth: 2,
                skColor: '#651035'.color(),
              ),
            ),
          ),
          Positioned(left: 24.w, top: 416.h, child: _GuideSpeechCard()),
          Positioned(
            left: (screenSize.width - 268.w) / 2,
            top: 550.h,
            child: ParticleButton(
              onTap: () => _openGuide(context),
              child: const _GuideActionButton(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSpeechCard extends StatelessWidget {
  const _GuideSpeechCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260.w,
      height: 101.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: ['#FFFBE2'.color(), '#FFE49A'.color()],
                ),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: '#D77A08'.color(), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10.w,
            top: 30.h,
            right: 10.w,
            child: RichText(
              maxLines: 3,
              text: TextSpan(
                style: TextStyle(
                  color: '#9B4D08'.color(),
                  fontSize: 14.sp,
                  height: 1.42,
                  fontWeight: FontWeight.w500,
                  fontFamily: text_fontName,
                  decoration: TextDecoration.none,
                ),
                children: [
                  const TextSpan(
                    text: "Hey, I’m Jason.\nJust last week, I cashed out ",
                  ),
                  TextSpan(
                    text: '\$100',
                    style: TextStyle(
                      color: '#F21D0C'.color(),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: '\nfrom this app.'),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20.w,
            top: -38.h,
            child: PCImg(name: 'pc_guang_icon', width: 21.w, height: 21.w),
          ),
          Positioned(
            left: 21.w,
            top: -26.h,
            child: Container(
              width: 49.w,
              height: 49.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: '#FFF8D7'.color(),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(2.w),
              child: ClipOval(
                child: PCImg(name: 'pc_ellipse_3', fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideActionButton extends StatelessWidget {
  const _GuideActionButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268.w,
      height: 62.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: PCImg(name: 'pc_btn_bg', width: 268.w, height: 62.h),
          ),
          PCStrokeText(
            text: 'Try It Now',
            size: 23.sp,
            color: Colors.white,
            weight: FontWeight.w800,
            skWidth: 3,
            skColor: '#173600'.color(),
          ),
        ],
      ),
    );
  }
}

// 引导第一步
class PCGuide0Dialog extends StatefulWidget {
  const PCGuide0Dialog({super.key});

  @override
  State<PCGuide0Dialog> createState() => PCGuide0DialogState();
}

class PCGuide0DialogState extends State<PCGuide0Dialog> {
  static const double _homeNavigationBarHeight = 81;

  Rect _fallbackAppleRect(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double homeHeight = math.max(
      0,
      screenSize.height - _homeNavigationBarHeight,
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

  Rect _appleRect(BuildContext context) {
    final RenderObject? targetRenderObject = pcHomeAppleTargetKey.currentContext
        ?.findRenderObject();
    if (targetRenderObject is RenderBox &&
        targetRenderObject.attached &&
        targetRenderObject.hasSize) {
      return targetRenderObject.localToGlobal(Offset.zero) &
          targetRenderObject.size;
    }
    return _fallbackAppleRect(context);
  }

  void _finishGuide() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(0);
    }
    context.tipShow2(PCGuide1Dialog());
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect appleRect = _appleRect(context);
    final double appleSize = appleRect.width;
    final double guideScale = appleSize / 64;
    final double handSize = 60 * guideScale;
    final double handLeft = math.min(
      17 * guideScale,
      math.max(0, screenSize.width - appleRect.left - handSize),
    );
    final double handTop = 47 * guideScale;
    final double appleGuideWidth = math.max(appleSize, handLeft + handSize);
    final double appleGuideHeight = math.max(appleSize, handTop + handSize);

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
                  child: PCImg(
                    name: 'pc_un_tip_content',
                    width: 237.w,
                    height: 55.h,
                  ),
                ),
                Positioned(
                  left: 20.w,
                  top: -25.h,
                  child: PCImg(name: 'pc_ellipse_3', width: 50.w, height: 50.w),
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
            left: appleRect.left,
            top: appleRect.top,
            width: appleGuideWidth,
            height: appleGuideHeight,
            child: ParticleButton(
              onTap: _finishGuide,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: PCImg(
                      name: 'pc_apple_icon',
                      width: appleSize,
                      height: appleSize,
                    ),
                  ),
                  Positioned(
                    left: appleSize - (20 * guideScale),
                    top: 0,
                    child: PCImg(
                      name: 'pc_ad_icon',
                      width: 20 * guideScale,
                      height: 20 * guideScale,
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

// 引导第二步
class PCGuide1Dialog extends StatefulWidget {
  const PCGuide1Dialog({super.key});

  @override
  State<PCGuide1Dialog> createState() => PCGuide1DialogState();
}

class PCGuide1DialogState extends State<PCGuide1Dialog> {
  Timer? _nextGuideTimer;
  ModalRoute<dynamic>? _dialogRoute;

  @override
  void initState() {
    super.initState();
    _nextGuideTimer = Timer(const Duration(seconds: 2), _showNextGuide);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dialogRoute ??= ModalRoute.of(context);
  }

  Future<void> _showNextGuide() async {
    if (!mounted) return;

    final ModalRoute<dynamic>? route = _dialogRoute;
    final NavigatorState? navigator = route?.navigator;
    if (route == null || navigator == null) return;

    navigator.removeRoute(route);
    await route.completed;
    if (!navigator.mounted) return;
    navigator.context.tipShow(const PCGuide2Dialog(), blurSigma: 0);
  }

  @override
  void dispose() {
    _nextGuideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Rect pigRect = _homePigRect(context);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: pigRect.left,
          top: pigRect.top,
          child: PCImg(
            name: 'pc_big_b_0',
            width: pigRect.width,
            height: pigRect.height,
          ),
        ),
        Positioned(
          left: (0.width(context) - 120.w) * 0.5,
          top: 320.h,
          child: Container(
            width: 120.w,
            height: 40.h,
            decoration: BoxDecoration(image: PCDImg('pc_dollar_icons')),
            child: Center(
              child: PCStrokeText(
                text: '\$${PCLocalProvider.instance.pc_dollar_number}',
                size: 20,
                color: '#FFAF00'.color(),
                weight: FontWeight.w700,
                skWidth: 1,
                skColor: '#3C1C04'.color(),
              ),
            ),
          ),
        ),
        Positioned(
          left: (0.width(context) - 304.w) * 0.5,
          top: 398.h,
          child: SizedBox(
            width: 304.w,
            height: 168.h,
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  child: Lottie.asset(
                    width: 304,
                    height: 80,
                    fit: BoxFit.fill,
                    "guide_2.zip".files(),
                    repeat: true,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: (304.w - 108.w) * 0.5,
                  child: PCImg(
                    name: 'pc_google_icons',
                    width: 108.w,
                    height: 84.h,
                  ),
                ),
                Positioned(
                  top: 68.h,
                  left: (304.w - 180.w) * 0.5,
                  child: Container(
                    width: 180.w,
                    height: 40.h,
                    decoration: BoxDecoration(image: PCDImg('pc_doaller_bgs')),
                    child: Row(
                      mainAxisAlignment: .center,
                      children: [
                        PCImg(name: 'cs_pp_0_icon', width: 24.w, height: 24.w),
                        SizedBox(width: 8.w),
                        PCText(
                          text:
                              '+\$${PCLocalProvider.instance.pc_dollar_number}',
                          size: 18,
                          color: '#FFFFFF'.color(),
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 引导第三步
class PCGuide2Dialog extends StatelessWidget {
  const PCGuide2Dialog({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect pigRect = _homePigRect(context);

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: pigRect.left,
            top: pigRect.top,
            child: PCImg(
              name: 'pc_big_b_0',
              width: pigRect.width,
              height: pigRect.height,
            ),
          ),
          Positioned(
            left: (screenSize.width - 126.w) * 0.5,
            top: 337.h,
            child: Container(
              width: 126.w,
              height: 48.h,
              decoration: BoxDecoration(image: PCDImg('pc_dollar_icons')),
              alignment: Alignment.center,
              padding: EdgeInsets.only(bottom: 2.h),
              child: PCStrokeText(
                text:
                    '\$${PCLocalProvider.instance.pc_dollar_number.toStringAsFixed(2)}',
                size: 21.sp,
                color: '#FFD515'.color(),
                weight: FontWeight.w800,
                skWidth: 2,
                skColor: '#651035'.color(),
              ),
            ),
          ),
          Positioned(
            left: (screenSize.width - 320.w) * 0.5,
            top: 414.h,
            child: SizedBox(
              width: 320.w,
              height: 312.h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PCImg(
                      name: 'pc_guide3_bg',
                      width: 320.w,
                      height: 312.h,
                    ),
                  ),
                  Positioned(
                    left: 17.w,
                    top: 20.h,
                    right: 17.w,
                    child: Row(
                      children: [
                        PCImg(name: 'pc_wall_icons', width: 20.w, height: 20.w),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: PCText(
                            text: 'Your First commission has arrived!',
                            size: 16.sp,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: (320.w - 76.w) * 0.5,
                    top: 54.h,
                    child: PCImg(
                      name: 'pc_pig_fendoalldr',
                      width: 76.w,
                      height: 56.h,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 123.h,
                    child: PCStrokeText(
                      text: 'Deposit amount: \$6',
                      size: 25.sp,
                      color: '#FFE500'.color(),
                      weight: FontWeight.w800,
                      skWidth: 1.5,
                      skColor: '#253400'.color(),
                    ),
                  ),
                  Positioned(
                    left: 24.w,
                    right: 24.w,
                    top: 166.h,
                    child: RichText(
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          fontFamily: text_fontName,
                          decoration: TextDecoration.none,
                        ),
                        children: [
                          const TextSpan(
                            text: 'An advertiser just paid you.\njust ',
                          ),
                          TextSpan(
                            text: '\$50.00',
                            style: TextStyle(color: '#FFE500'.color()),
                          ),
                          const TextSpan(text: ' more to cash out!'),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 26.w,
                    top: 224.h,
                    child: ParticleButton(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 268.w,
                        height: 64.h,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: PCImg(
                                name: 'pc_btn_bg',
                                width: 268.w,
                                height: 64.h,
                              ),
                            ),
                            PCStrokeText(
                              text: 'Get By Quiz',
                              size: 24.sp,
                              color: Colors.white,
                              weight: FontWeight.w800,
                              skWidth: 3,
                              skColor: '#173600'.color(),
                            ),
                          ],
                        ),
                      ),
                    ),
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

// 引导第四步：成长奖励激活与通知权限引导弹窗。
class PCGuide3Dialog extends StatefulWidget {
  const PCGuide3Dialog({super.key});

  @override
  State<PCGuide3Dialog> createState() => _PCGuide3DialogState();
}

class _PCGuide3DialogState extends State<PCGuide3Dialog>
    with WidgetsBindingObserver {
  bool _notificationEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationPermission();
    }
  }

  Future<void> _refreshNotificationPermission() async {
    bool enabled = false;
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        enabled =
            await notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final permission = await notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        enabled =
            (permission?.isEnabled ?? false) ||
            (permission?.isProvisionalEnabled ?? false);
      }
    } catch (_) {
      enabled = false;
    }

    if (mounted) {
      setState(() => _notificationEnabled = enabled);
    }
  }

  Future<void> _handleAction() async {
    if (_notificationEnabled) {
      _close();
      return;
    }

    await AppSettings.openAppSettings(type: AppSettingsType.notification);
    await _refreshNotificationPermission();
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = math.max(0.0, constraints.maxWidth - 8);
          final availableHeight = math.max(0.0, constraints.maxHeight - 16);
          final scale = math
              .min(math.min(availableWidth / 360, availableHeight / 500), 1.2)
              .clamp(0.1, 1.2)
              .toDouble();

          return Center(
            child: SizedBox(
              width: 360 * scale,
              height: 500 * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: 360,
                  height: 500,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(
                        left: 20,
                        top: 136,
                        width: 320,
                        height: 364,
                        child: PCImg(name: 'pc_guide3_bg'),
                      ),
                      const Positioned(
                        left: 12,
                        top: 12,
                        width: 336,
                        height: 152,
                        child: PCImg(name: 'pc_congs_tops'),
                      ),
                      const Positioned(
                        left: 20,
                        top: 88,
                        width: 320,
                        height: 68,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xFFFDB907), width: 4),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF08712C), Color(0xFF044515)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 22,
                        right: 22,
                        top: 96,
                        height: 48,
                        child: Center(
                          child: PCStrokeText(
                            text: '🎉 Grow Bonus Activated!',
                            size: 24,
                            color: Color(0xFFFFE449),
                            weight: FontWeight.w900,
                            align: TextAlign.center,
                            skWidth: 1.5,
                            skColor: Color(0xFF3F2603),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 96,
                        top: 172,
                        width: 168,
                        height: 140,
                        child: PCImg(name: 'pc_big_icon_0'),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
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
                      const Positioned(
                        left: 30,
                        right: 30,
                        top: 316,
                        height: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PCStrokeText(
                              text: "You're saved ",
                              size: 20,
                              color: Color(0xFFFFF8CD),
                              weight: FontWeight.w900,
                              skWidth: 1.2,
                              skColor: Color(0xFF285200),
                            ),
                            PCStrokeText(
                              text: '\$30.0',
                              size: 20,
                              color: Color(0xFFFFC21D),
                              weight: FontWeight.w900,
                              skWidth: 1.2,
                              skColor: Color(0xFF285200),
                            ),
                            PCStrokeText(
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
                      const Positioned(
                        left: 44,
                        top: 352,
                        width: 272,
                        height: 40,
                        child: PCText(
                          text:
                              '💡 Come back tomorrow to feed your\npiggy again and get a +3% cash boost!',
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
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleAction,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: _notificationEnabled
                                    ? const PCImg(name: 'pc_btn_bg')
                                    : const _PCGuide3RedButton(),
                              ),
                              PCStrokeText(
                                text: _notificationEnabled
                                    ? 'Remind Me'
                                    : 'Go Earn',
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
}

class _PCGuide3RedButton extends StatelessWidget {
  const _PCGuide3RedButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFFCEE00), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: const Color(0xFFFC8900)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFAF0339), Color(0xFF740000)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFDA0041),
                blurRadius: 0,
                spreadRadius: -1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF890002), width: 3),
                gradient: const RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.8,
                  colors: [Color(0xFFE60045), Color(0xFF600018)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 转盘引导：高亮底部转盘入口并提示利息加成玩法。
class PCWheelGuideDialog extends StatelessWidget {
  const PCWheelGuideDialog({super.key});

  void _close(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: 360,
                height: 780,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 68,
                      top: 552,
                      width: 260,
                      height: 120,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: const Color(0xFFE09A46),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFAF6D5), Color(0xFFFFE59A)],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 26, 10, 8),
                          child: RichText(
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: text_fontName,
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9B620C),
                                decoration: TextDecoration.none,
                              ),
                              children: const [
                                TextSpan(text: 'Want Higher Earnings?\n'),
                                TextSpan(
                                  text: 'Spin the wheel to unlock up to ',
                                ),
                                TextSpan(
                                  text: '+50% interest bonus',
                                  style: TextStyle(
                                    color: Color(0xFF704300),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' in your savings. More bonus, faster withdrawals!',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 88,
                      top: 528,
                      width: 48,
                      height: 48,
                      child: PCImg(name: 'pc_ellipse_3', fit: BoxFit.contain),
                    ),
                    const Positioned(
                      left: 92,
                      top: 516,
                      width: 20,
                      height: 20,
                      child: PCImg(
                        name: 'pc_wheel_guide_crown',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 195,
                      top: 708,
                      width: 60,
                      height: 64,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _close(context),
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: const [
                            PCImg(
                              name: 'pc_wheel_n',
                              width: 44,
                              height: 44,
                              fit: BoxFit.contain,
                            ),
                            Positioned(
                              top: 36,
                              child: PCText(
                                text: 'Wheel',
                                size: 14,
                                color: Color(0xFF4FC931),
                                weight: FontWeight.w700,
                                align: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 231,
                      top: 688,
                      width: 60,
                      height: 60,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: -math.pi / 2,
                          child: const PCShouIcon(size: 60),
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
  }
}
