import 'dart:async';
import 'dart:convert';

import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCModel/PCAdModel.dart';
import 'package:pennypilotcollectspin/PCTool/PCAdRevenue.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_ad_manger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const cloudXChannel = MethodChannel('cloudx_flutter_sdk');
  const adjustChannel = MethodChannel('com.adjust.sdk/api');
  const rewardId = 'yT9Q-o8dLXJKNqtYmZQ49';
  const interstitialId = 'ibY48kOdYdGCxD2FqIhOX';
  final manager = PCPigAds();
  final calls = <MethodCall>[];
  final revenues = <Map<dynamic, dynamic>>[];
  bool nativeReady = false;
  final nativeReadyOverrides = <String, bool>{};
  Completer<bool>? readinessGate;
  final requests = <Map<String, dynamic>>[];
  final adEvents = <(String, Map<String, dynamic>)>[];
  final tbaRevenues = <Map<String, dynamic>>[];
  final originalReportEvent = manager.reportEvent;
  final originalReportRevenue = manager.reportRevenue;
  final originalAnalyticsReporter = PCAnalytics.reporter;

  Future<void> flush() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> emit(
    String suffix, {
    bool rewarded = true,
    double revenue = 0.0123,
  }) async {
    final result = Completer<void>();
    final id = rewarded ? rewardId : interstitialId;
    if (suffix == 'Loaded') nativeReady = true;
    if (suffix == 'Hidden' || suffix == 'DisplayFailed') nativeReady = false;
    // 模拟真实 SDK 通道事件，覆盖插件解析、监听器和业务回调整条路径。
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      cloudXChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(
          'On${rewarded ? 'Rewarded' : 'Interstitial'}${suffix}Event',
          {
            'adUnitId': id,
            'ad': {
              'adUnitId': id,
              'adFormat': rewarded ? 'rewarded' : 'interstitial',
              'networkName': 'Meta',
              'revenue': revenue,
              'placement': rewarded ? 'scene_rv' : 'scene_int',
              'networkPlacement': 'network-slot',
            },
            'error': {'code': 302, 'message': 'No fill'},
            'reward': {'amount': 1, 'label': 'coin'},
          },
        ),
      ),
      (ByteData? _) => result.complete(),
    );
    await result.future;
    await flush();
  }

  int count(String method) => calls.where((c) => c.method == method).length;

  void expectAttempt(String placement, String format, String reason) {
    final chances = adEvents.where(
      (event) =>
          event.$1 == 'nkmdl_ad_chance' && event.$2['ad_pos_id'] == placement,
    );
    final failures = adEvents.where(
      (event) =>
          event.$1 == 'nkmdl_ad_impression_fail' &&
          event.$2['ad_pos_id'] == placement,
    );
    expect(chances, hasLength(1), reason: '每次入口尝试仅上报一次chance');
    expect(chances.single.$2, containsPair('ad_format', format));
    expect(failures, hasLength(1));
    expect(failures.single.$2, containsPair('reason', reason));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'pc_bg_music': false});
    await PCLocalProvider.instance.init();
    nativeReady = false;
    nativeReadyOverrides.clear();
    readinessGate = null;
    calls.clear();
    requests.clear();
    adEvents.clear();
    tbaRevenues.clear();
    revenues.clear();
    manager.skipAdForTesting = false;
    manager.reportEvent = (name, data) {
      adEvents.add((name, Map<String, dynamic>.from(data)));
      if (name == 'nkmdl_ad_request') requests.add(data);
    };
    manager.reportRevenue = (data) =>
        tbaRevenues.add(Map<String, dynamic>.from(data));
    PCAnalytics.reporter = (name, data) =>
        adEvents.add((name, Map<String, dynamic>.from(data)));
    messenger.setMockMethodCallHandler(cloudXChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isInitialized':
          return false;
        case 'initialize':
          return {'success': true};
        case 'isRewardedReady':
        case 'isInterstitialReady':
          if (readinessGate != null) return readinessGate!.future;
          final id = (call.arguments as Map)['adUnitId'];
          return nativeReadyOverrides[id] ?? nativeReady;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(adjustChannel, (call) async {
      if (call.method == 'trackAdRevenue') {
        revenues.add(Map<dynamic, dynamic>.from(call.arguments as Map));
      }
      return null;
    });
    expect((await CloudX.initialize(appKey: 'test-key')).success, isTrue);
    // TopOn 尚未初始化时，CloudX 应可独立工作，不访问 TopOn 原生通道。
    await manager.init(readySources: {'cloudx'});
    await flush();
  });

  tearDown(() async {
    await PCAnalytics.flush();
    PCAnalytics.reporter = originalAnalyticsReporter;
    manager.stopForTesting();
    manager.skipAdForTesting = null;
    manager.reportEvent = originalReportEvent;
    manager.reportRevenue = originalReportRevenue;
    await flush();
    messenger.setMockMethodCallHandler(cloudXChannel, null);
    messenger.setMockMethodCallHandler(adjustChannel, null);
  });

  test(
    'CloudX and TopOn income mappings keep supported sources and exact revenue',
    () {
      const ad = CloudXAd(
        adUnitId: rewardId,
        adFormat: CloudXAdFormat.rewarded,
        networkName: 'Meta',
        revenue: 0.0123,
        placement: 'scene_rv',
        networkPlacement: 'network-slot',
      );
      final cloudX = PCAdRevenue.cloudX(ad)!.toMap;
      expect(cloudX['source'], 'publisher_sdk');
      expect(cloudX['revenue'], '0.0123');
      expect(cloudX['currency'], 'USD');
      expect(cloudX['adRevenueNetwork'], 'Meta');
      expect(cloudX['adRevenueUnit'], rewardId);
      expect(cloudX['adRevenuePlacement'], 'scene_rv');
      expect(
        PCAdRevenue.cloudX(
          ad,
          placement: 'actual_scene_rv',
        )!.toMap['adRevenuePlacement'],
        'actual_scene_rv',
        reason: '传入的本次placeID优先于缓存SDK携带的旧placement',
      );
      expect(jsonDecode(cloudX['callbackParameters']!), {
        'mediation_platform': 'cloudx',
        'ad_type': 'rewarded',
        'ad_unit_id': rewardId,
      });
      final topOn = PCAdRevenue.topOn(
        {
          'publisher_revenue': '0.035',
          'currency': '',
          'network_name': 'Pangle',
        },
        adUnitId: 'topon-unit',
        placement: 'scene_int',
      )!.toMap;
      expect(topOn['source'], 'topon_sdk');
      expect(topOn['revenue'], '0.035');
      expect(topOn['currency'], 'USD');
      expect(topOn['adRevenueUnit'], 'topon-unit');
      expect(topOn['adRevenuePlacement'], 'scene_int');
      for (final value in [null, -1, double.nan, double.infinity, 'invalid']) {
        expect(PCAdRevenue.amount(value), isNull);
      }
    },
  );

  test('广告请求、填充与失败按表使用同一广告单元、rv/int和真实毫秒', () async {
    expect(requests, hasLength(2));
    expect(
      requests.map((data) => data['ad_format']),
      containsAll(['rv', 'int']),
    );
    expect(
      requests.every((data) => data['ad_source_client'] == 'other'),
      isTrue,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await emit('Loaded');
    await emit('Loaded');
    final returns = adEvents.where((event) => event.$1 == 'nkmdl_ad_return');
    expect(returns, hasLength(1), reason: '重复SDK回调不重复记填充');
    expect(returns.single.$2, containsPair('ad_code_id', rewardId));
    expect(returns.single.$2, containsPair('ad_format', 'rv'));
    expect(returns.single.$2, containsPair('ad_source_client', 'other'));
    expect(
      returns.single.$2['nkmdl_ad_request_time'],
      greaterThanOrEqualTo(30),
    );
    expect(returns.single.$2.containsKey('olstk_ad_request_time'), isFalse);

    await emit('LoadFailed', rewarded: false);
    final failures = adEvents.where(
      (event) => event.$1 == 'nkmdl_ad_return_fail',
    );
    expect(failures, hasLength(1));
    expect(failures.single.$2, containsPair('ad_code_id', interstitialId));
    expect(failures.single.$2, containsPair('ad_format', 'int'));
    expect(failures.single.$2, containsPair('ad_source_client', 'other'));
    expect(failures.single.$2, containsPair('reason', 'No fill'));
  });

  test('ad_impression只走pc_ad_fire且严格使用调用的placeID', () async {
    await emit('Loaded');
    final result = manager.requestRewarded('nkmdl_test_scene_rv');
    await flush();
    await emit('Displayed'); // SDK仍回填scene_rv，不能覆盖真实业务入口。
    await emit('Displayed');
    await emit('RevenuePaid', revenue: 9);
    expect(tbaRevenues, hasLength(1));
    expect(
      tbaRevenues.single,
      containsPair('ad_pos_id', 'nkmdl_test_scene_rv'),
    );
    expect(tbaRevenues.single, containsPair('valuate', 'nkmdl_test_scene_rv'));
    expect(tbaRevenues.single, containsPair('ad_pre_ecpm', 12300000.0));
    expect(tbaRevenues.single, containsPair('dang', 12300.0));
    expect(tbaRevenues.single, containsPair('ad_format', 'reward'));
    expect(tbaRevenues.single, containsPair('shadowy', 'rv'));
    expect(adEvents.where((event) => event.$1 == 'ad_impression'), isEmpty);
    expect(revenues.single['adRevenuePlacement'], 'nkmdl_test_scene_rv');
    await emit('Hidden');
    expect(await result, isFalse);
    final closed = adEvents.where((event) => event.$1 == 'nkmdl_ad_imp_close');
    expect(closed, hasLength(1));
    expect(closed.single.$2, containsPair('ad_pos_id', 'nkmdl_test_scene_rv'));
    expect(closed.single.$2, containsPair('ad_format', 'rv'));
  });

  test('无缓存、过期缓存与真实播放失败分别单次上报失败', () async {
    expect(await manager.requestRewarded('nkmdl_empty_rv'), isFalse);
    var failures = adEvents.where(
      (event) => event.$1 == 'nkmdl_ad_impression_fail',
    );
    expect(failures, hasLength(1));
    expect(failures.single.$2, containsPair('reason', 'notPrepared'));

    adEvents.clear();
    await emit('Loaded');
    nativeReady = false;
    expect(await manager.requestRewarded('nkmdl_expired_rv'), isFalse);
    await flush();
    failures = adEvents.where(
      (event) => event.$1 == 'nkmdl_ad_impression_fail',
    );
    expect(failures, hasLength(1));
    expect(failures.single.$2, containsPair('reason', 'ad_nocache'));

    adEvents.clear();
    await emit('Loaded');
    final failed = manager.requestRewarded('nkmdl_failed_rv');
    await flush();
    await emit('DisplayFailed');
    expect(await failed, isFalse);
    failures = adEvents.where(
      (event) => event.$1 == 'nkmdl_ad_impression_fail',
    );
    expect(failures, hasLength(1));
    expect(failures.single.$2, containsPair('reason', 'impfail'));
    expect(failures.single.$2, containsPair('ad_pos_id', 'nkmdl_failed_rv'));
    expect(tbaRevenues, isEmpty);
  });

  test(
    'only initialized SDK loads; missing cache returns false without a lock',
    () async {
      expect(count('loadInterstitial'), 1);
      expect(count('loadRewarded'), 1);
      expect(await PCRewardedAdService.instance.request('scene_rv'), isFalse);
      expect(manager.is_showAd, isFalse);
      expect(manager.onAdClosed, isNull);
      expect(count('showRewarded'), 0);
    },
  );

  test('reward close without reward callback never grants reward', () async {
    await emit('Loaded');
    final result = manager.requestRewarded('scene_rv');
    await flush();
    expect(count('showRewarded'), 1);
    await emit('Displayed');
    expect(revenues, hasLength(1), reason: '显示成功立即上报，不等待RevenuePaid');
    await emit('Displayed');
    await emit('RevenuePaid', revenue: 9);
    expect(revenues, hasLength(1));
    expect(revenues.single['source'], 'publisher_sdk');
    expect(revenues.single['revenue'], '0.0123');
    expect(manager.getAdRevenue(), closeTo(0.0123, 1e-10));
    await emit('Hidden');
    expect(await result, isFalse);
    expect(manager.is_showAd, isFalse);
    expect(count('loadRewarded'), 2);
  });

  test(
    'real reward succeeds once on close; concurrent request does not replace owner',
    () async {
      await emit('Loaded');
      await emit('Loaded', rewarded: false, revenue: 0.5);
      final result = manager.requestRewarded('scene_rv');
      var completed = 0;
      result.then((_) => completed++);
      await flush();
      expect(count('showRewarded'), 1);
      expect(count('showInterstitial'), 0); // A模式仍只比较同类型广告。
      expect(await manager.requestRewarded('other_rv'), isFalse);
      await emit('Displayed');
      await emit('ReceivedReward');
      await emit('ReceivedReward');
      expect(completed, 0);
      await emit('Hidden');
      expect(await result, isTrue);
      expect(completed, 1);
      await emit('Hidden');
      expect(completed, 1);
      expect(count('loadRewarded'), 2);
      expect(manager.onAdClosed, isNull);
    },
  );

  test(
    'display failure releases owner and permits a fresh reward attempt',
    () async {
      await emit('Loaded');
      final failed = manager.requestRewarded('scene_rv');
      await flush();
      await emit('DisplayFailed');
      expect(await failed, isFalse);
      expect(manager.is_showAd, isFalse);
      expect(manager.onAdClosed, isNull);
      await emit('Loaded');
      final retry = manager.requestRewarded('scene_rv');
      await flush();
      await emit('ReceivedReward');
      await emit('Hidden');
      expect(await retry, isTrue);
    },
  );

  test(
    'B comparison never substitutes a higher value interstitial for rewarded',
    () async {
      manager.compareMode = true;
      await emit('Loaded', revenue: 0.01);
      await emit('Loaded', rewarded: false, revenue: 0.1);
      final result = manager.requestRewarded('scene_rv');
      await flush();
      expect(count('showInterstitial'), 0);
      expect(count('showRewarded'), 1);
      await emit('ReceivedReward');
      await emit('Hidden');
      expect(await result, isTrue);
    },
  );

  test(
    'explicit rv and int placement IDs take precedence over legacy flags',
    () async {
      await emit('Loaded');
      final reward = Completer<bool>();
      manager.pc_showAd(
        null,
        'scene_rv',
        rewarded: false,
        showDialog: false,
        onCacheResponse: (ready) {
          if (!ready) reward.complete(false);
        },
        adDidClosed: reward.complete,
      );
      await flush();
      expect(count('showRewarded'), 1);
      expect(count('showInterstitial'), 0);
      await emit('ReceivedReward');
      await emit('Hidden');
      expect(await reward.future, isTrue);

      await emit('Loaded', rewarded: false);
      final interstitial = Completer<bool>();
      manager.pc_showAd(
        null,
        'scene_int',
        rewarded: true,
        showDialog: false,
        onCacheResponse: (ready) {
          if (!ready) interstitial.complete(false);
        },
        adDidClosed: interstitial.complete,
      );
      await flush();
      expect(count('showInterstitial'), 1);
      await emit('Hidden', rewarded: false);
      expect(await interstitial.future, isTrue);
    },
  );

  test(
    'launch placement uses an interstitial and services reject the wrong explicit format',
    () async {
      expect(await manager.requestRewarded('scene_int'), isFalse);
      expect(await manager.requestRewarded('nkmdl_launch'), isFalse);
      expect(await manager.requestRewarded('nskdh_launch'), isFalse);
      expect(await manager.requestInterstitial('scene_rv'), isFalse);
      await emit('Loaded', rewarded: false);
      final result = PCInterstitialAdService.instance.request('nkmdl_launch');
      await flush();
      expect(count('showInterstitial'), 1);
      expect(count('showRewarded'), 0);
      expect(
        calls.lastWhere((call) => call.method == 'showInterstitial').arguments,
        containsPair('placement', 'nkmdl_launch'),
      );
      await emit('Hidden', rewarded: false);
      expect(await result, isTrue);
    },
  );

  test(
    'ad owner is released before a close callback immediately requests the next ad',
    () async {
      await emit('Loaded');
      await emit('Loaded', rewarded: false);
      Future<bool>? next;
      manager.pc_showAd(
        null,
        'scene_rv',
        showDialog: false,
        onCacheResponse: (_) {},
        adDidClosed: (success) {
          expect(success, isTrue);
          // 测试SDK仅用一位模拟ready；上一条激励关闭不应消费插屏缓存。
          nativeReady = true;
          next = manager.requestInterstitial('int');
        },
      );
      await flush();
      await emit('ReceivedReward');
      await emit('Hidden');
      expect(count('showInterstitial'), 1);
      expect(manager.onAdClosed, isNotNull);
      await emit('Hidden', rewarded: false);
      expect(await next, isTrue);
    },
  );

  test(
    'debug skip completes rewarded and interstitial success without native display or income',
    () async {
      manager.skipAdForTesting = true;
      final callsBefore = calls.length;
      final showCountBefore = manager.getAdShowCount();
      final revenueBefore = manager.getAdRevenue();
      expect(await PCRewardedAdService.instance.request('rv'), isTrue);
      expect(await manager.requestInterstitial('nkmdl_launch'), isTrue);
      expect(await manager.requestCachedInterstitial('int'), isTrue);
      expect(calls, hasLength(callsBefore));
      expect(count('showRewarded'), 0);
      expect(count('showInterstitial'), 0);
      expect(manager.getAdShowCount(), showCountBefore);
      expect(manager.getAdRevenue(), revenueBefore);
      expect(revenues, isEmpty);
      expect(manager.onAdClosed, isNull);
      expect(manager.isAdBusy, isFalse);
    },
  );

  test(
    'debug skip releases owner before its one success callback chains another ad',
    () async {
      manager.skipAdForTesting = true;
      var completed = 0;
      Future<bool>? next;
      manager.pc_showAd(
        null,
        'scene_rv',
        onCacheResponse: (ready) => expect(ready, isTrue),
        adDidClosed: (success) {
          completed++;
          expect(success, isTrue);
          expect(manager.isAdBusy, isFalse);
          next = PCInterstitialAdService.instance.request('int');
        },
      );
      await flush();
      expect(completed, 1);
      expect(next, isNotNull);
      expect(await next, isTrue);
      expect(manager.onAdClosed, isNull);
      expect(manager.isAdBusy, isFalse);
      expect(count('showRewarded'), 0);
      expect(count('showInterstitial'), 0);
      expect(revenues, isEmpty);
    },
  );

  test(
    'expired native cache reloads and does not leave a pending reward',
    () async {
      await emit('Loaded');
      nativeReady = false;
      expect(await manager.requestRewarded('scene_rv'), isFalse);
      await flush(); // 失败结果先返回；补缓存仍需等待SDK缓存检查完成。
      expect(count('showRewarded'), 0);
      expect(count('loadRewarded'), 2);
      expect(manager.onAdClosed, isNull);
    },
  );

  test(
    'interstitial reports revenue on display once and closes independently from rewarded',
    () async {
      await emit('Loaded', rewarded: false);
      final result = Completer<bool>();
      manager.pc_showAd(
        null,
        'scene_int',
        rewarded: false,
        showDialog: false,
        onCacheResponse: (ready) {
          if (!ready) result.complete(false);
        },
        adDidClosed: result.complete,
      );
      await flush();
      expect(count('showInterstitial'), 1);
      expect(count('showRewarded'), 0);
      await emit('Displayed', rewarded: false, revenue: 0.0045);
      await emit('Clicked', rewarded: false);
      await emit('RevenuePaid', rewarded: false, revenue: 0.0045);
      expect(revenues, hasLength(1));
      expect(revenues.single['revenue'], '0.0045');
      expect(manager.getAdClickCount(), 1);
      await emit('Hidden', rewarded: false);
      expect(await result.future, isTrue);
      expect(count('loadInterstitial'), 2);
    },
  );

  test('native cached ads are reused without a new load', () async {
    manager.stopForTesting();
    nativeReady = true;
    calls.clear();
    requests.clear();
    await manager.init(readySources: {'cloudx'});
    await flush();
    expect(count('loadRewarded'), 0);
    expect(count('loadInterstitial'), 0);
    expect(requests, isEmpty);
    final reward = manager.requestRewarded('scene_rv');
    await flush();
    expect(count('showRewarded'), 1);
    await emit('ReceivedReward');
    await emit('Hidden');
    expect(await reward, isTrue);
    expect(count('loadRewarded'), 1, reason: '仅消费缓存后补一条广告');
  });

  test('普通开屏与激励入口无须外层预判，加载中和无缓存都记录机会与原因且不重复load', () async {
    for (final compare in [false, true]) {
      manager.compareMode = compare;
      for (final rewarded in [false, true]) {
        final placement = rewarded ? 'nkmdl_signin_rv' : 'nkmdl_launch';
        final format = rewarded ? 'rv' : 'int';
        final loadMethod = rewarded ? 'loadRewarded' : 'loadInterstitial';
        Future<bool> request() => rewarded
            ? PCRewardedAdService.instance.request(placement)
            : PCInterstitialAdService.instance.request(placement);

        adEvents.clear();
        final before = count(loadMethod);
        expect(await request(), isFalse);
        await flush();
        expectAttempt(placement, format, 'notPrepared');
        expect(count(loadMethod), before, reason: '已有SDK请求在途，不重发load');

        await emit('LoadFailed', rewarded: rewarded);
        adEvents.clear();
        expect(await request(), isFalse);
        await flush();
        expectAttempt(placement, format, 'ad_nocache');
        expect(count(loadMethod), before + 1, reason: '无缓存仅补一次正常请求');

        adEvents.clear();
        expect(await request(), isFalse);
        await flush();
        expectAttempt(placement, format, 'notPrepared');
        expect(count(loadMethod), before + 1, reason: '补缓存尚未返回，不重复请求');
        expect(manager.onAdClosed, isNull);
        expect(manager.isNativeAdShowing, isFalse);
      }
    }
    expect(count('showInterstitial'), 0);
    expect(count('showRewarded'), 0);
    expect(tbaRevenues, isEmpty);
  });

  test('SDK尚未初始化时普通开屏和激励仍进入pc_showAd记录uninitialized', () async {
    for (final prepared in [false, true]) {
      manager.stopForTesting();
      calls.clear();
      manager.bindServices();
      // init尚未运行，以及init完成但聚合SDK未就绪，两种情况均不能静默丢场景。
      if (prepared) await manager.init(readySources: <String>{});
      await flush();
      for (final compare in [false, true]) {
        manager.compareMode = compare;
        adEvents.clear();
        expect(
          await PCInterstitialAdService.instance.request('nkmdl_launch'),
          isFalse,
        );
        await flush();
        expectAttempt('nkmdl_launch', 'int', 'uninitialized');
        adEvents.clear();
        expect(await PCRewardedAdService.instance.request('scene_rv'), isFalse);
        await flush();
        expectAttempt('scene_rv', 'rv', 'uninitialized');
      }
      expect(count('loadInterstitial'), 0);
      expect(count('loadRewarded'), 0);
      expect(count('showInterstitial'), 0);
      expect(count('showRewarded'), 0);
      expect(manager.onAdClosed, isNull);
      expect(tbaRevenues, isEmpty);
    }
  });

  test('缓存检查在途拒绝开屏仍记chance和notPrepared，原owner及真实原生展示不被抢占', () async {
    await emit('Loaded');
    readinessGate = Completer<bool>();
    var completed = 0;
    final original = manager.requestRewarded('scene_rv');
    original.then((_) => completed++);
    await flush();
    final owner = manager.onAdClosed;
    final checks = count('isInterstitialReady') + count('isRewardedReady');
    final loads = count('loadInterstitial') + count('loadRewarded');
    expect(owner, isNotNull);
    expect(manager.isNativeAdShowing, isFalse);
    adEvents.clear();

    expect(
      await PCInterstitialAdService.instance.request('nkmdl_launch'),
      isFalse,
    );
    expectAttempt('nkmdl_launch', 'int', 'notPrepared');
    expect(manager.onAdClosed, same(owner));
    expect(manager.quizAdPlaceID, 'scene_rv');
    expect(count('isInterstitialReady') + count('isRewardedReady'), checks);
    expect(count('loadInterstitial') + count('loadRewarded'), loads);
    expect(count('showInterstitial'), 0);
    expect(count('showRewarded'), 0);
    expect(completed, 0);

    readinessGate!.complete(true);
    readinessGate = null;
    await flush();
    expect(manager.isNativeAdShowing, isTrue);
    expect(count('showRewarded'), 1);
    expect(count('showInterstitial'), 0);
    expect(await manager.requestInterstitial('nkmdl_launch'), isFalse);
    expect(manager.onAdClosed, same(owner));
    expect(manager.quizAdPlaceID, 'scene_rv');
    await emit('Displayed');
    await emit('ReceivedReward');
    await emit('Hidden');
    expect(await original, isTrue);
    expect(completed, 1);
    expect(tbaRevenues, hasLength(1));
    expect(tbaRevenues.single, containsPair('ad_pos_id', 'scene_rv'));
    expect(manager.getAdShowCount(), 1);
    expect(count('showInterstitial'), 0);
  });

  test('普通nkmdl_launch复用缓存，关闭后补缺失插屏且保留仍缓存的激励', () async {
    for (final compare in [false, true]) {
      manager.stopForTesting();
      nativeReady = true;
      // 插屏消耗不影响激励缓存；分别模拟两个SDK广告位的真实ready状态。
      nativeReadyOverrides[rewardId] = true;
      calls.clear();
      adEvents.clear();
      await manager.init(readySources: {'cloudx'});
      await flush();
      manager.compareMode = compare;
      final result = PCInterstitialAdService.instance.request('nkmdl_launch');
      await flush();
      expect(count('loadInterstitial'), 0);
      expect(count('loadRewarded'), 0);
      expect(count('showInterstitial'), 1);
      expect(count('showRewarded'), 0);
      final chances = adEvents.where((event) => event.$1 == 'nkmdl_ad_chance');
      expect(chances, hasLength(1));
      expect(chances.single.$2, containsPair('ad_pos_id', 'nkmdl_launch'));
      await emit('Displayed', rewarded: false);
      await emit('Hidden', rewarded: false);
      expect(await result, isTrue);
      expect(count('loadInterstitial'), 1);
      expect(count('loadRewarded'), 0);
    }
  });

  test('风控拒绝保持原协议，不上报广告机会或收入', () async {
    final local = PCLocalProvider.instance;
    local.pc_fk_number_status = true;
    adEvents.clear();
    try {
      expect(await manager.requestInterstitial('nkmdl_launch'), isFalse);
      expect(adEvents, hasLength(1));
      expect(adEvents.single.$1, 'pc_fk_un');
      expect(adEvents.single.$2, isEmpty);
      expect(manager.onAdClosed, isNull);
      expect(tbaRevenues, isEmpty);
      expect(count('showInterstitial'), 0);
    } finally {
      local.pc_fk_number_status = false;
    }
  });

  test('仅缓存API在无缓存和失效缓存时不额外load或替换在途请求', () async {
    for (final compare in [false, true]) {
      manager.compareMode = compare;
      final before = count('loadInterstitial');
      expect(
        await PCInterstitialAdService.instance.requestCached('nskdh_launch'),
        isFalse,
      );
      await flush();
      expect(count('loadInterstitial'), before);
      expect(manager.isAdBusy, isFalse);

      await emit('Loaded', rewarded: false);
      nativeReady = false; // Dart认为缓存存在，但原生缓存已失效。
      expect(
        await PCInterstitialAdService.instance.requestCached('nskdh_launch'),
        isFalse,
      );
      await flush();
      expect(count('loadInterstitial'), before);
      expect(manager.isAdBusy, isFalse);
    }
    expect(manager.adSessionVersion, 0);
    expect(manager.lastAdFinishedAt, isNull);
  });

  test('仅缓存API等待原生缓存检查也保持busy，真实展示与关闭记录同一session', () async {
    await emit('Loaded', rewarded: false);
    readinessGate = Completer<bool>();
    final result = PCInterstitialAdService.instance.requestCached(
      'nskdh_launch',
    );
    await flush();
    expect(manager.isAdBusy, isTrue);
    expect(manager.adSessionVersion, 0);
    expect(await manager.requestRewarded('scene_rv'), isFalse);
    readinessGate!.complete(true);
    readinessGate = null;
    await flush();
    expect(count('showInterstitial'), 1);
    expect(count('showRewarded'), 0);
    expect(
      calls.lastWhere((call) => call.method == 'showInterstitial').arguments,
      containsPair('placement', 'nskdh_launch'),
    );
    expect(manager.isAdBusy, isTrue);
    expect(manager.adSessionVersion, 1);
    await emit('Displayed', rewarded: false);
    await emit('Hidden', rewarded: false);
    expect(await result, isTrue);
    expect(manager.isAdBusy, isFalse);
    expect(manager.adSessionVersion, 1);
    expect(manager.lastAdFinishedAt, isNotNull);
    expect(count('loadInterstitial'), 2, reason: '仅已消费广告关闭后正常补缓存');
  });

  test('CloudX缓存/付费/展示失败不报收入，只在本次显示成功上报且下一次展示独立计数', () async {
    await emit('Loaded');
    await emit('RevenuePaid');
    await emit('Displayed');
    expect(revenues, isEmpty, reason: '未请求展示时的迟到回调不属于本次展示');
    final failed = manager.requestRewarded('failed_rv');
    await flush();
    await emit('RevenuePaid');
    expect(revenues, isEmpty);
    await emit('DisplayFailed');
    expect(await failed, false);
    await emit('Displayed');
    expect(revenues, isEmpty);
    for (final amount in [0.02, 0.03]) {
      await emit('Loaded', revenue: amount);
      final result = manager.requestRewarded('scene_rv');
      await flush();
      await emit('RevenuePaid', revenue: 9);
      final before = revenues.length;
      await emit('Displayed', revenue: amount);
      expect(revenues, hasLength(before + 1));
      expect(revenues.last['revenue'], '$amount');
      await emit('Displayed', revenue: amount);
      await emit('RevenuePaid', revenue: amount);
      expect(revenues, hasLength(before + 1));
      await emit('Hidden');
      expect(await result, false);
    }
    expect(manager.getAdRevenue(), closeTo(.05, 1e-10));
  });

  test(
    'concurrent cache checks and repeated initialization issue only one load per placement',
    () async {
      manager.stopForTesting();
      calls.clear();
      requests.clear();
      readinessGate = Completer<bool>();
      await manager.init(readySources: {'cloudx'});
      manager.setSourceReady('cloudx');
      await manager.init(readySources: {'cloudx'});
      await flush();
      expect(count('isRewardedReady'), 1);
      expect(count('isInterstitialReady'), 1);
      expect(count('loadRewarded'), 0);
      readinessGate!.complete(false);
      await flush();
      readinessGate = null;
      manager.setSourceReady('cloudx');
      manager.setSourceReady('cloudx');
      await manager.init(readySources: {'cloudx'});
      await flush();
      expect(count('loadRewarded'), 1);
      expect(count('loadInterstitial'), 1);
      expect(requests, hasLength(2));
    },
  );

  test(
    'cached and currently showing ads survive reinitialization without replacing the reward callback',
    () async {
      await emit('Loaded');
      manager.setSourceReady('cloudx');
      await manager.init(readySources: {'cloudx'});
      await flush();
      expect(count('loadRewarded'), 1);
      final reward = manager.requestRewarded('scene_rv');
      await flush();
      await manager.init(readySources: {'cloudx'});
      manager.setSourceReady('cloudx');
      await flush();
      expect(count('loadRewarded'), 1);
      expect(count('showRewarded'), 1);
      await emit('ReceivedReward');
      await emit('Hidden');
      expect(await reward, isTrue);
      expect(count('loadRewarded'), 2);
    },
  );

  test(
    'manual retry cancels the pending timer; late failures never invalidate a cached ad',
    () async {
      await emit('LoadFailed');
      manager.setSourceReady('cloudx');
      manager.setSourceReady('cloudx');
      await flush();
      expect(count('loadRewarded'), 2);
      await emit('Loaded');
      await emit('LoadFailed'); // 迟到的旧请求失败不能清掉已经成功的缓存。
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      await flush();
      expect(count('loadRewarded'), 2);
      expect(requests.where((r) => r['ad_code_id'] == rewardId), hasLength(2));
      final reward = manager.requestRewarded('scene_rv');
      await flush();
      expect(count('showRewarded'), 1);
      await emit('ReceivedReward');
      await emit('Hidden');
      expect(await reward, isTrue);
    },
  );

  test(
    'late load success cancels the scheduled retry before another SDK cache check',
    () async {
      await emit('LoadFailed');
      final checks = count('isRewardedReady');
      await emit('Loaded');
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      await flush();
      expect(count('loadRewarded'), 1);
      expect(count('isRewardedReady'), checks);
    },
  );

  test(
    'duplicate configuration entries do not cause duplicate SDK loads',
    () async {
      manager.stopForTesting();
      calls.clear();
      final config = PCAdModel.fromJson(pc_defaultAdConfig);
      config.nkmdl_int = [config.nkmdl_int.last, config.nkmdl_int.last];
      config.nkmdl_rv = [config.nkmdl_rv.last, config.nkmdl_rv.last];
      await manager.init(inputAd: config, readySources: {'cloudx'});
      await flush();
      expect(count('loadRewarded'), 1);
      expect(count('loadInterstitial'), 1);
    },
  );
  test('repeated load failure coalesces to one retry', () async {
    await emit('LoadFailed');
    await emit('LoadFailed');
    expect(count('loadRewarded'), 1);
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    await flush();
    expect(count('loadRewarded'), 2);
    expect(manager.is_showAd, isFalse);
  });
}
