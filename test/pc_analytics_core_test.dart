import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeHelp.dart';
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

  test('标准安装只对首次安装上报，已有存档升级不重新记install', () async {
    var installs = 0;
    PCAnalytics.installReporter = () async => installs++;
    await Future.wait([PCAnalytics.install(), PCAnalytics.install()]);
    expect(installs, 1);
    SharedPreferences.setMockInitialValues({'pc_install_status': true});
    PCAnalytics.resetForTesting();
    PCAnalytics.installReporter = () async => installs++;
    await PCAnalytics.install();
    expect(installs, 1);
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
