// TopOn原生桥接依赖dart:io，需在Flutter VM上验证。
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCModel/PCAdModel.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_ad_manger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_fake_audio.dart';
import 'support/pc_number_test_assets.dart';

class _Unit {
  const _Unit(this.source, this.rewarded);
  final String source;
  final bool rewarded;
  String get id => '$source-${rewarded ? 'rv' : 'int'}';
  String get placement => rewarded ? 'weight_test_rv' : 'weight_test_int';
  String get check => source == 'cloudx'
      ? (rewarded ? 'isRewardedReady' : 'isInterstitialReady')
      : (rewarded ? 'rewardedVideoReady' : 'hasInterstitialAdReady');
  String get load => source == 'cloudx'
      ? (rewarded ? 'loadRewarded' : 'loadInterstitial')
      : (rewarded ? 'loadRewardedVideo' : 'loadInterstitialAd');
  String get show => source == 'cloudx'
      ? (rewarded ? 'showRewarded' : 'showInterstitial')
      : (rewarded ? 'showRewardedVideo' : 'showInterstitialAd');
}

const _units = [
  _Unit('topon', false),
  _Unit('cloudx', false),
  _Unit('topon', true),
  _Unit('cloudx', true),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const cloudX = MethodChannel('cloudx_flutter_sdk');
  const topOn = MethodChannel('thinkup_sdk');
  const adjust = MethodChannel('com.adjust.sdk/api');
  const facebook = MethodChannel('com.example.pennyplicotcollectspin/facebook');
  final manager = PCPigAds();
  final originalEvent = manager.reportEvent;
  final originalRevenue = manager.reportRevenue;
  final originalAnalytics = PCAnalytics.reporter;
  final calls = <MethodCall>[];
  final events = <(String, Map<String, dynamic>)>[];
  final ready = <String, bool>{};
  final income = <String, double>{};
  final failedChecks = <String>{};
  final checkGates = <String, Completer<bool>>{};
  late PCFakeAudio fakeAudio;

  String? callId(MethodCall call) =>
      (call.arguments as Map?)?['adUnitId'] as String? ??
      (call.arguments as Map?)?['placementID'] as String?;

  int count(_Unit unit, String method) => calls
      .where((call) => call.method == method && callId(call) == unit.id)
      .length;

  List<MethodCall> getShows() => calls
      .where((call) => _units.any((unit) => unit.show == call.method))
      .toList();

  Future<void> flush() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<dynamic> nativeCall(MethodCall call, {required bool cloud}) async {
    calls.add(call);
    if (call.method == 'isInitialized') return false;
    if (call.method == 'initialize') return {'success': true};
    final id = callId(call);
    if (_units.any((unit) => unit.check == call.method)) {
      if (failedChecks.contains(id)) {
        throw PlatformException(code: 'TEST_CACHE_CHECK_FAILED');
      }
      if (checkGates[id] case final gate?) return gate.future;
      return ready[id] ?? false;
    }
    if (_units.any((unit) => unit.show == call.method)) ready[id!] = false;
    if (call.method.endsWith('ValidAds')) {
      return jsonEncode([
        {'publisher_revenue': income[id] ?? 0.0},
      ]);
    }
    return cloud ? null : '';
  }

  PCAdModel config({int topOnWeight = 2, int cloudXWeight = 3}) {
    PCAdModellist model(_Unit unit) => PCAdModellist(
      byfxjhld: unit.id,
      dmhytwql: unit.source,
      ugebepat: unit.rewarded ? 'reward' : 'interstitial',
      gqqvwedz: 3000,
      wdzqbsbt: unit.source == 'topon' ? topOnWeight : cloudXWeight,
    );
    return PCAdModel(
      nkmdl_int: _units.where((unit) => !unit.rewarded).map(model).toList(),
      nkmdl_rv: _units.where((unit) => unit.rewarded).map(model).toList(),
    );
  }

  Future<void> configure({int topOnWeight = 2, int cloudXWeight = 3}) async {
    await manager.init(
      inputAd: config(topOnWeight: topOnWeight, cloudXWeight: cloudXWeight),
      readySources: {'topon', 'cloudx'},
    );
    await flush();
  }

  Future<void> emit(_Unit unit, String kind) async {
    if (kind == 'Loaded') ready[unit.id] = true;
    if (kind == 'Hidden' || kind == 'DisplayFailed') ready[unit.id] = false;
    final MethodCall call;
    if (unit.source == 'cloudx') {
      call = MethodCall(
        'On${unit.rewarded ? 'Rewarded' : 'Interstitial'}${kind}Event',
        {
          'adUnitId': unit.id,
          'ad': {
            'adUnitId': unit.id,
            'adFormat': unit.rewarded ? 'rewarded' : 'interstitial',
            'networkName': 'Test Network',
            'revenue': income[unit.id] ?? 0.0,
            'placement': unit.placement,
          },
          'error': {'code': 302, 'message': 'Test failure'},
          'reward': {'amount': 1, 'label': 'coin'},
        },
      );
    } else {
      final name = switch (kind) {
        'Loaded' =>
          unit.rewarded
              ? 'rewardedVideoDidFinishLoading'
              : 'interstitialAdDidFinishLoading',
        'Displayed' =>
          unit.rewarded
              ? 'rewardedVideoDidStartPlaying'
              : 'interstitialDidShowSucceed',
        'Hidden' =>
          unit.rewarded ? 'rewardedVideoDidClose' : 'interstitialAdDidClose',
        'ReceivedReward' => 'rewardedVideoDidRewardSuccess',
        _ => throw StateError('Unknown test event: $kind'),
      };
      call = MethodCall(
        unit.rewarded ? 'RewardedVideoCall' : 'InterstitialCall',
        {
          'placementID': unit.id,
          'callbackName': name,
          'requestMessage': '',
          'extraDic': {'publisher_revenue': income[unit.id] ?? 0.0},
        },
      );
    }
    final result = Completer<void>();
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      unit.source == 'cloudx' ? cloudX.name : topOn.name,
      const StandardMethodCodec().encodeMethodCall(call),
      (_) => result.complete(),
    );
    await result.future;
    await flush();
  }

  Future<bool> request(_Unit unit) => unit.rewarded
      ? manager.requestRewarded(unit.placement)
      : manager.requestInterstitial(unit.placement);

  Future<void> finish(_Unit unit, Future<bool> result) async {
    if (unit.rewarded) await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await result, isTrue);
    expect(manager.isAdBusy, isFalse);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_sound_music': false,
    });
    await PCLocalProvider.instance.init();
    manager.stopForTesting();
    manager.skipAdForTesting = false;
    manager.reportEvent = (name, data) =>
        events.add((name, Map<String, dynamic>.from(data)));
    manager.reportRevenue = (_) {};
    PCAnalytics.reporter = (_, _) {};
    calls.clear();
    events.clear();
    ready.clear();
    income.clear();
    failedChecks.clear();
    checkGates.clear();
    messenger.setMockMethodCallHandler(
      cloudX,
      (call) => nativeCall(call, cloud: true),
    );
    messenger.setMockMethodCallHandler(
      topOn,
      (call) => nativeCall(call, cloud: false),
    );
    messenger.setMockMethodCallHandler(adjust, (_) async => null);
    messenger.setMockMethodCallHandler(facebook, (_) async => null);
    expect((await CloudX.initialize(appKey: 'test-key')).success, isTrue);
    fakeAudio = PCFakeAudio();
    PCAudioUtils.overrideForTesting(fakeAudio.audio);
  });

  tearDown(() async {
    for (final gate in checkGates.values) {
      if (!gate.isCompleted) gate.complete(false);
    }
    manager.stopForTesting();
    await flush();
    await fakeAudio.audio.dispose();
    PCAudioUtils.overrideForTesting(null);
    manager.skipAdForTesting = null;
    manager.reportEvent = originalEvent;
    manager.reportRevenue = originalRevenue;
    await PCAnalytics.flush();
    PCAnalytics.reporter = originalAnalytics;
    for (final channel in [cloudX, topOn, adjust, facebook]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test('四个广告位同时检查并请求，检查和加载在途时重复初始化不重复请求', () async {
    for (final unit in _units) {
      checkGates[unit.id] = Completer<bool>();
    }
    await configure();
    for (final unit in _units) {
      expect(count(unit, unit.check), 1);
      expect(count(unit, unit.load), 0);
    }
    await configure();
    manager.setSourceReady('topon');
    manager.setSourceReady('cloudx');
    await flush();
    for (final unit in _units) {
      expect(count(unit, unit.check), 1);
      checkGates[unit.id]!.complete(false);
    }
    checkGates.clear();
    await flush();
    await configure();
    for (final unit in _units) {
      expect(count(unit, unit.load), 1);
    }
    expect(
      events.where((event) => event.$1 == 'nkmdl_ad_request'),
      hasLength(4),
    );
  });

  for (final rewarded in [false, true]) {
    final top = _Unit('topon', rewarded);
    final cloud = _Unit('cloudx', rewarded);
    final format = rewarded ? '激励' : '插屏';

    test('$format同时缓存按配置权重选CloudX，即使TopOn收益更高也不比价', () async {
      await configure();
      income[top.id] = 100.0;
      income[cloud.id] = 0.001;
      await emit(top, 'Loaded');
      await emit(cloud, 'Loaded');
      final result = request(cloud);
      await flush();
      expect(getShows().map(callId), [cloud.id]);
      expect(getShows().single.method, cloud.show);
      await finish(cloud, result);
    });

    test('$format高权重缓存已失效时继续检查并播放另一平台缓存', () async {
      await configure();
      income[cloud.id] = 100.0;
      await emit(top, 'Loaded');
      await emit(cloud, 'Loaded');
      ready[cloud.id] = false;
      final result = request(top);
      await flush();
      expect(getShows().map(callId), [top.id]);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );
      await finish(top, result);
    });

    test('$format高权重平台缓存检查异常不阻断另一平台缓存播放', () async {
      await configure();
      income[cloud.id] = 100.0;
      await emit(top, 'Loaded');
      await emit(cloud, 'Loaded');
      failedChecks.add(cloud.id);
      final result = request(top);
      await flush();
      expect(getShows().map(callId), [top.id]);
      failedChecks.clear();
      await finish(top, result);
    });

    test('${format}TopOn补量缓存检查挂起也不等待，立即播放已Loaded的CloudX', () async {
      await configure(topOnWeight: 9, cloudXWeight: 1);
      await emit(cloud, 'Loaded');
      final topChecks = count(top, top.check);
      checkGates[top.id] = Completer<bool>();
      var completed = false;
      final result = request(cloud);
      unawaited(result.then((_) => completed = true));
      await flush();
      expect(getShows().map(callId), [cloud.id]);
      expect(count(top, top.check), topChecks, reason: '唯一已缓存广告不等待其他平台补量');
      expect(completed, isFalse, reason: '不能先回失败，再由迟到回调展示广告');
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );
      await finish(cloud, result);
    });

    test('$format两家都无缓存才失败，单次入口只报一次失败且不重复load', () async {
      await configure();
      expect(await request(cloud), isFalse);
      await flush();
      expect(getShows(), isEmpty);
      expect(manager.isAdBusy, isFalse);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_chance'),
        hasLength(1),
      );
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        hasLength(1),
      );
      for (final unit in _units) {
        expect(count(unit, unit.load), 1);
      }
    });

    for (final source in ['topon', 'cloudx']) {
      final first = _Unit(source, rewarded);
      final second = _Unit(source == 'topon' ? 'cloudx' : 'topon', rewarded);
      test('$format$source关闭补量未返回时直接播放另一平台已有缓存', () async {
        await configure(
          topOnWeight: source == 'topon' ? 5 : 2,
          cloudXWeight: source == 'cloudx' ? 5 : 2,
        );
        await emit(first, 'Loaded');
        await emit(second, 'Loaded');
        final firstResult = request(first);
        await flush();
        expect(getShows().map(callId), [first.id]);
        await finish(first, firstResult);
        expect(count(first, first.load), 2, reason: '已消费广告立即补量');
        expect(count(second, second.load), 1, reason: '另一平台缓存不重复load');
        final secondResult = request(second);
        await flush();
        expect(getShows().map(callId), [first.id, second.id]);
        await finish(second, secondResult);
      });

      test('$format只有$source有缓存时不等待另一平台加载', () async {
        await configure();
        await emit(first, 'Loaded');
        final result = request(first);
        await flush();
        expect(getShows().map(callId), [first.id]);
        expect(count(second, second.load), 1);
        await finish(first, result);
      });
    }

    test('$format相同广告位仅更新权重即改变优先平台，已有缓存保留', () async {
      await configure();
      income[cloud.id] = 100.0;
      await emit(top, 'Loaded');
      await emit(cloud, 'Loaded');
      await configure(topOnWeight: 6, cloudXWeight: 1);
      expect(count(top, top.load), 1);
      expect(count(cloud, cloud.load), 1);
      final result = request(top);
      await flush();
      expect(getShows().map(callId), [top.id]);
      await finish(top, result);
    });
  }

  test('关闭后逐项补失效缓存，保留其余缓存并跳过在途请求', () async {
    await configure();
    income[const _Unit('cloudx', true).id] = 100.0;
    for (final unit in _units) {
      await emit(unit, 'Loaded');
    }
    const cloudReward = _Unit('cloudx', true);
    const topReward = _Unit('topon', true);
    const topInt = _Unit('topon', false);
    const cloudInt = _Unit('cloudx', false);
    // 其他类型的缓存也可能已被SDK回收，关闭后的补量需核对四条真实缓存。
    ready[topInt.id] = false;
    final result = request(cloudReward);
    await flush();
    expect(getShows().map(callId), [cloudReward.id]);
    await finish(cloudReward, result);
    expect(count(cloudReward, cloudReward.load), 2);
    expect(count(topInt, topInt.load), 2);
    expect(count(topReward, topReward.load), 1);
    expect(count(cloudInt, cloudInt.load), 1);
    manager.setSourceReady('topon');
    manager.setSourceReady('cloudx');
    await flush();
    expect(count(cloudReward, cloudReward.load), 2);
    expect(count(topInt, topInt.load), 2);
  });
}
