import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCOtherDialogWidgets.dart';

/// 通知权限开启引导弹窗（Turn On Push Notifications）。
///
/// 点击 Go And Open 跳转系统通知设置，返回后由召回入口重新检查权限；关闭按钮仅关闭本次引导。
class PCPushNotificationDialog extends StatelessWidget {
  const PCPushNotificationDialog({super.key, this.onOpen});
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return PCResponsiveDialog(
      designHeight: 372,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 20,
            top: 4,
            width: 320,
            height: 368,
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
                text: 'Turn On Push Notifications',
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
                      'Keep your earnings safe—get notified when it’s time to cash out',
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
              text: 'Go And Open',
              onTap:
                  onOpen ??
                  () => AppSettings.openAppSettings(
                    type: AppSettingsType.notification,
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
