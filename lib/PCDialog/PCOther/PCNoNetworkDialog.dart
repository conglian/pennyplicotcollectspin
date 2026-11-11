import 'package:flutter/material.dart';

import 'PCOtherDialogWidgets.dart';
import '../../PCTool/PCAnalytics.dart';

/// 无网络提示弹窗（Got It）。
///
/// 提醒用户检查网络；点击 Got It 或关闭按钮均关闭当前弹窗。
class PCNoNetworkDialog extends StatelessWidget {
  const PCNoNetworkDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PCAnalyticsExposure(
      event: 'no_network_pop',
      child: PCAdStatusDialog(
        titleAssetName: 'pc_no_network_title_2x',
        iconName: 'pc_no_network_2x',
        canvasHeight: 428,
        panelHeight: 304,
        buttonTop: 340,
        iconWidth: 160,
        iconHeight: 160,
        iconLeft: 100,
        iconTop: 160,
        imageSize: 215,
        imageLeft: -27,
        imageTop: -26,
        buttonText: 'Got It',
        onButtonTap: () => Navigator.of(context).pop(),
      ),
    );
  }
}
