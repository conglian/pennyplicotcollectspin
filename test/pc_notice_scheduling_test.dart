import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeHelp.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeMessage.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

/// 用原生通道的有状态替身验证计划恢复，不依赖 Firebase 或系统计时。
class _NotificationBackend {
  final calls = <MethodCall>[];
  final scheduled = <int, Map<Object?, Object?>>{};
  final channels = <String, Map<Object?, Object?>>{};
  final active = <int, Map<Object?, Object?>>{};
  final topics = <String, Map<Object?, Object?>>{};
  final broadcasts = <int, Map<Object?, Object?>>{};
  bool notificationsEnabled = true;
  Future<bool?> Function()? requestPermission;

  Iterable<MethodCall> called(String method) =>
      calls.where((call) => call.method == method);

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    final args = call.arguments;
    switch (call.method) {
      case 'initialize':
        return true;
      case 'areNotificationsEnabled':
        return notificationsEnabled;
      case 'requestNotificationsPermission':
        return await requestPermission?.call() ?? notificationsEnabled;
      case 'getNotificationAppLaunchDetails':
        return {'notificationLaunchedApp': false};
      case 'getActiveNotifications':
        return active.values.toList();
      case 'getNotificationChannels':
        return channels.values.toList();
      case 'pendingNotificationRequests':
        return scheduled.values
            .map(
              (item) => {
                'id': item['id'],
                'title': item['title'],
                'body': item['body'],
                'payload': item['payload'],
              },
            )
            .toList();
      case 'createNotificationChannel':
        final data = Map<Object?, Object?>.from(args as Map);
        channels[data['id']! as String] = data;
        return null;
      case 'zonedSchedule':
        final data = Map<Object?, Object?>.from(args as Map);
        scheduled[data['id']! as int] = data;
        return null;
      case 'startForegroundService':
        final data = Map<Object?, Object?>.from(
          (args as Map)['notificationData'] as Map,
        );
        active[data['id']! as int] = data;
        return null;
      case 'show':
        final data = Map<Object?, Object?>.from(args as Map);
        active[data['id']! as int] = data;
        return null;
      case 'stopForegroundService':
        active.remove(1200);
        return null;
      case 'showBroadcastNotification':
        final data = Map<Object?, Object?>.from(args as Map);
        broadcasts[data['id']! as int] = data;
        return null;
      case 'subscribeToTopic':
        final data = Map<Object?, Object?>.from(args as Map);
        topics[data['topic']! as String] = data;
        return true;
      case 'unsubscribeFromTopic':
        topics.remove((args as Map)['topic']);
        return true;
      case 'cancel':
        final id = args is int ? args : (args as Map)['id'] as int;
        scheduled.remove(id);
        active.remove(id);
        broadcasts.remove(id);
        return null;
      case 'cancelAll':
        scheduled.clear();
        active.clear();
        broadcasts.clear();
        return null;
      default:
        return null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const fixedIds = {5590, 4562, 7552, 9475};
  const mediaIds = {4738, 2788, 2934, 1320};
  late _NotificationBackend backend;
  final helpers = <PCNoticeHelp>[];

  PCNoticeHelp create({
    bool Function()? guide,
    Future<bool> Function()? permission,
    double Function()? balance,
    Map<String, String>? topics,
    Duration startupPermissionTimeout = PCNoticeHelp.startupPermissionLimit,
  }) {
    final helper = PCNoticeHelp.testing(
      isGuideComplete: guide ?? () => true,
      permissionEnabled: permission ?? () async => true,
      balance: balance ?? () => 59,
      target: () => 100,
      fcmTopics: topics,
      startupPermissionTimeout: startupPermissionTimeout,
    );
    helpers.add(helper);
    return helper;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _NotificationBackend();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, backend.handle);
  });

  tearDown(() async {
    for (final helper in helpers) {
      helper.dispose();
    }
    helpers.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('启动未授权只申请一次，申请完成前等待召回并持有弹窗展示权', () async {
    backend.notificationsEnabled = false;
    final permission = Completer<bool>();
    final requested = Completer<void>();
    backend.requestPermission = () {
      requested.complete();
      return permission.future;
    };
    final notice = create(permission: () async => backend.notificationsEnabled);
    final holds = PCDialogCoordinator.instance.holdCount;
    final startup = notice.initializeForStartup();
    expect(identical(startup, notice.initializeForStartup()), true);
    await requested.future;
    expect(PCDialogCoordinator.instance.holdCount, holds + 1);
    var waited = false;
    final waiting = notice.waitForStartupPermission().then(
      (_) => waited = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(waited, false);
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    backend.notificationsEnabled = true;
    permission.complete(true);
    await startup;
    await waiting;
    expect(waited, true);
    expect(PCDialogCoordinator.instance.holdCount, holds);
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    expect(
      backend.topics.keys,
      unorderedEquals(['c177fcm_piggy', 'c177fcm_piggy_two']),
    );
    await notice.initializeForStartup();
    await notice.refreshSchedules();
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
  });

  test('启动已授权直接恢复通知计划，不重复申请权限或安排已有通知', () async {
    final notice = create(permission: () async => backend.notificationsEnabled);
    await notice.initializeForStartup();
    expect(backend.called('requestNotificationsPermission'), isEmpty);
    expect(backend.scheduled, hasLength(8));
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect(backend.called('startForegroundService'), hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    final originalPlan = prefs.getString('pc_notification_plan_v3');
    notice.dispose();
    helpers.remove(notice);
    await create(
      permission: () async => backend.notificationsEnabled,
    ).initializeForStartup();
    expect(backend.called('requestNotificationsPermission'), isEmpty);
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect(prefs.getString('pc_notification_plan_v3'), originalPlan);
  });

  test('系统权限回调失联8秒有界放行并释放锁，晚成功恢复计划且不重复请求', () async {
    backend.notificationsEnabled = false;
    final permission = Completer<bool>();
    final requested = Completer<void>();
    backend.requestPermission = () {
      requested.complete();
      return permission.future;
    };
    final notice = create(
      permission: () async => backend.notificationsEnabled,
      startupPermissionTimeout: const Duration(milliseconds: 20),
    );
    final holds = PCDialogCoordinator.instance.holdCount;
    final startup = notice.initializeForStartup();
    await requested.future;
    expect(notice.isStartupPermissionRequestPending, true);
    expect(PCDialogCoordinator.instance.holdCount, holds + 1);
    await startup;
    await notice.waitForStartupPermission();
    expect(PCDialogCoordinator.instance.holdCount, holds);
    expect(notice.isStartupPermissionRequestPending, true);
    expect(backend.notificationsEnabled, false);
    expect(backend.scheduled, isEmpty);
    await notice.initializeForStartup();
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    backend.notificationsEnabled = true;
    permission.complete(true);
    for (var i = 0; i < 50 && backend.scheduled.length < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(notice.isStartupPermissionRequestPending, false);
    expect(notice.startupPermissionChanges.value, 1);
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    expect(PCDialogCoordinator.instance.holdCount, holds);
  });

  test('初始化失联后不再补发系统窗口，释放展示锁且后续授权仍可恢复计划', () async {
    backend.notificationsEnabled = false;
    final initialize = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          if (call.method == 'initialize') return initialize.future;
          return backend.handle(call);
        });
    final notice = create(
      permission: () async => backend.notificationsEnabled,
      startupPermissionTimeout: const Duration(milliseconds: 20),
    );
    final holds = PCDialogCoordinator.instance.holdCount;
    await notice.initializeForStartup();
    expect(PCDialogCoordinator.instance.holdCount, holds);
    expect(notice.isStartupPermissionRequestPending, false);
    expect(backend.called('requestNotificationsPermission'), isEmpty);
    initialize.complete(true);
    for (var i = 0; i < 50 && notice.startupPermissionChanges.value == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(notice.startupPermissionChanges.value, 1);
    expect(backend.called('requestNotificationsPermission'), isEmpty);
    backend.notificationsEnabled = true;
    await notice.refreshSchedules();
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    expect(PCDialogCoordinator.instance.holdCount, holds);
  });

  test('启动拒绝后同次不重复申请，设置开启再回前台恢复全部通知', () async {
    backend.notificationsEnabled = false;
    backend.requestPermission = () async => false;
    final notice = create(permission: () async => backend.notificationsEnabled);
    await notice.initializeForStartup();
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    expect(backend.scheduled, isEmpty);
    expect(backend.active, isEmpty);
    expect(backend.topics, isEmpty);
    await notice.initializeForStartup();
    await notice.refreshSchedules();
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    notice.didChangeAppLifecycleState(AppLifecycleState.paused);
    backend.notificationsEnabled = true;
    notice.didChangeAppLifecycleState(AppLifecycleState.resumed);
    // 回前台的刷新通过原生通道异步完成，不重新申请系统权限。
    for (var index = 0; index < 20 && backend.broadcasts.length != 2; index++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    expect(backend.broadcasts.keys, unorderedEquals([2829, 1029]));
    expect(
      backend.topics.keys,
      unorderedEquals(['c177fcm_piggy', 'c177fcm_piggy_two']),
    );
  });

  test('未启动时等待接口不申请权限，启动申请异常也释放展示权且下次冷启可重试', () async {
    backend.notificationsEnabled = false;
    backend.requestPermission = () async =>
        throw PlatformException(code: 'NO_PERMISSION_UI');
    final notice = create(permission: () async => backend.notificationsEnabled);
    await notice.waitForStartupPermission();
    expect(backend.calls, isEmpty);
    final holds = PCDialogCoordinator.instance.holdCount;
    await notice.initializeForStartup();
    expect(PCDialogCoordinator.instance.holdCount, holds);
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    await notice.initializeForStartup();
    expect(backend.called('requestNotificationsPermission'), hasLength(1));
    notice.dispose();
    helpers.remove(notice);
    backend.requestPermission = () async => false;
    await create(
      permission: () async => backend.notificationsEnabled,
    ).initializeForStartup();
    expect(backend.called('requestNotificationsPermission'), hasLength(2));
    expect(PCDialogCoordinator.instance.holdCount, holds);
  });

  test('五组通知文案逐字对应确认稿，仅 saved 金额按实时余额替换', () {
    const expected = [
      ('Piggy Almost Full!', 'You’ve saved \$4.80—cash out before it spills!'),
      ('Cash-Out Time 🎉', 'Spin & play—your balance is ready to grab!'),
      (
        'Your Payout Is Ready! 💰',
        'Piggy bank is full and ready to pop—open the app to collect your cash.',
      ),
      (
        'Advertiser Just Paid You! 🎁',
        'Tap to feed your piggy & claim today’s payout.',
      ),
      ('Balance Near Max 💵', 'Almost full—withdraw before it’s gone!'),
    ];
    expect(PCStepMotivationManager.templateCount, expected.length);
    for (var index = 0; index < expected.length; index++) {
      final copy = PCStepMotivationManager.PC_getMotivation(
        index,
        balance: 4.8,
      );
      expect((copy.title, copy.body), expected[index]);
      final refreshed = PCStepMotivationManager.PC_getMotivation(
        index,
        balance: 56.12,
      );
      expect(refreshed.title, copy.title);
      expect(
        refreshed.body,
        index == 0
            ? 'You’ve saved \$56.12—cash out before it spills!'
            : copy.body,
      );
    }
  });

  test('4 个固定与 4 个媒体通知按各自延迟只发送一次并使用正确样式', () async {
    await create().initialize();
    expect(PCNoticeHelp.schedules, hasLength(8));
    expect(
      PCNoticeHelp.schedules
          .where((item) => !item.media)
          .map((item) => item.id),
      unorderedEquals(fixedIds),
    );
    expect(
      PCNoticeHelp.schedules.where((item) => item.media).map((item) => item.id),
      unorderedEquals(mediaIds),
    );
    expect(
      PCNoticeHelp.schedules
          .where((item) => !item.media)
          .map((item) => item.minutes),
      [26, 62, 117, 162],
    );
    expect(
      PCNoticeHelp.schedules
          .where((item) => item.media)
          .map((item) => item.minutes),
      [29, 59, 119, 159],
    );
    expect(backend.scheduled.keys, unorderedEquals({...fixedIds, ...mediaIds}));
    for (final schedule in PCNoticeHelp.schedules) {
      final data = backend.scheduled[schedule.id]!;
      final details = data['platformSpecifics'] as Map;
      expect(details['channelId'], schedule.channel);
      expect(data['payload'], schedule.payload);
      expect(data['scheduledDateTime'], isA<String>());
      expect(data['matchDateTimeComponents'], isNull);
      expect(data['repeatIntervalMilliseconds'], isNull);
      expect(data['repeatInterval'], isNull);
      expect(
        details['style'],
        (schedule.media
                ? AndroidNotificationStyle.media
                : AndroidNotificationStyle.beauty)
            .index,
      );
      expect(details['styleInformation'], isA<Map>());
      expect(schedule.kind, isIn([PCNoticeKind.account, PCNoticeKind.goal]));
      if (!schedule.media) {
        expect((details['styleInformation'] as Map)['template'], 'goal');
      }
    }
    final ordered = PCNoticeHelp.schedules.toList()
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    final anchor = DateTime.parse(
      backend.scheduled[ordered.first.id]!['scheduledDateTime']! as String,
    ).subtract(Duration(minutes: ordered.first.minutes));
    for (final schedule in ordered) {
      expect(
        DateTime.parse(
          backend.scheduled[schedule.id]!['scheduledDateTime']! as String,
        ).difference(anchor),
        Duration(minutes: schedule.minutes),
      );
    }
    expect(backend.called('periodicallyShowWithDuration'), isEmpty);
  });

  test('创建媒体 4、固定 4、前台 1 和 FCM 2 个独立渠道，正式 topic 分别绑定', () async {
    await create().initialize();
    final channels = {
      ...PCNoticeHelp.schedules.map((item) => item.channel),
      'pigwalletForeground',
      ...PCNoticeHelp.fcmChannels.map((item) => item.channel),
    };
    expect(channels, hasLength(11));
    expect(backend.channels.keys, containsAll(channels));
    expect(PCNoticeHelp.fcmChannels, hasLength(2));
    expect(
      PCNoticeHelp.fcmChannels.map((item) => item.slotKey),
      unorderedEquals(['fcm1', 'fcm2']),
    );
    expect(PCNoticeHelp.defaultFcmTopics, {
      'fcm1': 'c177fcm_piggy',
      'fcm2': 'c177fcm_piggy_two',
    });
    expect(
      backend.topics.keys,
      unorderedEquals(['c177fcm_piggy', 'c177fcm_piggy_two']),
    );
    for (final slot in PCNoticeHelp.fcmChannels) {
      final topic = PCNoticeHelp.defaultFcmTopics[slot.slotKey]!;
      final record = backend.topics[topic]!;
      expect(record['payload'], slot.slotKey);
      expect((record['platformSpecifics'] as Map)['channelId'], slot.channel);
      expect(slot.kind, PCNoticeKind.goal);
      expect(
        ((record['platformSpecifics'] as Map)['styleInformation']
            as Map)['template'],
        'goal',
      );
    }
    expect(backend.active.keys, [1200]);
    final details = backend.active[1200]!['platformSpecifics'] as Map;
    expect(details['channelId'], 'pigwalletForeground');
    expect(details['ongoing'], true);
  });

  test('显式清空两个 FCM topic 时保留渠道且不订阅默认 topic', () async {
    await create(topics: {'fcm1': '', 'fcm2': ''}).initialize();
    expect(backend.called('subscribeToTopic'), isEmpty);
    for (final slot in PCNoticeHelp.fcmChannels) {
      expect(backend.channels, contains(slot.channel));
    }
  });

  test('初始化和重复刷新幂等，不重置计划起点且只保留同一条前台服务通知', () async {
    final notice = create();
    await Future.wait([
      notice.initialize(),
      notice.initialize(),
      notice.initialize(),
    ]);
    final original = Map<int, Map<Object?, Object?>>.from(backend.scheduled);
    await Future.wait([notice.initialize(), notice.refreshSchedules()]);
    await notice.refreshSchedules();
    expect(backend.called('initialize'), hasLength(1));
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect(backend.scheduled, original);
    expect(backend.active.keys, [1200]);
  });

  test('首次原生初始化临时失败后刷新会重试，恢复时不重复创建渠道或通知计划', () async {
    var firstInitialize = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize' && firstInitialize) {
            firstInitialize = false;
            backend.calls.add(call);
            throw PlatformException(code: 'temporary_notification_failure');
          }
          return backend.handle(call);
        });
    final notice = create();
    await notice.initialize();
    expect(backend.called('initialize'), hasLength(1));
    expect(backend.channels, isEmpty);
    expect(backend.scheduled, isEmpty);
    expect(backend.active, isEmpty);

    await notice.refreshSchedules();
    expect(backend.called('initialize'), hasLength(2));
    expect(backend.channels, hasLength(11));
    expect(backend.called('createNotificationChannel'), hasLength(11));
    expect(backend.scheduled, hasLength(8));
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect(backend.active.keys, [1200]);

    await notice.initialize();
    await notice.refreshSchedules();
    expect(backend.called('initialize'), hasLength(2));
    expect(backend.called('createNotificationChannel'), hasLength(11));
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect(backend.active.keys, [1200]);
  });

  test('冷启动不改变首次计划时间，已触发且不在 pending 的通知不再次发送', () async {
    final first = create();
    await first.initialize();
    final originalStarts = {
      for (final item in backend.scheduled.entries)
        item.key: item.value['scheduledDateTime'],
    };
    first.dispose();
    helpers.remove(first);
    await create().initialize();
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect({
      for (final item in backend.scheduled.entries)
        item.key: item.value['scheduledDateTime'],
    }, originalStarts);
    backend.scheduled.remove(5590);
    await helpers.single.refreshSchedules();
    expect(backend.called('zonedSchedule'), hasLength(8));
    expect(backend.scheduled, hasLength(7));
    for (final entry in originalStarts.entries.where(
      (item) => item.key != 5590,
    )) {
      expect(backend.scheduled[entry.key]!['scheduledDateTime'], entry.value);
    }
  });

  test('余额更新刷新同一服务 ID，更新通知内容仍保留原定触发时刻', () async {
    var balance = 59.0;
    final notice = create(balance: () => balance);
    await notice.initialize();
    final before = backend.active[1200].toString();
    final times = {
      for (final item in backend.scheduled.entries)
        item.key: item.value['scheduledDateTime'],
    };
    balance = 106.25;
    await notice.refreshSchedules();
    expect(backend.active.keys, [1200]);
    expect(backend.active[1200].toString(), isNot(before));
    expect(backend.active[1200].toString(), contains('106.25'));
    expect({
      for (final item in backend.scheduled.entries)
        item.key: item.value['scheduledDateTime'],
    }, times);
    expect(backend.called('periodicallyShowWithDuration'), isEmpty);
  });

  test('真实余额跨过首档门槛只刷新通知计划，不再主动弹出payout站内通知', () async {
    // 使用真实入口注册PCLocalProvider监听，避免testing构造跳过监听导致假通过。
    SharedPreferences.setMockInitialValues({
      'pc_dollar_number': 99.0,
      'pc_new_guide_end': true,
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
    });
    await PCNewUserGuideController.instance.load();
    await PCLocalProvider.instance.init();
    final notice = PCNoticeHelp();
    helpers.add(notice);
    notice.attachNavigation((_) {});
    await notice.initialize();
    expect(notice.banner.value, isNull);
    expect(backend.scheduled, hasLength(8));
    final prefs = await SharedPreferences.getInstance();
    final times = {
      for (final entry in backend.scheduled.entries)
        entry.key: entry.value['scheduledDateTime'],
    };
    await prefs.setDouble('pc_dollar_number', 100.0);
    await PCLocalProvider.instance.init();
    // provider监听异步刷新服务/8项计划，先让真实通道回调完成再核对结果。
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await notice.refreshSchedules();
    expect(PCLocalProvider.instance.pc_dollar_number, 100);
    expect(notice.banner.value, isNull);
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    for (final entry in backend.scheduled.entries) {
      expect(entry.value['scheduledDateTime'], times[entry.key]);
    }
  });

  test('旧payout计划恢复为goal，保留全部通道及原定时刻且不补发已发送项', () async {
    final first = create(balance: () => 106.25);
    await first.initialize();
    final prefs = await SharedPreferences.getInstance();
    const planKey = 'pc_notification_plan_v3';
    final plan = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(planKey)!) as Map,
    );
    final signatures = Map<String, dynamic>.from(plan['signatures'] as Map);
    for (final id in [7552, 2934]) {
      signatures['$id'] = (signatures['$id'] as String).replaceFirst(
        RegExp(r'^[^:]+:'),
        'payout:',
      );
    }
    await prefs.setString(
      planKey,
      jsonEncode({...plan, 'signatures': signatures}),
    );
    final times = {
      for (final entry in backend.scheduled.entries)
        entry.key: entry.value['scheduledDateTime'],
    };
    // 一条已发送的计划不能因旧样式迁移重新发出。
    backend.scheduled.remove(5590);
    first.dispose();
    helpers.remove(first);
    await create(balance: () => 106.25).initialize();
    expect(
      backend.scheduled.keys,
      unorderedEquals({...fixedIds, ...mediaIds}..remove(5590)),
    );
    expect(backend.channels, hasLength(11));
    expect(backend.topics, hasLength(2));
    expect(backend.active.keys, [1200]);
    for (final entry in backend.scheduled.entries) {
      expect(entry.value['scheduledDateTime'], times[entry.key]);
      final details = entry.value['platformSpecifics'] as Map;
      if (fixedIds.contains(entry.key)) {
        expect((details['styleInformation'] as Map)['template'], 'goal');
      }
    }
    final restored = jsonDecode(prefs.getString(planKey)!) as Map;
    expect(restored['anchor'], plan['anchor']);
    for (final id in [7552, 2934]) {
      expect((restored['signatures'] as Map)['$id'], startsWith('goal:'));
    }
    expect(
      backend
          .called('zonedSchedule')
          .where((call) => (call.arguments as Map)['id'] == 5590),
      hasLength(1),
    );
  });

  test('每个单次计划固定一个随机文案，余额刷新和冷启动不重新抽取且不推迟', () async {
    var balance = 4.8;
    final notice = create(balance: () => balance);
    await notice.initialize();
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> readPlan() => Map<String, dynamic>.from(
      jsonDecode(prefs.getString('pc_notification_plan_v3')!) as Map,
    );
    final originalIndices = Map<String, dynamic>.from(
      readPlan()['copyIndices'] as Map,
    );
    final times = {
      for (final item in backend.scheduled.entries)
        item.key: item.value['scheduledDateTime'],
    };
    expect(originalIndices, hasLength(8));
    void expectSelectedCopy() {
      for (final schedule in PCNoticeHelp.schedules) {
        final index = originalIndices['${schedule.id}'];
        expect(index, inInclusiveRange(0, 4));
        final copy = PCStepMotivationManager.PC_getMotivation(
          index as int,
          balance: balance,
        );
        expect(backend.scheduled[schedule.id]!['title'], copy.title);
        expect(backend.scheduled[schedule.id]!['body'], copy.body);
        expect(
          backend.scheduled[schedule.id]!['scheduledDateTime'],
          times[schedule.id],
        );
      }
    }

    expectSelectedCopy();
    balance = 56.12;
    await notice.refreshSchedules();
    expect(readPlan()['copyIndices'], originalIndices);
    expectSelectedCopy();
    notice.dispose();
    helpers.remove(notice);
    await create(balance: () => balance).initialize();
    expect(readPlan()['copyIndices'], originalIndices);
    expectSelectedCopy();
  });

  test('锁屏和亮屏分别绑定 SCREEN_OFF 与 SCREEN_ON，广播文案来自同一文案池', () async {
    await create(balance: () => 4.8).initialize();
    expect(backend.broadcasts.keys, unorderedEquals([2829, 1029]));
    expect(
      backend.broadcasts[2829]!['broadcast'],
      'android.intent.action.SCREEN_OFF',
    );
    expect(backend.broadcasts[2829]!['payload'], 'screenoff');
    expect(
      backend.broadcasts[1029]!['broadcast'],
      'android.intent.action.SCREEN_ON',
    );
    expect(backend.broadcasts[1029]!['payload'], 'screenon');
    final pool = [
      for (var index = 0; index < 5; index++)
        PCStepMotivationManager.PC_getMotivation(index, balance: 4.8),
    ];
    for (final broadcast in backend.broadcasts.values) {
      expect(broadcast['randomMessages'], [
        for (final copy in pool) {'title': copy.title, 'body': copy.body},
      ]);
      expect(
        pool.any(
          (copy) =>
              copy.title == broadcast['title'] &&
              copy.body == broadcast['body'],
        ),
        true,
      );
    }
  });

  test('新用户引导未完成不启动计划、服务、广播或 FCM，完成后统一恢复', () async {
    var complete = false;
    final notice = create(guide: () => complete);
    await notice.initialize();
    expect(backend.scheduled, isEmpty);
    expect(backend.active, isEmpty);
    expect(backend.broadcasts, isEmpty);
    expect(backend.topics, isEmpty);
    complete = true;
    await notice.refreshSchedules();
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    expect(backend.broadcasts.keys, unorderedEquals([2829, 1029]));
  });

  test('撤回通知权限取消全部计划、服务和广播并退订；重新授权恢复未发送计划', () async {
    var enabled = true;
    final notice = create(
      permission: () async => enabled,
      topics: {'fcm1': 'test_withdraw', 'fcm2': 'test_earn'},
    );
    await notice.initialize();
    expect(
      backend.topics.keys,
      unorderedEquals(['test_withdraw', 'test_earn']),
    );
    enabled = false;
    await notice.refreshSchedules();
    expect(backend.scheduled, isEmpty);
    expect(backend.active, isEmpty);
    expect(backend.broadcasts, isEmpty);
    expect(backend.topics, isEmpty);
    final subscriptions = backend.called('subscribeToTopic').length;
    await notice.refreshSchedules();
    expect(backend.called('subscribeToTopic'), hasLength(subscriptions));
    enabled = true;
    await notice.refreshSchedules();
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    expect(backend.broadcasts.keys, unorderedEquals([2829, 1029]));
    expect(
      backend.topics.keys,
      unorderedEquals(['test_withdraw', 'test_earn']),
    );
  });

  test('已发送通知在撤权再授权后不重发，其余 7 个沿原定时刻恢复', () async {
    var enabled = true;
    final notice = create(permission: () async => enabled);
    await notice.initialize();
    final originalTimes = {
      for (final item in backend.scheduled.entries)
        item.key: item.value['scheduledDateTime'],
    };
    // Android 已发送的单次通知从 pending 列表移除。
    backend.scheduled.remove(5590);
    enabled = false;
    await notice.refreshSchedules();
    expect(backend.scheduled, isEmpty);
    enabled = true;
    await notice.refreshSchedules();
    final expectedIds = {...fixedIds, ...mediaIds}..remove(5590);
    expect(backend.scheduled.keys, unorderedEquals(expectedIds));
    expect(
      backend
          .called('zonedSchedule')
          .where((call) => (call.arguments as Map)['id'] == 5590),
      hasLength(1),
    );
    for (final item in backend.scheduled.entries) {
      expect(item.value['scheduledDateTime'], originalTimes[item.key]);
    }
  });

  test('暂停通知期间错过触发时刻，恢复授权仅恢复未来计划且不立即补发', () async {
    var enabled = true;
    final notice = create(permission: () async => enabled);
    await notice.initialize();
    enabled = false;
    await notice.refreshSchedules();
    final prefs = await SharedPreferences.getInstance();
    const planKey = 'pc_notification_plan_v3';
    final plan = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(planKey)!) as Map,
    );
    // 模拟首次锚点已经过去 27 分钟：26 分钟项过期，29 分钟项尚未到时。
    final anchor = DateTime.now().toUtc().subtract(const Duration(minutes: 27));
    plan['anchor'] = anchor.millisecondsSinceEpoch;
    await prefs.setString(planKey, jsonEncode(plan));
    final scheduledBefore = backend.called('zonedSchedule').length;
    enabled = true;
    await notice.refreshSchedules();
    expect(backend.scheduled, hasLength(7));
    expect(backend.scheduled.containsKey(5590), false);
    expect(
      backend
          .called('zonedSchedule')
          .skip(scheduledBefore)
          .map((call) => (call.arguments as Map)['id']),
      isNot(contains(5590)),
    );
    expect(backend.called('show'), isEmpty);
    for (final schedule in PCNoticeHelp.schedules.where(
      (item) => item.id != 5590,
    )) {
      final due = DateTime.parse(
        backend.scheduled[schedule.id]!['scheduledDateTimeISO8601']! as String,
      );
      expect(due.isAfter(DateTime.now().toUtc()), true);
      expect(
        due.millisecondsSinceEpoch,
        anchor.add(Duration(minutes: schedule.minutes)).millisecondsSinceEpoch,
      );
    }
  });

  test('两个 FCM slot 使用各自渠道与 payload，重复配置不订阅，修改与清空先退订', () async {
    final notice = create();
    await notice.initialize();
    await notice.configureFcmTopics(
      withdrawTopic: 'test_withdraw',
      earnTopic: 'test_earn',
    );
    expect(backend.topics, hasLength(2));
    for (final slot in PCNoticeHelp.fcmChannels) {
      final topic = slot.slotKey == 'fcm1' ? 'test_withdraw' : 'test_earn';
      final record = backend.topics[topic]!;
      expect(record['payload'], slot.slotKey);
      expect((record['platformSpecifics'] as Map)['channelId'], slot.channel);
    }
    final subscribed = backend.called('subscribeToTopic').length;
    await notice.configureFcmTopics(
      withdrawTopic: 'test_withdraw',
      earnTopic: 'test_earn',
    );
    expect(backend.called('subscribeToTopic'), hasLength(subscribed));
    await notice.configureFcmTopics(withdrawTopic: 'test_withdraw_v2');
    expect(
      backend.topics.keys,
      unorderedEquals(['test_withdraw_v2', 'test_earn']),
    );
    expect(
      backend
          .called('unsubscribeFromTopic')
          .map((call) => (call.arguments as Map)['topic']),
      contains('test_withdraw'),
    );
    await notice.configureFcmTopics(withdrawTopic: '', earnTopic: '');
    expect(backend.topics, isEmpty);
    expect(
      backend
          .called('unsubscribeFromTopic')
          .map((call) => (call.arguments as Map)['topic']),
      containsAll(['test_withdraw_v2', 'test_earn']),
    );
  });

  test('旧FCM签名保留原topic并更新两槽goal样式元数据，不影响其他通知计划', () async {
    SharedPreferences.setMockInitialValues({
      'pc_notification_fcm_subscribed_v1': jsonEncode({
        'fcm1': 'c177fcm_piggy',
        'fcm1Signature': 'c177fcm_piggy:\$106.25',
        'fcm2': 'c177fcm_piggy_two',
        'fcm2Signature': 'c177fcm_piggy_two:\$106.25',
      }),
    });
    final notice = create(balance: () => 106.25);
    await notice.initialize();
    expect(
      backend.topics.keys,
      unorderedEquals(['c177fcm_piggy', 'c177fcm_piggy_two']),
    );
    expect(backend.called('unsubscribeFromTopic'), isEmpty);
    expect(backend.called('subscribeToTopic'), hasLength(2));
    for (final record in backend.topics.values) {
      expect(
        ((record['platformSpecifics'] as Map)['styleInformation']
            as Map)['template'],
        'goal',
      );
    }
    expect(backend.channels, hasLength(11));
    expect(backend.scheduled, hasLength(8));
    expect(backend.active.keys, [1200]);
    final prefs = await SharedPreferences.getInstance();
    final subscriptions =
        jsonDecode(prefs.getString('pc_notification_fcm_subscribed_v1')!)
            as Map;
    expect(subscriptions['fcm1'], 'c177fcm_piggy');
    expect(subscriptions['fcm2'], 'c177fcm_piggy_two');
    expect(subscriptions['fcm1Signature'], contains('goal'));
    expect(subscriptions['fcm2Signature'], contains('goal'));
    await notice.refreshSchedules();
    expect(backend.called('subscribeToTopic'), hasLength(2));
  });

  test('旧通知、媒体、服务、广播和两个 FCM slot 的点击路由完整', () {
    final notice = create();
    final actions = <PCNoticeAction>[];
    notice.attachNavigation(actions.add);
    const routes = {
      'noti1': PCNoticeAction.withdraw,
      'noti2': PCNoticeAction.earn,
      'noti3': PCNoticeAction.withdraw,
      'noti4': PCNoticeAction.earn,
      'Media1': PCNoticeAction.withdraw,
      'Media2': PCNoticeAction.earn,
      'Media3': PCNoticeAction.withdraw,
      'Media4': PCNoticeAction.earn,
      'foreground': PCNoticeAction.withdraw,
      'unlock': PCNoticeAction.withdraw,
      'screenoff': PCNoticeAction.withdraw,
      'screenon': PCNoticeAction.earn,
      'fcm1': PCNoticeAction.withdraw,
      'fcm2': PCNoticeAction.earn,
    };
    for (final item in routes.entries) {
      notice.handlePayload(item.key);
      expect(actions.last, item.value, reason: item.key);
    }
    final count = actions.length;
    for (final invalid in [null, '', 'unknown', '{}', '[]']) {
      notice.handlePayload(invalid);
    }
    expect(actions, hasLength(count));
    notice.handlePayload(
      const PCNoticeMessage(
        kind: PCNoticeKind.goal,
        balance: 59,
        target: 100,
      ).payload,
    );
    expect(actions.last, PCNoticeAction.earn);
  });
}
