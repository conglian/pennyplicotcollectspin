import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'PCNoticeHelp.dart';

/// 提现倒计时的通知权限入口：只在用户点击提醒按钮时申请权限。
/// 查询失败、拒绝或不支持通知均返回false，不能显示成已开启。
class PCWithdrawalNotifications {
  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final status = await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return (status?.isEnabled ?? false) ||
            (status?.isProvisionalEnabled ?? false);
      }
    } catch (_) {
      // 下次回前台再检查，避免临时插件错误被记录成永久授权。
    }
    return false;
  }

  static Future<bool> request() async {
    if (kIsWeb) return false;
    try {
      await PCNoticeHelp.instance.initialize();
      final plugin = FlutterLocalNotificationsPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      final enabled = await isEnabled();
      if (enabled) await PCNoticeHelp.instance.refreshSchedules();
      return enabled;
    } catch (_) {
      return false;
    }
  }
}
