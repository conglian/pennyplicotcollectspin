import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../PCTool/PCAudioUtils.dart';
import '../../PCTool/PCPigMotion.dart';
import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideDepositCash.dart';
import 'PCGuideLayout.dart';

/// 引导7：首笔签到奖励到账，使用本地钞票动画飞向存钱罐。
///
/// 两秒后返回调度器，再展示首笔佣金说明；计时器随弹窗释放。
class PCGuide1Dialog extends StatefulWidget {
  const PCGuide1Dialog({super.key, this.depositAmount = 6});
  final double depositAmount;

  @override
  State<PCGuide1Dialog> createState() => PCGuide1DialogState();
}

class PCGuide1DialogState extends State<PCGuide1Dialog> {
  Timer? _nextGuideTimer;
  ModalRoute<dynamic>? _dialogRoute;

  @override
  void initState() {
    super.initState();
    // 签到已成功到账，奖励层首次出现时播放；后续重建不重复播放。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        unawaited(PCAudioUtils().playRewardAudio());
      }
    });
    _nextGuideTimer = Timer(const Duration(seconds: 2), _showNextGuide);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dialogRoute ??= ModalRoute.of(context);
  }

  Future<void> _showNextGuide() async {
    if (mounted && (_dialogRoute?.isCurrent ?? false))
      Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nextGuideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Rect pigRect = pcHomePigRect(context);
    final Size screenSize = MediaQuery.sizeOf(context);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: pigRect.left,
          top: pigRect.top,
          width: pigRect.width,
          height: pigRect.height,
          child: const PCPigMotion.hero(child: PCImg(name: 'pc_big_b_0')),
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
                  left: 0,
                  top: 58.h,
                  child: PCImg(
                    name: 'pc_bottom_money',
                    width: 304.w,
                    height: (304 * 220 / 720).h,
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
                          text: '+\$${widget.depositAmount.toStringAsFixed(2)}',
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
        Positioned(
          left: 0,
          top: 0,
          width: screenSize.width,
          height: screenSize.width * 1110 / 940,
          child: PCGuideDepositCash(
            start: Offset(screenSize.width * .5 - 70.w, 390.h),
            destination: Offset(
              pigRect.left + pigRect.width * .2,
              pigRect.center.dy,
            ),
          ),
        ),
      ],
    );
  }
}
