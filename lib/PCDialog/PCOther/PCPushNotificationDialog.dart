import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCOtherDialogWidgets.dart';

/// 通知权限引导弹窗（Don't miss your cash）。
///
/// 点击 Enable Notifications 请求系统通知权限；Later 和关闭按钮仅关闭本次引导。
class PCPushNotificationDialog extends StatelessWidget {
  const PCPushNotificationDialog({super.key, this.onOpen});
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return PCResponsiveDialog(
      designHeight: 408,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 20,
            top: 4,
            width: 320,
            height: 400,
            child: PCImg(name: 'pc_guide3_bg'),
          ),
          const Positioned(
            left: 100,
            top: 20,
            width: 160,
            height: 160,
            child: PCFigmaIcon(
              name: 'pc_push_notice_2x',
              imageSize: 234,
              imageLeft: -34,
              imageTop: -34,
            ),
          ),
          const Positioned(
            left: 34,
            right: 34,
            top: 184,
            height: 28,
            child: Center(
              child: PCStrokeText(
                text: "Don't miss your cash",
                size: 20,
                color: Color(0xFFFFF28B),
                weight: FontWeight.w900,
                align: TextAlign.center,
                skWidth: 1.2,
                skColor: Color(0xFF285200),
              ),
            ),
          ),
          const Positioned(
            left: 44,
            top: 220,
            width: 272,
            height: 56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 272,
                child: PCText(
                  key: ValueKey('pcNotificationRecallSubtitle'),
                  text:
                      "Keep your earnings updated — get notified when it's time to cash out",
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w500,
                  align: TextAlign.center,
                  maxLines: 4,
                  height: 1.25,
                ),
              ),
            ),
          ),
          Positioned(
            left: 46,
            top: 284,
            width: 268,
            height: 64,
            child: PCGreenDialogButton(
              key: const ValueKey('pcNotificationRecallOpen'),
              text: 'Enable Notifications',
              onTap:
                  onOpen ??
                  () => AppSettings.openAppSettings(
                    type: AppSettingsType.notification,
                  ),
            ),
          ),
          Positioned(
            left: 46,
            top: 350,
            width: 268,
            height: 44,
            child: GestureDetector(
              key: const ValueKey('pcNotificationRecallLater'),
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const Center(
                child: PCText(
                  text: 'Later',
                  size: 16,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: -4,
            width: 48,
            height: 48,
            child: PCDialogCloseButton(
              key: const ValueKey('pcNotificationRecallClose'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
