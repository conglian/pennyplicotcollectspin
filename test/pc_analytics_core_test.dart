import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pennypilotcollectspin/PCBasic/PCLaunch.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeHelp.dart';
import 'package:pennypilotcollectspin/PCTool/PCTBAEventTool.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <(String, Map<String, dynamic>)>[];
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void expectEvents(
    List<(String, Map<String, dynamic>)> expected, {
    int start = 0,
  }) {
    final actual = events.sublist(start);
    expect(actual.length, expected.length);
    for (var index = 0; index < expected.length; index++) {
      expect(actual[index].$1, expected[index].$1);
      expect(actual[index].$2, expected[index].$2);
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PCAnalytics.resetForTesting();
    events.clear();
    PCAnalytics.reporter = (name, body) => events.add((name, body));
  });
  tearDown(() async {
    await PCAnalytics.flush();
    messenger.setMockMethodCallHandler(channel, null);
    PCAnalytics.resetForTesting();
  });

  test('现金每5美元跨档补齐，重建冷启及余额回退不重复，资源数不当现金', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_dollar_number', 14.99);
    await Future.wait([PCAnalytics.cashChanged(), PCAnalytics.cashChanged()]);
    expectEvents([
      ('cash_money_detail', {'money_from': 5}),
      ('cash_money_detail', {'money_from': 10}),
    ]);
    await prefs.setDouble('pc_dollar_number', 21);
    await PCAnalytics.cashChanged();
    expectEvents([
      ('cash_money_detail', {'money_from': 15}),
      ('cash_money_detail', {'money_from': 20}),
    ], start: 2);
    await prefs.setDouble('pc_dollar_number', 5);
    await prefs.setDouble('pc_quiz_gold', 1000);
    await PCAnalytics.cashChanged();
    expect(events.length, 4);
    PCAnalytics.resetForTesting();
    PCAnalytics.reporter = (name, body) => events.add((name, body));
    await prefs.setDouble('pc_dollar_number', 21);
    await PCAnalytics.cashChanged();
    expect(events.length, 4);
  });

  test('累计广告每5次仅一次，真实计数并发不会重复或遗漏档位', () async {
    await Future.wait([
      PCAnalytics.adDisplayed(count: 5),
      PCAnalytics.adDisplayed(count: 5),
      PCAnalytics.adDisplayed(count: 12),
      PCAnalytics.adDisplayed(count: 9),
    ]);
    expectEvents([
      ('cash_ad_detail', {'ad_from': 5}),
      ('cash_ad_detail', {'ad_from': 10}),
    ]);
    await PCAnalytics.adDisplayed(count: 20);
    expectEvents([
      ('cash_ad_detail', {'ad_from': 15}),
      ('cash_ad_detail', {'ad_from': 20}),
    ], start: 2);
  });

  test('安装请求进行中合并并发，收到成功确认后跨冷启去重', () async {
    final started = Completer<void>();
    final response = Completer<bool>();
    var installs = 0;
    PCAnalytics.installReporter = () {
      installs++;
      started.complete();
      return response.future;
    };
    final first = PCAnalytics.install();
    await started.future;
    final second = PCAnalytics.install();
    expect(second, same(first));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(PCAnalytics.installKey), isFalse);
    response.complete(true);
    await Future.wait([first, second]);
    expect(prefs.getBool(PCAnalytics.installKey), isTrue);

    PCAnalytics.resetForTesting();
    PCAnalytics.installReporter = () async {
      installs++;
      return true;
    };
    await PCAnalytics.install();
    expect(installs, 1);
  });

  test('已有旧版安装标记的存档升级后不重报', () async {
    var installs = 0;
    for (final key in [PCAnalytics.installKey, 'pc_install_status']) {
      PCAnalytics.resetForTesting();
      SharedPreferences.setMockInitialValues({key: true});
      PCAnalytics.installReporter = () async {
        installs++;
        return true;
      };
      await PCAnalytics.install();
    }
    expect(installs, 0);
  });

  test('只在 cloak 成功后尝试安装请求，失败跨冷启续报并复用日志 ID', () async {
    const metadata = MethodChannel('flutter_tba_info');
    const referrer = MethodChannel(
      'de.lschmierer.android_play_install_referrer',
    );
    var generatedLogIds = 0;
    messenger.setMockMethodCallHandler(metadata, (call) async {
      return switch (call.method) {
        'getLogId' => 'test-install-${++generatedLogIds}',
        'getFirstInstallTime' || 'getLastUpdateTime' => 1,
        _ => 'test',
      };
    });
    messenger.setMockMethodCallHandler(
      referrer,
      (_) async => {
        'referrerClickTimestampSeconds': 1,
        'installBeginTimestampSeconds': 1,
        'referrerClickTimestampServerSeconds': 1,
        'installBeginTimestampServerSeconds': 1,
        'googlePlayInstantParam': false,
      },
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(metadata, null);
      messenger.setMockMethodCallHandler(referrer, null);
    });

    final logIds = <String>[];
    var cloakRequests = 0;
    final prefs = await SharedPreferences.getInstance();
    void expectPendingInstall() {
      expect(prefs.containsKey(PCAnalytics.installKey), isFalse);
      expect(prefs.containsKey('pc_install_status'), isFalse);
    }

    await http.runWithClient(
      () async {
        await PCLaunchState().pc_getUserCloakConfig();
        await PCLaunchState().pc_getUserCloakConfig();
        await PCLaunchState().pc_getUserCloakConfig();
        expect(logIds, isEmpty);
        expectPendingInstall();

        await PCLaunchState().pc_getUserCloakConfig();
        expect(logIds, hasLength(1));
        expectPendingInstall();

        // Simulate a process restart after the socket reset.
        await prefs.reload();
        PCAnalytics.resetForTesting();
        PCAnalytics.reporter = (name, body) => events.add((name, body));
        await PCLaunchState().pc_getUserCloakConfig();
        expect(logIds, hasLength(1));
        expectPendingInstall();

        await PCLaunchState().pc_getUserCloakConfig();
        expect(logIds, hasLength(2));
        expectPendingInstall();

        await PCLaunchState().pc_getUserCloakConfig();
        expect(prefs.getBool(PCAnalytics.installKey), isTrue);
        expect(prefs.getBool('pc_install_status'), isTrue);
        await PCLaunchState().pc_getUserCloakConfig();
        expect(logIds, List.filled(3, 'test-install-1'));
        expect(events.where((event) => event.$1 == 'cloak_suc'), hasLength(4));
      },
      () => MockClient((request) async {
        if (request.method == 'GET') {
          return switch (++cloakRequests) {
            1 || 5 => throw const SocketException('test offline'),
            2 => http.Response('temporarily unavailable', 503),
            3 => http.Response('', 200),
            _ => http.Response('ashland', 200),
          };
        }
        expect(request.method, 'POST');
        expect(request.url, Uri.parse(PCRequestHelpers.tba_event_Url_test));
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final align = payload['align'] as Map<String, dynamic>;
        logIds.add(align['reticent'] as String);
        return switch (logIds.length) {
          1 => throw const SocketException('Connection reset by peer'),
          2 => http.Response('temporarily unavailable', 503),
          _ => http.Response('', 201),
        };
      }),
    );
  });

  test('安装请求单次失败后返回未确认，且不回退到正式地址', () async {
    final previousUrl = PCRequestHelpers.tba_event_Url;
    PCRequestHelpers.tba_event_Url = PCRequestHelpers.tba_event_Url_test;
    addTearDown(() => PCRequestHelpers.tba_event_Url = previousUrl);
    final attemptedUrls = <Uri>[];
    final response = await http.runWithClient(
      () => PCRequestHelpers().post({}, 1),
      () => MockClient((request) async {
        attemptedUrls.add(request.url);
        throw const SocketException('test offline');
      }),
    );
    expect(response, isNull);
    expect(attemptedUrls, [Uri.parse(PCRequestHelpers.tba_event_Url_test)]);
  });

  test('session使用本地标准会话协议，不额外打同名自定义事件', () async {
    var sessions = 0;
    PCAnalytics.sessionReporter = () async => sessions++;
    await PCAnalytics.session();
    await PCAnalytics.session();
    expect(sessions, 2);
    expect(events, isEmpty);
  });

  test('原生非FCM触发按ID去重，确认失败重读不双报，旧FCM只确认清理', () async {
    final rows = [
      {'eventId': 'a', 'type': 'local'},
      {'eventId': 'b', 'type': 'unlock'},
      {'eventId': 'c', 'type': 'fcm'},
      {'eventId': 'a', 'type': 'local'},
    ];
    final acknowledgements = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getPendingNotificationAnalytics') return rows;
      if (call.method == 'ackNotificationAnalytics') {
        acknowledgements.add(call.arguments);
        throw PlatformException(code: 'temporary');
      }
      return null;
    });
    await Future.wait([
      PCAnalytics.flushNotificationTriggers(),
      PCAnalytics.flushNotificationTriggers(),
    ]);
    expectEvents([
      ('inform_p', {'type': 'local'}),
      ('inform_p', {'type': 'unlock'}),
    ]);
    await PCAnalytics.flushNotificationTriggers();
    expect(events.length, 2);
    expect(acknowledgements.length, 2);
    expect(acknowledgements.last, {
      'eventIds': ['a', 'b', 'c', 'a'],
    });
  });

  test('启动来源读取原生通知Intent且复用结果，图标启动不误记push', () async {
    var reads = 0;
    var fromPush = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'getNotificationAppLaunchDetails') return null;
      reads++;
      return {'notificationLaunchedApp': fromPush};
    });
    final pushed = PCNoticeHelp.testing(isGuideComplete: () => true);
    expect(await pushed.launchSource(), 'push');
    expect(await pushed.launchSource(), 'push');
    expect(reads, 1);
    fromPush = false;
    final icon = PCNoticeHelp.testing(isGuideComplete: () => true);
    expect(await icon.launchSource(), 'icon');
    pushed.dispose();
    icon.dispose();
  });

  testWidgets('真实失败面板曝光一次，父组件重建不重复', (tester) async {
    Widget page() =>
        const MaterialApp(home: Scaffold(body: PCAdLoadingFailedDialog()));
    await tester.pumpWidget(page());
    await tester.pump();
    await tester.pumpWidget(page());
    await tester.pump();
    expect(events.where((e) => e.$1 == 'ad_fail_pop'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
