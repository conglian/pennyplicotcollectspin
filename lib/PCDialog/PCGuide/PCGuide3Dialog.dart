import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'PCGrowBonusContent.dart';
import '../../PCTool/PCAnalytics.dart';

/// 引导13：成长奖励激活与通知权限弹窗（Grow Bonus Activated）。
///
/// 未开启通知时 Reminder Me 请求系统权限；已开启时 Go Earn 继续。
/// 从系统设置返回应用时，重新检查通知权限并刷新按钮状态。
class PCGuide3Dialog extends StatefulWidget {
  const PCGuide3Dialog({super.key, this.savedAmount = 0, this.growPercent = 3});
  final double savedAmount;
  final double growPercent;

  @override
  State<PCGuide3Dialog> createState() => _PCGuide3DialogState();
}

class _PCGuide3DialogState extends State<PCGuide3Dialog>
    with WidgetsBindingObserver {
  bool _notificationEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationPermission();
    }
  }

  Future<void> _refreshNotificationPermission() async {
    bool enabled = false;
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        enabled =
            await notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final permission = await notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        enabled =
            (permission?.isEnabled ?? false) ||
            (permission?.isProvisionalEnabled ?? false);
      }
    } catch (_) {
      enabled = false;
    }

    if (mounted) {
      setState(() => _notificationEnabled = enabled);
    }
  }

  bool _handling = false;
  Future<void> _handleAction() async {
    if (_handling) return;
    _handling = true;
    PCAnalytics.event('grow_bonus_pop_c', {'pop_from': 'new'});
    try {
      if (!_notificationEnabled && !kIsWeb) {
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
      }
    } catch (_) {
      // 系统不支持或用户拒绝时仍继续，不强制跳设置页。
    } finally {
      if (mounted) _close();
    }
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) => PCGrowBonusContent(
    savedAmount: widget.savedAmount,
    growPercent: widget.growPercent,
    actionLabel: _notificationEnabled ? 'Go Earn' : 'Reminder Me',
    redButton: _notificationEnabled,
    onAction: _handleAction,
    onClose: _close,
  );
}
