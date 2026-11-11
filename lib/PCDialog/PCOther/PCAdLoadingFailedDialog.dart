import 'package:flutter/material.dart';

import 'PCOtherDialogWidgets.dart';
import '../../PCTool/PCAnalytics.dart';

/// 广告加载失败弹窗（Try Again）。
///
/// Try Again与关闭按钮都只关闭当前弹窗，不立即播放或重新请求广告。
/// 任务弹窗内的失败状态可通过[onClose]统一退出原任务路由。
class PCAdLoadingFailedDialog extends StatelessWidget {
  const PCAdLoadingFailedDialog({super.key, this.onClose});

  final VoidCallback? onClose;

  void _close(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final close = onClose;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PCAnalyticsExposure(
      event: 'ad_fail_pop',
      child: PCAdStatusDialog(
        titleAssetName: 'pc_ad_load_title_2x',
        iconName: 'pc_ad_load_failed_2x',
        canvasHeight: 428,
        panelHeight: 304,
        buttonTop: 340,
        iconWidth: 160,
        iconHeight: 160,
        iconLeft: 100,
        iconTop: 160,
        imageSize: 218,
        imageLeft: -28,
        imageTop: -19,
        buttonText: 'Try Again',
        onClose: () => _close(context),
        onButtonTap: () => _close(context),
      ),
    );
  }
}
