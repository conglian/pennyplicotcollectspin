import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCPigMotion.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideLayout.dart';

/// 引导8：首笔佣金到账说明（Keep Earning）。
///
/// 金额由已入账奖励和提现门槛计算；继续后进入三题引导。
class PCGuide2Dialog extends StatelessWidget {
  const PCGuide2Dialog({
    super.key,
    this.depositAmount = 6,
    this.remainingAmount = 94,
  });
  final double depositAmount;
  final double remainingAmount;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final Rect pigRect = pcHomePigRect(context);

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
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
                    width: 76.w,
                    height: 56.h,
                    child: const PCPigMotion.hero(
                      child: PCImg(name: 'pc_pig_fendoalldr'),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 123.h,
                    child: PCStrokeText(
                      text:
                          'Deposit amount: \$${depositAmount.toStringAsFixed(2)}',
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
                            text: '\$${remainingAmount.toStringAsFixed(2)}',
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
                      onTap: () {
                        if (ModalRoute.of(context)?.isCurrent != true) return;
                        PCAnalytics.event('new_first_prize_pop_c');
                        Navigator.of(context).pop();
                      },
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
                              text: 'Keep Earning',
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
