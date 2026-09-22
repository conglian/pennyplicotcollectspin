import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:provider/provider.dart';
import '../PCTool/PCPigWheelPage.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_text.dart';

final GlobalKey<PCWheelState> homeKey = GlobalKey<PCWheelState>();

class PCWheel extends StatefulWidget {
  PCWheel({super.key});

  @override
  State<PCWheel> createState() => PCWheelState();
}

class PCWheelState extends State<PCWheel> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              PCImg(
                name: 'pc_wheel_bg',
                width: 0.width(context),
                height: 0.height(context),
              ),
              Column(
                children: [
                  SizedBox(height: 64.h),
                  SizedBox(
                    width: 328.w,
                    height: 112.w,
                    child: _buildWheelTopCard(provider),
                  ),
                  SizedBox(height: 44.h),
                  SizedBox(
                    width: 360.w,
                    height: 360.w + 28.h,
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 0,
                          child: PCImg(
                            name: 'pc_bottom_money',
                            width: 360.w,
                            height: 112.w,
                          ),
                        ),
                        ParticleButton(
                          onTap: () {
                            tapWheelEvent();
                          },
                          child: SizedBox(
                            width: 360.w,
                            height: 360.w,
                            child: PCPigWheelPage(imagePath: 'pc_wheel_center'),
                          ),
                        ),
                        Positioned(
                          left: (360.w - 38) * 0.5,
                          top: 12.h,
                          child: PCImg(
                            name: 'pc_rectangle_icon',
                            width: 38,
                            height: 36,
                          ),
                        ),
                        Positioned(
                          top: 130.h,
                          left: (360.w - 100) * 0.5,
                          child: ParticleButton(
                            child: PCImg(
                              name: 'pc_go_btn',
                              width: 100,
                              height: 100,
                            ),
                            onTap: () {
                              tapWheelEvent();
                            },
                          ),
                        ),
                        Positioned(
                          left: (360.w - 56) * 0.6,
                          top: 120.h,
                          child: SizedBox(
                            width: 56,
                            height: 36,
                            child: Stack(
                              children: [
                                PCImg(name: 'pc_num_bg'),
                                Center(
                                  child: PCStrokeText(
                                    text: '×${provider.pc_wheel_number}',
                                    size: 16,
                                    color: '#FFDD1D'.color(),
                                    weight: FontWeight.w700,
                                    skWidth: 1,
                                    skColor: '#5D0D03'.color(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 20,
                top: 194.h,
                child: ParticleButton(
                  onTap: () {
                    PigsTabController.switchTo(1);
                  },
                  child: const PCBouncyImage(
                    imagePath: 'pc_quiz_icon',
                    width: 64,
                    height: 64,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void tapWheelEvent() {
    WheelStartNotificationService.sendToStartIndexNotification(1);
  }

  Widget _buildWheelTopCard(PCLocalProvider provider) {
    const double withdrawTarget = 100;
    final double balance = provider.pc_dollar_number;
    final double progress = (balance / withdrawTarget).clamp(0.0, 1.0);
    final int collected = provider.pc_domand_number;
    final int left = provider.pc_wheel_number;

    return Container(
      width: 328.w,
      height: 112.w,
      decoration: BoxDecoration(image: PCDImg('pc_wheel_top_bg')),
      child: Stack(
        children: [
          Positioned(
            left: 12.w,
            top: 10.w,
            width: 48,
            height: 40,
            child: PCImg(name: 'pc_pig_top_2', width: 48, height: 40),
          ),
          Positioned(
            left: 64.w,
            top: 20.w,
            width: 178.w,
            height: 16.w,
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: '#003F00'.color(),
                borderRadius: BorderRadius.circular(8.w),
                border: Border.all(color: '#002700'.color(), width: 1.w),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.w),
                child: ColoredBox(
                  color: '#1162F9'.color(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.1,
                      heightFactor: 1,
                      child: ColoredBox(color: '#2EEFFC'.color()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 64.w + (178.w * progress) - 10.w,
            top: 17.w,
            width: 20.w,
            height: 20.w,
            child: PCImg(name: 'pc_domand_icons', width: 20.w, height: 20.w),
          ),
          Positioned(
            left: 64.w,
            top: 20.w,
            width: 178.w,
            height: 16.w,
            child: Center(
              child: PCText(
                text: '\$${balance.toStringAsFixed(0)}/\$100',
                size: 11,
                color: Colors.white,
                weight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            right: 12.w,
            top: 17.w,
            width: 72.w,
            height: 24.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PCImg(name: 'pc_pp_bg', width: 72.w, height: 24.w),
                Positioned(
                  left: 5.w,
                  child: PCImg(name: 'pc_paypal_0', width: 20.w, height: 20.w),
                ),
                Positioned(
                  right: 7.w,
                  child: PCStrokeText(
                    text: '\$100',
                    size: 12,
                    color: '#FFAF00'.color(),
                    weight: FontWeight.w700,
                    skWidth: 1,
                    skColor: '#624500'.color(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 45.w,
            child: PCText(
              text: "Money's in-ready to withdraw!",
              size: 11,
              color: Colors.white,
              weight: FontWeight.w600,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 12.w,
            right: 12.w,
            top: 70.w,
            height: 30.w,
            child: Container(
              decoration: BoxDecoration(
                color: '#004B05'.color(),
                borderRadius: BorderRadius.circular(6.w),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDiamondStat('Collected:', collected),
                  Container(width: 1.w, height: 18.w, color: '#1B6C20'.color()),
                  _buildDiamondStat('Left:', left),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiamondStat(String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PCText(
          text: '$label $value',
          size: 10,
          color: Colors.white,
          weight: FontWeight.w500,
        ),
        SizedBox(width: 3.w),
        PCImg(name: 'pc_act_1', width: 14.w, height: 14.w),
      ],
    );
  }
}
