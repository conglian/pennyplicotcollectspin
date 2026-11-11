// TopOn使用原生平台通道，广告加载恢复在Flutter VM下验证。
@TestOn('vm')
library;

import 'dart:async';

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
  String get id => 'recovery-$source-${rewarded ? 'rv' : 'int'}';
  String get placement => rewarded ? 'recovery_rv' : 'recovery_int';
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
  final nativeLoading = <String, bool>{};
  final failedChecks = <String>{};
  final failedLoads = <String>{};
  final failedStatusChecks = <String>{};
  final unknownStatusChecks = <String>{};
  final checkGates = <String, Completer<bool>>{};
  final loadGates = <String, Completer<String>>{};
  final destroyGates = <String, Completer<void>>{};
  late PCFakeAudio fakeAudio;

  String? callId(MethodCall call) =>
      (call.arguments as Map?)?['adUnitId'] as String? ??
      (call.arguments as Map?)?['placementID'] as String?;

  int count(_Unit unit, String method) => calls
      .where((call) => call.method == method && callId(call) == unit.id)
      .length;

  Iterable<(String, Map<String, dynamic>)> failures(_Unit unit) => events.where(
    (event) =>
        event.$1 == 'nkmdl_ad_return_fail' && event.$2['ad_code_id'] == unit.id,
  );

  List<MethodCall> shows() => calls
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
    if (call.method == 'checkInterstitialLoadStatus' ||
        call.method == 'checkRewardedVideoLoadStatus') {
      if (failedStatusChecks.contains(id)) {
        throw PlatformException(code: 'TEST_LOAD_STATUS_UNAVAILABLE');
      }
      if (unknownStatusChecks.contains(id)) return <String, dynamic>{};
      return {
        'isLoading': nativeLoading[id] ?? false,
        'isReady': ready[id] ?? false,
      };
    }
    if (_units.any((unit) => unit.load == call.method)) {
      if (failedLoads.contains(id)) {
        throw PlatformException(code: 'TEST_LOAD_BRIDGE_FAILED');
      }
      if (loadGates[id] case final gate?) return gate.future;
    }
    if (call.method == 'destroyRewarded' ||
        call.method == 'destroyInterstitial') {
      if (destroyGates[id] case final gate?) await gate.future;
      ready[id!] = false;
    }
    if (_units.any((unit) => unit.show == call.method)) ready[id!] = false;
    return cloud ? null : '';
  }

  Future<void> configure([List<_Unit> units = _units]) async {
    PCAdModellist model(_Unit unit) => PCAdModellist(
      byfxjhld: unit.id,
      dmhytwql: unit.source,
      ugebepat: unit.rewarded ? 'reward' : 'interstitial',
      gqqvwedz: 3000,
      wdzqbsbt: unit.source == 'topon' ? 2 : 3,
    );
    await manager.init(
      inputAd: PCAdModel(
        nkmdl_int: units.where((unit) => !unit.rewarded).map(model).toList(),
        nkmdl_rv: units.where((unit) => unit.rewarded).map(model).toList(),
      ),
      readySources: units.map((unit) => unit.source).toSet(),
    );
    await flush();
  }

  Future<void> emit(_Unit unit, String kind) async {
    if (kind == 'Loaded') ready[unit.id] = true;
    if (kind == 'Hidden') ready[unit.id] = false;
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
            'revenue': 0.0,
            'placement': unit.placement,
          },
          'error': {'code': 302, 'message': 'Test no fill'},
          'reward': {'amount': 1, 'label': 'coin'},
        },
      );
    } else {
      final name = switch (kind) {
        'Loaded' =>
          unit.rewarded
              ? 'rewardedVideoDidFinishLoading'
              : 'interstitialAdDidFinishLoading',
        'LoadFailed' =>
          unit.rewarded
              ? 'rewardedVideoDidFailToLoad'
              : 'interstitialAdFailToLoadAD',
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
          'requestMessage': 'Test no fill',
          'extraDic': {'publisher_revenue': 0.0},
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

  Future<void> retryMissing() async {
    await manager.retryMissingAds();
    await flush();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_sound_music': false,
    });
    await PCLocalProvider.instance.init();
    manager.stopForTesting();
    manager.skipAdForTesting = false;
    manager.loadTimeoutForTesting = const Duration(seconds: 30);
    manager.retryDelayForTesting = const Duration(seconds: 2);
    manager.reportEvent = (name, data) =>
        events.add((name, Map<String, dynamic>.from(data)));
    manager.reportRevenue = (_) {};
    PCAnalytics.reporter = (_, _) {};
    calls.clear();
    events.clear();
    ready.clear();
    nativeLoading.clear();
    failedChecks.clear();
    failedLoads.clear();
    failedStatusChecks.clear();
    unknownStatusChecks.clear();
    checkGates.clear();
    loadGates.clear();
    destroyGates.clear();
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
    manager.stopForTesting();
    for (final gate in checkGates.values) {
      if (!gate.isCompleted) gate.complete(false);
    }
    for (final gate in loadGates.values) {
      if (!gate.isCompleted) gate.complete('');
    }
    for (final gate in destroyGates.values) {
      if (!gate.isCompleted) gate.complete();
    }
    await flush();
    await fakeAudio.audio.dispose();
    PCAudioUtils.overrideForTesting(null);
    manager.skipAdForTesting = null;
    manager.loadTimeoutForTesting = null;
    manager.retryDelayForTesting = null;
    manager.reportEvent = originalEvent;
    manager.reportRevenue = originalRevenue;
    await PCAnalytics.flush();
    PCAnalytics.reporter = originalAnalytics;
    for (final channel in [cloudX, topOn, adjust, facebook]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  test('重复补量不重复请求正常在途的四条广告，也不自动播放', () async {
    await configure();
    await retryMissing();
    await retryMissing();
    for (final unit in _units) {
      expect(count(unit, unit.load), 1);
    }
    expect(shows(), isEmpty);
    expect(manager.isAdBusy, isFalse);
  });

  test('补量仅加载空闲缺失项，保留已有缓存和其他在途请求', () async {
    await configure();
    const cached = _Unit('cloudx', true);
    const failed = _Unit('topon', false);
    await emit(cached, 'Loaded');
    await emit(failed, 'LoadFailed');
    await retryMissing();
    expect(count(cached, cached.load), 1);
    expect(count(failed, failed.load), 2);
    for (final unit in _units.where((unit) => unit.id != failed.id)) {
      expect(count(unit, unit.load), 1);
    }
    expect(shows(), isEmpty);
  });

  for (final unit in _units) {
    test('${unit.id}没有成功或失败回调时超时释放，下一次补量可以重新load', () async {
      manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
      await configure([unit]);
      expect(count(unit, unit.load), 1);
      await Future<void>.delayed(const Duration(milliseconds: 110));
      manager.loadTimeoutForTesting = const Duration(seconds: 30);
      await retryMissing();
      expect(count(unit, unit.load), 2);
      expect(failures(unit), hasLength(1));
      if (unit.source == 'cloudx') {
        final destroy = unit.rewarded
            ? 'destroyRewarded'
            : 'destroyInterstitial';
        expect(count(unit, destroy), 1);
        final destroyIndex = calls.indexWhere(
          (call) => call.method == destroy && callId(call) == unit.id,
        );
        final reloadIndex = calls.lastIndexWhere(
          (call) => call.method == unit.load && callId(call) == unit.id,
        );
        expect(
          destroyIndex,
          lessThan(reloadIndex),
          reason: '先结束旧实例再重发，不能叠加load',
        );
      }
      expect(shows(), isEmpty);
      expect(manager.isAdBusy, isFalse);
      await retryMissing();
      expect(count(unit, unit.load), 2, reason: '新请求正常在途不能重复load');
    });
  }

  test('load回调丢失但SDK已经缓存时恢复缓存，不能重复请求或自动播放', () async {
    const unit = _Unit('topon', true);
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    await configure([unit]);
    ready[unit.id] = true;
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await retryMissing();
    expect(count(unit, unit.load), 1);
    expect(failures(unit), isEmpty);
    expect(shows(), isEmpty);
    final result = request(unit);
    await flush();
    expect(shows().map(callId), [unit.id]);
    await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await result, isTrue);
  });

  test('Loaded取消加载超时，重复回调不触发新的load', () async {
    const unit = _Unit('cloudx', true);
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    await configure([unit]);
    await emit(unit, 'Loaded');
    await emit(unit, 'Loaded');
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await retryMissing();
    expect(count(unit, unit.load), 1);
    expect(failures(unit), isEmpty);
  });

  test('明确LoadFailed取消加载超时，重复失败只记录一次并允许新请求', () async {
    const unit = _Unit('cloudx', false);
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    await configure([unit]);
    await emit(unit, 'LoadFailed');
    await emit(unit, 'LoadFailed');
    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(failures(unit), hasLength(1));
    manager.loadTimeoutForTesting = const Duration(seconds: 30);
    await retryMissing();
    expect(count(unit, unit.load), 2);
    await retryMissing();
    expect(count(unit, unit.load), 2);
  });

  test('旧TopOn load Future迟到抛错不能清理新一轮请求', () async {
    const unit = _Unit('topon', true);
    final oldLoad = Completer<String>();
    loadGates[unit.id] = oldLoad;
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    await configure([unit]);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    manager.loadTimeoutForTesting = const Duration(seconds: 30);
    loadGates.remove(unit.id);
    await retryMissing();
    expect(count(unit, unit.load), 2);
    final failuresBefore = failures(unit).length;
    oldLoad.completeError(PlatformException(code: 'OLD_LOAD_FAILED'));
    await flush();
    expect(failures(unit), hasLength(failuresBefore));
    await retryMissing();
    expect(count(unit, unit.load), 2, reason: '旧Future不能把新请求变为空闲');
    await emit(unit, 'Loaded');
    final result = request(unit);
    await flush();
    expect(shows().map(callId), [unit.id]);
    await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await result, isTrue);
  });

  test('TopOn load MethodChannel不返回时仍以Loaded回调完成缓存且可播放', () async {
    const unit = _Unit('topon', true);
    final nativeResult = Completer<String>();
    loadGates[unit.id] = nativeResult;
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    await configure([unit]);
    await emit(unit, 'Loaded');
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await retryMissing();
    expect(count(unit, unit.load), 1);
    expect(failures(unit), isEmpty);
    final result = request(unit);
    await flush();
    expect(shows().map(callId), [unit.id]);
    loadGates.remove(unit.id);
    nativeResult.completeError(PlatformException(code: 'LATE_NATIVE_RESULT'));
    await flush();
    expect(failures(unit), isEmpty);
    expect(manager.isNativeAdShowing, isTrue);
    await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await result, isTrue);
  });

  test('SDK缓存检查抛错后可以补量，不会永久保持检查中', () async {
    const unit = _Unit('topon', false);
    failedChecks.add(unit.id);
    await configure([unit]);
    expect(count(unit, unit.load), 1, reason: '检查异常不能永久阻止真正的load');
    failedChecks.clear();
    await retryMissing();
    expect(count(unit, unit.load), 1);
    await emit(unit, 'LoadFailed');
    await retryMissing();
    expect(count(unit, unit.load), 2);
    expect(shows(), isEmpty);
  });

  for (final rewarded in [false, true]) {
    final top = _Unit('topon', rewarded);
    test('${top.id}超时后可向仍在加载的SDK重派发，普通补量仍去重', () async {
      manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
      manager.retryDelayForTesting = const Duration(milliseconds: 20);
      await configure([top]);
      nativeLoading[top.id] = true;
      await retryMissing();
      expect(count(top, top.load), 1, reason: '尚未超时的请求不能被手动补量重复派发');
      await Future<void>.delayed(const Duration(milliseconds: 110));
      await flush();
      expect(count(top, top.load), 2, reason: '超时必须结束本地attempt并重派发，由SDK合并原生请求');
      expect(failures(top), hasLength(1));
      await retryMissing();
      expect(count(top, top.load), 2, reason: '新一轮未超时请求仍按正常在途去重');
      await emit(top, 'Loaded');
      await retryMissing();
      expect(count(top, top.load), 2, reason: '成功缓存后不再重派发load');
      expect(shows(), isEmpty);
    });

    final cloud = _Unit('cloudx', rewarded);
    test('${cloud.id}漏Loaded但有原生缓存时不销毁或重复load', () async {
      manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
      await configure([cloud]);
      ready[cloud.id] = true;
      await Future<void>.delayed(const Duration(milliseconds: 110));
      await retryMissing();
      expect(count(cloud, cloud.load), 1);
      expect(
        count(cloud, rewarded ? 'destroyRewarded' : 'destroyInterstitial'),
        0,
      );
      expect(failures(cloud), isEmpty);
      expect(shows(), isEmpty);
    });

    test('${cloud.id}销毁旧实例期间迟到Loaded不能展示，销毁后必须补新广告', () async {
      final pendingDestroy = Completer<void>();
      destroyGates[cloud.id] = pendingDestroy;
      manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
      await configure([cloud]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final destroy = rewarded ? 'destroyRewarded' : 'destroyInterstitial';
      expect(count(cloud, destroy), 1);
      await emit(cloud, 'Loaded'); // 旧实例在异步destroy完成前的迟到回调。
      await retryMissing();
      expect(await request(cloud), isFalse);
      expect(shows(), isEmpty, reason: '正在清理的旧缓存不能被当作本次可用广告');
      expect(count(cloud, cloud.load), 1);
      expect(count(cloud, destroy), 1);
      manager.loadTimeoutForTesting = const Duration(seconds: 30);
      pendingDestroy.complete();
      await flush();
      await retryMissing();
      expect(count(cloud, cloud.load), 2, reason: '旧Loaded不能取消销毁后的重新补量');
      expect(shows(), isEmpty);
    });

    for (final statusError in [false, true]) {
      final label = statusError ? '状态查询抛错' : '状态查询缺少isLoading';
      test('${top.id}$label时普通补量去重，超时仍能重派发下一次load', () async {
        manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
        manager.retryDelayForTesting = const Duration(milliseconds: 20);
        await configure([top]);
        final uncertain = statusError
            ? failedStatusChecks
            : unknownStatusChecks;
        uncertain.add(top.id);
        await retryMissing();
        expect(count(top, top.load), 1, reason: '普通在途不能因为用户重复补量而重派发');
        await Future<void>.delayed(const Duration(milliseconds: 110));
        await flush();
        expect(count(top, top.load), 2, reason: '状态未知不能让本地已超时attempt永远占位');
        expect(failures(top), hasLength(1));
        await retryMissing();
        expect(count(top, top.load), 2, reason: '重新发出的请求尚未超时，应继续去重');
        uncertain.remove(top.id);
        await emit(top, 'Loaded');
        await retryMissing();
        expect(count(top, top.load), 2);
        expect(shows(), isEmpty);
      });
    }
  }

  for (final source in ['topon', 'cloudx']) {
    final unit = _Unit(source, true);
    test('$source原生load桥接失败释放在途，下一次补量可以成功请求', () async {
      failedLoads.add(unit.id);
      await configure([unit]);
      expect(count(unit, unit.load), 1);
      expect(failures(unit), hasLength(1));
      failedLoads.clear();
      await retryMissing();
      expect(count(unit, unit.load), 2);
      await retryMissing();
      expect(count(unit, unit.load), 2);
      expect(shows(), isEmpty);
    });
  }

  test('SDK缓存检查不返回时超时结束，恢复后可正常load', () async {
    const unit = _Unit('topon', true);
    final pending = Completer<bool>();
    checkGates[unit.id] = pending;
    await configure([unit]);
    expect(count(unit, unit.load), 0);
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    checkGates.remove(unit.id);
    pending.complete(false);
    await retryMissing();
    expect(count(unit, unit.load), 1);
    expect(manager.isAdBusy, isFalse);
  });

  test('无缓存失败不会占用展示入口，丢失回调恢复后可再次播放并领奖', () async {
    const unit = _Unit('cloudx', true);
    manager.loadTimeoutForTesting = const Duration(milliseconds: 80);
    await configure();
    expect(await request(unit), isFalse);
    expect(manager.isAdBusy, isFalse);
    expect(manager.onAdClosed, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    manager.loadTimeoutForTesting = const Duration(seconds: 30);
    await retryMissing();
    for (final ad in _units) {
      expect(count(ad, ad.load), 2);
    }
    await emit(unit, 'Loaded');
    final result = request(unit);
    await flush();
    expect(shows().map(callId), [unit.id]);
    await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await result, isTrue);
    expect(manager.isAdBusy, isFalse);
  });

  test('停止旧管理器时取消加载超时，不影响随后新初始化的请求', () async {
    const unit = _Unit('topon', false);
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    await configure([unit]);
    manager.stopForTesting();
    manager.loadTimeoutForTesting = const Duration(seconds: 30);
    await configure([unit]);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await retryMissing();
    expect(count(unit, unit.load), 2);
    expect(failures(unit), isEmpty);
  });
}
