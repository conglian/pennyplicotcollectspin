@TestOn('vm')
library;

import 'dart:async';

import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/pc_init_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <Map<String, dynamic>>[];

  setUp(() {
    events.clear();
    PCAnalytics.reporter = (name, parameters) {
      if (name == 'nkmdl_ad_initsuc') events.add(parameters);
    };
  });

  tearDown(PCAnalytics.resetForTesting);

  testWidgets('仅广告管理器未就位时后台重试不能提前初始化聚合SDK', (tester) async {
    final gate = Completer<void>();
    final requested = <String>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: gate.future,
      initializeAdSource: (source) async {
        requested.add(source);
        return true;
      },
      onAdSourceReady: ready.add,
    );

    await helpers.retryAdSourceInitialization('topon');
    await helpers.retryAdSourceInitialization('cloudx');
    expect(requested, isEmpty);
    expect(ready, isEmpty);

    gate.complete();
    await tester.pump();
    await helpers.retryAdSourceInitialization('topon');
    expect(requested, ['topon']);
    expect(ready, ['topon']);
  });

  testWidgets('实际并行启动中FB一直等待也不阻止广告SDK或启动链返回', (tester) async {
    final facebook = Completer<void>();
    final manager = Completer<void>();
    final started = <String>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      initializeAdSource: (source) async {
        started.add(source);
        return true;
      },
      onAdSourceReady: ready.add,
    );
    var startupReturned = false;
    final startup = helpers
        .initializeFacebookAndAdsForTesting(
          initializeFacebook: () {
            started.add('facebook');
            return facebook.future;
          },
          initializeAdManager: () {
            started.add('manager');
            return manager.future;
          },
        )
        .then((_) => startupReturned = true);

    expect(started, ['facebook', 'manager']);
    await helpers.retryAdSourceInitialization('topon');
    expect(started, ['facebook', 'manager']);
    expect(startupReturned, isFalse);
    manager.complete();
    await startup;
    expect(facebook.isCompleted, isFalse);
    expect(startupReturned, isTrue);
    await tester.pump();
    expect(ready, unorderedEquals(['topon', 'cloudx']));
    expect(facebook.isCompleted, isFalse);
    expect(events, hasLength(2));

    facebook.complete();
    await tester.pump();
    expect(ready, hasLength(2));
  });

  testWidgets('FB初始化抛错由自身隔离且广告仍按真实成功就绪', (tester) async {
    final started = <String>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      initializeAdSource: (source) async {
        started.add(source);
        return true;
      },
      onAdSourceReady: ready.add,
    );
    await helpers.initializeFacebookAndAdsForTesting(
      initializeFacebook: () {
        started.add('facebook');
        throw StateError('facebook unavailable');
      },
      initializeAdManager: () async {
        started.add('manager');
      },
    );
    await tester.pump();

    expect(started, ['facebook', 'manager', 'topon', 'cloudx']);
    expect(ready, ['topon', 'cloudx']);
    expect(events, hasLength(2));
  });

  testWidgets('广告平台初始化失败不能取消仍在运行的FB初始化', (tester) async {
    final facebook = Completer<void>();
    var facebookCompleted = false;
    final requested = <String>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      initializeAdSource: (source) async {
        requested.add(source);
        return false;
      },
      onAdSourceReady: ready.add,
    );
    await helpers.initializeFacebookAndAdsForTesting(
      initializeFacebook: () async {
        await facebook.future;
        facebookCompleted = true;
      },
      initializeAdManager: () async {},
    );
    await tester.pump();
    expect(requested, ['topon', 'cloudx']);
    expect(ready, isEmpty);
    expect(events, isEmpty);
    expect(facebookCompleted, isFalse);

    facebook.complete();
    await tester.pump();
    expect(facebookCompleted, isTrue);
  });

  testWidgets('TopOn初始化未结束不阻止CloudX独立成功', (tester) async {
    final topOn = Completer<bool>();
    final cloudX = Completer<bool>();
    final requested = <String>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      initializeAdSource: (source) {
        requested.add(source);
        return source == 'topon' ? topOn.future : cloudX.future;
      },
      onAdSourceReady: ready.add,
    );
    await tester.pump();

    final topOnAttempt = helpers.retryAdSourceInitialization('topon');
    final cloudXAttempt = helpers.retryAdSourceInitialization('cloudx');
    expect(requested, ['topon', 'cloudx']);
    cloudX.complete(true);
    await cloudXAttempt;
    expect(ready, ['cloudx']);
    expect(events.single['ad_source_client'], 'other');

    topOn.complete(true);
    await topOnAttempt;
    expect(ready, ['cloudx', 'topon']);
    expect(events.last['ad_source_client'], 'topon');
  });

  testWidgets('原生初始化异常或明确失败后下一轮可重试且失败不记成功', (tester) async {
    final attempts = <String, int>{};
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      initializeAdSource: (source) async {
        final count = attempts.update(
          source,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        if (count == 1 && source == 'topon') throw StateError('unavailable');
        return count > 1;
      },
      onAdSourceReady: ready.add,
    );
    await tester.pump();

    await Future.wait([
      helpers.retryAdSourceInitialization('topon'),
      helpers.retryAdSourceInitialization('cloudx'),
    ]);
    expect(helpers.is_ad_suc, isFalse);
    expect(ready, isEmpty);
    expect(events, isEmpty);

    await Future.wait([
      helpers.retryAdSourceInitialization('topon'),
      helpers.retryAdSourceInitialization('cloudx'),
    ]);
    expect(attempts, {'topon': 2, 'cloudx': 2});
    expect(ready, unorderedEquals(['topon', 'cloudx']));
    expect(events, hasLength(2));
    expect(helpers.is_ad_suc, isTrue);
  });

  testWidgets('同平台正常在途只共享一笔初始化而不随多个广告位重复调用', (tester) async {
    final pending = Completer<bool>();
    var attempts = 0;
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      initializeAdSource: (_) {
        attempts++;
        return pending.future;
      },
      onAdSourceReady: ready.add,
    );
    await tester.pump();

    final first = helpers.retryAdSourceInitialization('topon');
    expect(helpers.retryAdSourceInitialization('topon'), same(first));
    await tester.pump(const Duration(seconds: 8));
    expect(helpers.retryAdSourceInitialization('topon'), same(first));
    expect(attempts, 1);

    pending.complete(true);
    await first;
    expect(ready, ['topon']);
  });

  testWidgets('9秒超时后能开始新尝试且旧成功不能发布ready或解除新锁', (tester) async {
    final attempts = <Completer<bool>>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      initializeAdSource: (_) {
        final pending = Completer<bool>();
        attempts.add(pending);
        return pending.future;
      },
      onAdSourceReady: ready.add,
    );
    await tester.pump();

    final first = helpers.retryAdSourceInitialization('topon');
    await tester.pump(const Duration(seconds: 9));
    await first;
    expect(ready, isEmpty);
    expect(events, isEmpty);

    final second = helpers.retryAdSourceInitialization('topon');
    expect(attempts, hasLength(2));
    attempts.first.complete(true);
    await tester.pump();
    expect(ready, isEmpty);
    expect(events, isEmpty);
    expect(helpers.retryAdSourceInitialization('topon'), same(second));
    expect(attempts, hasLength(2));

    attempts.last.complete(true);
    await second;
    expect(ready, ['topon']);
    expect(events, hasLength(1));
  });

  testWidgets('超时后旧异常不会影响新平台初始化成功', (tester) async {
    final firstNative = Completer<bool>();
    final secondNative = Completer<bool>();
    var attempts = 0;
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      initializeAdSource: (_) {
        attempts++;
        return attempts == 1 ? firstNative.future : secondNative.future;
      },
      onAdSourceReady: ready.add,
    );
    await tester.pump();
    final first = helpers.retryAdSourceInitialization('cloudx');
    await tester.pump(const Duration(seconds: 9));
    await first;
    final second = helpers.retryAdSourceInitialization('cloudx');

    firstNative.completeError(StateError('late native failure'));
    await tester.pump();
    expect(helpers.retryAdSourceInitialization('cloudx'), same(second));
    secondNative.complete(true);
    await second;
    expect(ready, ['cloudx']);
    expect(events, hasLength(1));
  });

  testWidgets('每平台成功后不再初始化且成功事件各上报一次', (tester) async {
    final requested = <String>[];
    final ready = <String>[];
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      initializeAdSource: (source) async {
        requested.add(source);
        return true;
      },
      onAdSourceReady: ready.add,
    );
    await tester.pump();
    for (var cycle = 0; cycle < 3; cycle++) {
      await helpers.retryAdSourceInitialization('topon');
      await helpers.retryAdSourceInitialization('cloudx');
      await helpers.retryAdSourceInitialization('unknown');
    }
    expect(requested, ['topon', 'cloudx']);
    expect(ready, ['topon', 'cloudx']);
    expect(events, hasLength(2));
    expect(events.map((event) => event['ad_source_client']), [
      'topon',
      'other',
    ]);
    expect(events.every((event) => event['ad_init_time'] is int), isTrue);
  });

  testWidgets('TopOn旧日志设置迟到不能在新初始化成功后再初始化SDK', (tester) async {
    const topOnChannel = MethodChannel('thinkup_sdk');
    final oldLogResponse = Completer<bool>();
    var logCalls = 0;
    var nativeInitializeCalls = 0;
    final ready = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(topOnChannel, (call) async {
      if (call.method == 'setLogEnabled') {
        logCalls++;
        return logCalls == 1 ? oldLogResponse.future : true;
      }
      if (call.method == 'initSDK') {
        nativeInitializeCalls++;
        return '';
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(topOnChannel, null);
    });
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      onAdSourceReady: ready.add,
    );
    await tester.pump();

    final first = helpers.retryAdSourceInitialization('topon');
    await tester.pump();
    expect(logCalls, 1);
    expect(nativeInitializeCalls, 0);
    await tester.pump(const Duration(seconds: 9));
    await first;
    await helpers.retryAdSourceInitialization('topon');
    expect(nativeInitializeCalls, 1);
    expect(ready, ['topon']);

    oldLogResponse.complete(true);
    await tester.pump();
    expect(nativeInitializeCalls, 1);
    expect(ready, ['topon']);
    expect(events, hasLength(1));
  });

  testWidgets('CloudX原生已完成但旧initialize回执丢失时可按真实状态恢复', (tester) async {
    const cloudXChannel = MethodChannel('cloudx_flutter_sdk');
    final nativeResponse = Completer<Map<String, dynamic>>();
    var nativeReady = false;
    var nativeInitializeCalls = 0;
    final ready = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(cloudXChannel, (call) async {
      switch (call.method) {
        case 'isInitialized':
          return nativeReady;
        case 'initialize':
          nativeInitializeCalls++;
          return nativeResponse.future;
        case 'isRewardedReady':
          return nativeReady;
        default:
          return null;
      }
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(cloudXChannel, null);
    });
    final helpers = PCSDKHelpers.forTesting(
      adManagerReady: Future<void>.value(),
      onAdSourceReady: ready.add,
    );
    await tester.pump();

    final first = helpers.retryAdSourceInitialization('cloudx');
    await tester.pump();
    expect(nativeInitializeCalls, 1);
    await tester.pump(const Duration(seconds: 9));
    await first;
    expect(ready, isEmpty);

    nativeReady = true;
    await helpers.retryAdSourceInitialization('cloudx');
    expect(ready, ['cloudx']);
    expect(nativeInitializeCalls, 1);
    expect(events, hasLength(1));
    expect(await CloudX.isRewardedReady(adUnitId: 'test-reward-id'), isTrue);

    nativeResponse.complete({'success': true});
    await tester.pump();
    expect(ready, ['cloudx']);
    expect(events, hasLength(1));
  });
}
