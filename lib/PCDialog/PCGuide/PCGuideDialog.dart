import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCPigMotion.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_stroke_text.dart';
import 'PCGuideLayout.dart';
import 'PCGuideIdentity.dart';

// 兼容原有引导弹窗引用；各步骤和转盘引导在同名文件中独立维护。
export 'PCGuide0Dialog.dart';
export 'PCGuide1Dialog.dart';
export 'PCGuide2Dialog.dart';
export 'PCGuide3Dialog.dart';
export 'PCWheelGuideDialog.dart';
export 'PCGuide1Page.dart';
export 'PCGuide2Page.dart';
export 'PCGuide3Page.dart';
export 'PCNewUserGuideFlow.dart';

/// 引导4：榜首用户介绍（Try It Now）。
/// 点击或停留两秒切换第二段对白；继续后交给控制器进入签到引导。
class PCGuideDialog extends StatefulWidget {
  const PCGuideDialog({super.key});
  @override
  State<PCGuideDialog> createState() => _PCGuideDialogState();
}

class _PCGuideDialogState extends State<PCGuideDialog> {
  bool _second = false;
  Timer? _timer;
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
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _second = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _leaving = false;
  void _openGuide(BuildContext context) {
    if (_leaving || ModalRoute.of(context)?.isCurrent != true) return;
    _leaving = true;
    PCAnalytics.event('new_home_guide_c');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect pigRect = pcHomePigRect(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_second) {
          setState(() => _second = true);
        } else {
          _openGuide(context);
        }
      },
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pigRect.left,
              top: pigRect.top,
              width: pigRect.width,
              height: pigRect.height,
              child: const PCPigMotion.hero(
                child: PCImg(name: 'pc_big_icon_0'),
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
              left: 24.w,
              top: 416.h,
              child: _GuideSpeechCard(second: _second),
            ),
            Positioned(
              left: (screenSize.width - 268.w) / 2,
              top: 580.h,
              child: ParticleButton(
                onTap: () => _openGuide(context),
                child: const _GuideActionButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSpeechCard extends StatelessWidget {
  const _GuideSpeechCard({required this.second});
  final bool second;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260.w,
      height: 116.h,
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
              maxLines: 4,
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
                  TextSpan(
                    text: second
                        ? 'You wanna know how I did it? 👉 Let me show you. It’s easy — we earn money by watching ads.'
                        : 'Hey, I’m Jason. Just last week, I cashed out \$100 from this app.',
                  ),
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
                child: PCImg(name: pcGuideAvatarAsset, fit: BoxFit.cover),
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
