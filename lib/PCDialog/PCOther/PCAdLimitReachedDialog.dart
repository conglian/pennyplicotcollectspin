import 'package:flutter/material.dart';

import 'PCOtherDialogWidgets.dart';
import '../../PCTool/PCAnalytics.dart';

/// 当天广告观看次数已达上限弹窗（Got It）。
///
/// 提示明天再来；点击 Got It 或关闭按钮均关闭当前弹窗。
class PCAdLimitReachedDialog extends StatelessWidget {
  const PCAdLimitReachedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PCAnalyticsExposure(
      event: 'ad_limit_pop',
      child: PCAdStatusDialog(
        titleAssetName: 'pc_ad_limit_title_2x',
        iconName: 'pc_ad_limit_2x',
        canvasHeight: 472,
        panelHeight: 348,
        buttonTop: 384,
        iconWidth: 188,
        iconHeight: 160,
        iconLeft: 86,
        iconTop: 160,
        imageSize: 218,
        imageLeft: -15,
        imageTop: -19,
        description:
            "You've watched all available ads for today.\nTry again tomorrow.",
        descriptionTop: 324,
        buttonText: 'Got It',
        onButtonTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
