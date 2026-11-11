import '../../PCTool/PCAnalytics.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import 'PCOtherDialogWidgets.dart';

/// 转盘次数不足弹窗（No More Chance）。
/// 点击底部Get By Quiz返回true，由转盘页关闭弹窗后切到答题页；关闭按钮仅关闭。
class PCWheelNoChanceDialog extends StatelessWidget {
  const PCWheelNoChanceDialog({super.key});
  @override
  Widget build(BuildContext context) => PCResponsiveDialog(
    designHeight: 428,
    child: Stack(
      children: [
        const Positioned(
          left: 20,
          top: 124,
          width: 320,
          height: 304,
          child: PCImg(name: 'pc_wheel_empty_panel'),
        ),
        const Positioned(
          left: 12,
          top: 0,
          width: 336,
          height: 152,
          child: PCImg(name: 'pc_wheel_empty_title'),
        ),
        const Positioned(
          left: 100,
          top: 160,
          width: 160,
          height: 160,
          child: PCImg(name: 'pc_wheel_empty_glow'),
        ),
        const Positioned(
          left: 100,
          top: 160,
          width: 160,
          height: 160,
          child: PCImg(name: 'pc_wheel_empty_icon'),
        ),
        const Positioned(
          left: 260,
          top: 280,
          child: PCStrokeText(
            text: '×1',
            size: 28,
            color: Color(0xFFFFDF28),
            weight: FontWeight.w900,
            skWidth: 1,
            skColor: Color(0xFF624500),
          ),
        ),
        Positioned(
          left: 46,
          top: 340,
          width: 268,
          height: 64,
          child: PCGreenDialogButton(
            text: 'Get By Quiz',
            onTap: () {
              PCAnalytics.event('no_chance_pop_c');
              Navigator.of(context).pop(true);
            },
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          width: 48,
          height: 48,
          child: PCDialogCloseButton(
            onTap: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    ),
  );
}
