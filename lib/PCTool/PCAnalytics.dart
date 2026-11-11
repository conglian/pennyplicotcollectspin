import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCTBAEventTool.dart';

/// 产品事件统一使用本地TBA协议；业务不接触请求参数混淆和设备信息。
abstract final class PCAnalytics {
  @visibleForTesting
  static void Function(String, Map<String, dynamic>) reporter = pc_event_fire;
  @visibleForTesting
  static Future<void> Function() installReporter = pc_install_fire;
  @visibleForTesting
  static Future<void> Function() sessionReporter = pc_session_fire;

  static void event(String name, [Map<String, dynamic> parameters = const {}]) {
    try {
      reporter(name.trim(), Map<String, dynamic>.of(parameters));
    } catch (_) {
      // 统计失败不能阻断按钮、领奖及流程状态的持久化。
    }
  }

  static Future<void> _milestones = Future<void>.value();
  static const cashMilestoneKey = 'pc_tba_cash_milestone_v1';
  static const adMilestoneKey = 'pc_tba_ad_milestone_v1';
  static const installKey = 'pc_tba_install_reported_v1';
  static const notificationSeenKey = 'pc_tba_notification_seen_v1';
  static const _notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  static Future<void>? _notificationFlush;

  static Future<void> _serial(Future<void> Function() action) {
    _milestones = _milestones.then((_) => action()).catchError((Object _) {});
    return _milestones;
  }

  static Future<void> cashChanged() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.get('pc_dollar_number');
    if (balance is! num || !balance.isFinite || balance < 5) return;
    await _reportMilestones(
      prefs,
      cashMilestoneKey,
      (balance / 5).floor(),
      'cash_money_detail',
      'money_from',
    );
  });

  /// 仅广告SDK真实展示成功调用；跳过广告不计入累计观看档位。
  static Future<void> adDisplayed({int? count}) => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    final total = count ?? prefs.getInt('pc_ad_show_number') ?? 0;
    await _reportMilestones(
      prefs,
      adMilestoneKey,
      total ~/ 5,
      'cash_ad_detail',
      'ad_from',
    );
  });

  static Future<void> _reportMilestones(
    SharedPreferences prefs,
    String key,
    int reached,
    String name,
    String attribute,
  ) async {
    final previous = prefs.getInt(key) ?? 0;
    for (var step = previous + 1; step <= reached; step++) {
      if (!await prefs.setInt(key, step)) return;
      event(name, {attribute: step * 5});
    }
  }

  static Future<void> install() => _serial(() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(installKey) ?? false) return;
    final existingInstallation = prefs.containsKey('pc_install_status');
    if (!await prefs.setBool(installKey, true)) return;
    // 升级已有存档不能重新算安装；网络上报不能阻塞首次进入应用。
    if (!existingInstallation) unawaited(installReporter());
  });

  static Future<void> session() => sessionReporter();

  /// 原生后台只记录真正分发的通知；Flutter恢复后复用本地TBA上传并按ID确认。
  static Future<void> flushNotificationTriggers() =>
      _notificationFlush ??= _flushNotificationTriggers().whenComplete(() {
        _notificationFlush = null;
      });

  static Future<void> _flushNotificationTriggers() async {
    try {
      final rows = await _notificationChannel
          .invokeListMethod<dynamic>('getPendingNotificationAnalytics')
          .timeout(const Duration(seconds: 3));
      if (rows == null || rows.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getStringList(notificationSeenKey) ?? []).toSet();
      final acknowledgements = <String>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final id = row['eventId'];
        final type = row['type'];
        if (id is! String ||
            id.isEmpty ||
            !const {'local', 'unlock', 'fcm'}.contains(type)) {
          continue;
        }
        acknowledgements.add(id);
        // FCM由后台口径统计；兼容清理升级前已经落盘的FCM记录。
        if (type == 'fcm') continue;
        if (!seen.add(id)) continue;
        final latest = seen.toList();
        if (!await prefs.setStringList(
          notificationSeenKey,
          latest.skip(latest.length > 512 ? latest.length - 512 : 0).toList(),
        )) {
          return;
        }
        event('inform_p', {'type': type});
      }
      if (acknowledgements.isNotEmpty) {
        await _notificationChannel.invokeMethod<void>(
          'ackNotificationAnalytics',
          {'eventIds': acknowledgements},
        );
      }
    } catch (_) {
      // 没有原生桥或确认失败时保留原生队列，下次恢复继续；已提交ID不重复发送。
    }
  }

  @visibleForTesting
  static Future<void> flush() => _milestones;

  @visibleForTesting
  static void resetForTesting() {
    reporter = pc_event_fire;
    installReporter = pc_install_fire;
    sessionReporter = pc_session_fire;
    _milestones = Future<void>.value();
    _notificationFlush = null;
  }
}

/// 路由中的真实曝光：首帧展示时上报，父组件重建不会重复产生曝光。
class PCAnalyticsExposure extends StatefulWidget {
  const PCAnalyticsExposure({
    super.key,
    required this.event,
    required this.child,
    this.parameters = const {},
  });
  final String event;
  final Map<String, dynamic> parameters;
  final Widget child;

  @override
  State<PCAnalyticsExposure> createState() => _PCAnalyticsExposureState();
}

class _PCAnalyticsExposureState extends State<PCAnalyticsExposure> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      PCAnalytics.event(widget.event, widget.parameters);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
