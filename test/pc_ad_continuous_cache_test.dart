// TopOn依赖原生平台通道，持续缓存维护在Flutter VM中验证。
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
  const _Unit(this.id, this.source, this.rewarded);
  final String id;
  final String source;
  final bool rewarded;
  String get placement =>
      rewarded ? 'continuous_cache_rv' : 'continuous_cache_int';
  String get check => source == 'cloudx'
      ? (rewarded ? 'isRewardedReady' : 'isInterstitialReady')
      : (rewarded ? 'rewardedVideoReady' : 'hasInterstitialAdReady');
  String get load => source == 'cloudx'
      ? (rewarded ? 'loadRewarded' : 'loadInterstitial')
      : (rewarded ? 'loadRewardedVideo' : 'loadInterstitialAd');
  String get show => source == 'cloudx'
      ? (rewarded ? 'showRewarded' : 'showInterstitial')
      : (rewarded ? 'showRewardedVideo' : 'showInterstitialAd');
  String get destroy => rewarded ? 'destroyRewarded' : 'destroyInterstitial';
}

const _units = [
  _Unit('keep-top-int-a', 'topon', false),
  _Unit('keep-cloud-int-a', 'cloudx', false),
  _Unit('keep-top-rv-a', 'topon', true),
  _Unit('keep-cloud-rv-a', 'cloudx', true),
  _Unit('keep-cloud-int-b', 'cloudx', false),
  _Unit('keep-top-rv-b', 'topon', true),
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
  final checkGates = <String, Completer<bool>>{};
  final loadGates = <String, Completer<String>>{};
  final afterLoad = <String, Future<void> Function(int attempt)>{};
  late PCFakeAudio fakeAudio;

  String? callId(MethodCall call) =>
      (call.arguments as Map?)?['adUnitId'] as String? ??
      (call.arguments as Map?)?['placementID'] as String?;

  int count(_Unit unit, String method) => calls
      .where((call) => call.method == method && callId(call) == unit.id)
      .length;

  Iterable<MethodCall> shows() => calls.where(
    (call) => const {
      'showRewarded',
      'showInterstitial',
      'showRewardedVideo',
      'showInterstitialAd',
    }.contains(call.method),
  );

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> waitFor(
    bool Function() predicate, {
    required String reason,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final watch = Stopwatch()..start();
    while (!predicate() && watch.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(predicate(), isTrue, reason: reason);
    await flush();
  }

  Future<dynamic> nativeCall(MethodCall call, {required bool cloud}) async {
    calls.add(call);
    if (call.method == 'isInitialized') return false;
    if (call.method == 'initialize') return {'success': true};
    final id = callId(call);
    if (_units.any((unit) => unit.check == call.method)) {
      if (checkGates[id] case final gate?) return gate.future;
      return ready[id] ?? false;
    }
    if (call.method == 'checkInterstitialLoadStatus' ||
        call.method == 'checkRewardedVideoLoadStatus') {
      return {
        'isLoading': nativeLoading[id] ?? false,
        'isReady': ready[id] ?? false,
      };
    }
    if (_units.any((unit) => unit.load == call.method)) {
      if (afterLoad[id] case final onLoad?) {
        final attempt = calls
            .where((old) => old.method == call.method && callId(old) == id)
            .length;
        // SDK回调是独立事件，不能由load方法的返回值代替。
        scheduleMicrotask(() => unawaited(onLoad(attempt)));
      }
      if (loadGates[id] case final gate?) return gate.future;
    }
    if (call.method == 'destroyRewarded' ||
        call.method == 'destroyInterstitial') {
      ready[id!] = false;
    }
    if (_units.any((unit) => unit.show == call.method)) ready[id!] = false;
    return cloud ? null : '';
  }

  Future<void> configure(List<_Unit> units, {Set<String>? readySources}) async {
    PCAdModellist model(_Unit unit) => PCAdModellist(
      byfxjhld: unit.id,
      dmhytwql: unit.source,
      ugebepat: unit.rewarded ? 'reward' : 'interstitial',
      gqqvwedz: 3000,
      wdzqbsbt: unit.source == 'cloudx' ? 3 : 2,
    );
    await manager.init(
      inputAd: PCAdModel(
        nkmdl_int: units.where((unit) => !unit.rewarded).map(model).toList(),
        nkmdl_rv: units.where((unit) => unit.rewarded).map(model).toList(),
      ),
      readySources: readySources ?? units.map((unit) => unit.source).toSet(),
    );
    await flush();
  }

  Future<void> emit(_Unit unit, String kind) async {
    if (kind == 'Loaded') ready[unit.id] = true;
    if (kind == 'Hidden' || kind == 'LoadFailed') ready[unit.id] = false;
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_sound_music': false,
    });
    await PCLocalProvider.instance.init();
    manager.stopForTesting();
    manager.skipAdForTesting = false;
    manager.loadTimeoutForTesting = const Duration(seconds: 30);
    manager.retryDelayForTesting = const Duration(milliseconds: 25);
    manager.cacheCheckIntervalForTesting = const Duration(milliseconds: 25);
    // 测试从不接触真实SDK初始化；需恢复源的场景再覆盖此hook。
    manager.retryAdSourceInitializationForTesting = (_) async {};
    manager.reportEvent = (name, data) =>
        events.add((name, Map<String, dynamic>.from(data)));
    manager.reportRevenue = (_) {};
    PCAnalytics.reporter = (_, _) {};
    calls.clear();
    events.clear();
    ready.clear();
    nativeLoading.clear();
    checkGates.clear();
    loadGates.clear();
    afterLoad.clear();
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
    await flush();
    await fakeAudio.audio.dispose();
    PCAudioUtils.overrideForTesting(null);
    manager.skipAdForTesting = null;
    manager.loadTimeoutForTesting = null;
    manager.retryDelayForTesting = null;
    manager.cacheCheckIntervalForTesting = null;
    manager.retryAdSourceInitializationForTesting = null;
    manager.reportEvent = originalEvent;
    manager.reportRevenue = originalRevenue;
    await PCAnalytics.flush();
    PCAnalytics.reporter = originalAnalytics;
    for (final channel in [cloudX, topOn, adjust, facebook]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final countToConfigure in [0, 1, 6]) {
    test('配置$countToConfigure个ID就独立并行请求$countToConfigure个，不固定为四条', () async {
      final units = _units.take(countToConfigure).toList();
      for (final unit in units) {
        checkGates[unit.id] = Completer<bool>();
      }
      await configure(units);
      for (final unit in units) {
        expect(count(unit, unit.check), 1, reason: '每条独立发起缓存检查');
        expect(count(unit, unit.load), 0);
      }
      for (final gate in checkGates.values) {
        gate.complete(false);
      }
      await flush();
      for (final unit in units) {
        expect(count(unit, unit.load), 1);
      }
      expect(
        calls
            .where((call) => _units.any((unit) => unit.load == call.method))
            .map(callId),
        unorderedEquals(units.map((unit) => unit.id)),
        reason: '不能额外请求模型之外的默认广告位，也不能固定只维护四条',
      );
      expect(shows(), isEmpty);
    });
  }

  for (final unit in _units.take(4)) {
    test('${unit.id}无用户操作时连续失败仍自动获取，拿到缓存后停止重复load', () async {
      afterLoad[unit.id] = (attempt) =>
          emit(unit, attempt < 4 ? 'LoadFailed' : 'Loaded');
      await configure([unit]);
      await waitFor(
        () => ready[unit.id] == true,
        reason: '不能依赖Try Again或再次点击业务入口才继续补量',
      );
      expect(count(unit, unit.load), 4);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(count(unit, unit.load), 4, reason: '有缓存后不重复load');
      expect(shows(), isEmpty, reason: '后台维护不自动展示');
    });
  }

  for (final unit in _units.take(4)) {
    test('${unit.id}漏回调时超时后自动继续获取直到缓存，不依赖手动重试', () async {
      manager.loadTimeoutForTesting = const Duration(milliseconds: 50);
      afterLoad[unit.id] = (attempt) async {
        if (attempt == 3) await emit(unit, 'Loaded');
      };
      await configure([unit]);
      await waitFor(
        () => ready[unit.id] == true,
        reason: '前两次未收到SDK回调后仍须后台自动发起下一轮',
      );
      expect(count(unit, unit.load), 3);
      if (unit.source == 'cloudx') {
        expect(count(unit, unit.destroy), 2, reason: '每次超时都先结束旧实例再补量');
      }
      final requests = events.where((event) => event.$1 == 'nkmdl_ad_request');
      expect(requests, hasLength(3));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(count(unit, unit.load), 3);
      expect(shows(), isEmpty);
    });
  }

  for (final unit in [_units[0], _units[2]]) {
    test('${unit.id}SDK仍loading时仅超时后重新派发，正常在途不重复请求', () async {
      manager.loadTimeoutForTesting = const Duration(milliseconds: 70);
      await configure([unit]);
      nativeLoading[unit.id] = true;
      await manager.retryMissingAds();
      await manager.retryMissingAds();
      await flush();
      expect(count(unit, unit.load), 1, reason: '尚未超时不应重复调用SDK');
      await waitFor(
        () => count(unit, unit.load) >= 2,
        reason: '超时后仍须派发下一次load，由TopOn内部合并真实在途的请求',
      );
      expect(count(unit, unit.load), 2);
      await emit(unit, 'Loaded');
      await Future<void>.delayed(const Duration(milliseconds: 110));
      expect(count(unit, unit.load), 2, reason: '拿到真实缓存后停止重试');
      expect(count(unit, unit.destroy), 0, reason: 'TopOn不使用CloudX销毁接口');
      expect(shows(), isEmpty);
    });
  }

  test('六条稳定缓存均持续检查，不重复请求其中任何ID', () async {
    await configure(_units);
    for (final unit in _units) {
      await emit(unit, 'Loaded');
    }
    final checks = {
      for (final unit in _units) unit.id: count(unit, unit.check),
    };
    await Future<void>.delayed(const Duration(milliseconds: 140));
    for (final unit in _units) {
      expect(count(unit, unit.load), 1);
      expect(count(unit, unit.check), greaterThan(checks[unit.id]!));
    }
    expect(shows(), isEmpty);
  });

  test('缓存静默失效后自动仅补缺失ID，其他缓存不受影响', () async {
    await configure(_units);
    for (final unit in _units) {
      await emit(unit, 'Loaded');
    }
    final missing = [_units[0], _units[4]];
    for (final unit in missing) {
      ready[unit.id] = false;
    }
    await waitFor(
      () => missing.every((unit) => count(unit, unit.load) == 2),
      reason: 'SDK缓存过期不一定发失败回调，需要后台巡检发现',
    );
    for (final unit in _units.where((unit) => !missing.contains(unit))) {
      expect(count(unit, unit.load), 1);
    }
    expect(shows(), isEmpty);
  });

  test('正在播放的ID不补不销毁，其他ID的失效缓存仍在后台补', () async {
    final units = _units.take(4).toList();
    final playing = _units[3];
    final missing = _units[0];
    await configure(units);
    for (final unit in units) {
      await emit(unit, 'Loaded');
    }
    final result = request(playing);
    await flush();
    expect(shows().map(callId), [playing.id]);
    ready[missing.id] = false;
    await waitFor(
      () => count(missing, missing.load) == 2,
      reason: '一个广告在播放不能阻挡其他ID补量',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(count(playing, playing.load), 1);
    expect(count(playing, playing.destroy), 0);
    expect(manager.isNativeAdShowing, isTrue);
    await emit(playing, 'ReceivedReward');
    await emit(playing, 'Hidden');
    expect(await result, isTrue);
    await waitFor(
      () => count(playing, playing.load) == 2,
      reason: '只有真实关闭后才补该ID',
    );
  });

  test('广告关闭后的补缓存不等待业务关闭Future完成', () async {
    final unit = _units[3];
    final callbackGate = Completer<void>();
    var enteredCallback = false;
    // 将周期拉长，确保关闭触发本身立即补量，而不是碰巧由巡检补上。
    manager.cacheCheckIntervalForTesting = const Duration(seconds: 30);
    await configure([unit]);
    await emit(unit, 'Loaded');
    manager.pc_showAd(
      null,
      unit.placement,
      rewarded: true,
      showDialog: false,
      onCacheResponse: (_) {},
      adDidClosed: (success) async {
        expect(success, isTrue);
        enteredCallback = true;
        await callbackGate.future;
      },
    );
    await flush();
    await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(enteredCallback, isTrue);
    expect(count(unit, unit.load), 2, reason: '不能因业务后续弹窗等待而停止补缓存');
    callbackGate.complete();
    await flush();
  });

  test('移除配置ID后旧缓存检查晚返回不能重新请求被移除ID', () async {
    final removed = _units[3];
    final retained = _units[0];
    await configure([removed, retained]);
    await emit(removed, 'Loaded');
    await emit(retained, 'Loaded');
    final checks = count(removed, removed.check);
    final oldCheck = Completer<bool>();
    checkGates[removed.id] = oldCheck;
    await waitFor(
      () => count(removed, removed.check) > checks,
      reason: '先建立一条旧配置缓存检查在途',
    );
    await configure([retained]);
    oldCheck.complete(false);
    checkGates.remove(removed.id);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(count(removed, removed.load), 1);
    expect(count(retained, retained.load), 1, reason: '仍配置且有缓存的ID继续复用');
  });

  test('配置增加ID时保留正在播放的owner，关闭后仍正常回调并补该ID', () async {
    final playing = _units[3];
    final cached = _units[0];
    final added = _units[4];
    await configure([playing, cached]);
    await emit(playing, 'Loaded');
    await emit(cached, 'Loaded');
    var completed = false;
    final result = request(playing);
    unawaited(result.then((_) => completed = true));
    await flush();
    await configure([playing, cached, added]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(manager.isNativeAdShowing, isTrue);
    expect(manager.quizAdPlaceID, playing.placement);
    expect(completed, isFalse);
    expect(count(playing, playing.load), 1);
    expect(count(playing, playing.destroy), 0);
    expect(count(cached, cached.load), 1);
    expect(count(added, added.load), 1);
    await emit(playing, 'ReceivedReward');
    await emit(playing, 'Hidden');
    expect(await result, isTrue);
    expect(count(playing, playing.load), 2);
  });

  test('配置移除在播ID时等真实关闭才退役，不能补回已移除的ID', () async {
    final playing = _units[3];
    final retained = _units[0];
    await configure([playing, retained]);
    await emit(playing, 'Loaded');
    await emit(retained, 'Loaded');
    final result = request(playing);
    await flush();
    await configure([retained]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(manager.isNativeAdShowing, isTrue);
    expect(count(playing, playing.load), 1);
    expect(count(playing, playing.destroy), 0);
    await emit(playing, 'ReceivedReward');
    await emit(playing, 'Hidden');
    expect(await result, isTrue);
    expect(manager.isAdBusy, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(count(playing, playing.load), 1, reason: '关闭后不再属于当前配置，不能补回旧ID');
    expect(count(retained, retained.load), 1);
  });

  test('停止后取消所有持续维护，迟到原生load错误不重开补量', () async {
    final unit = _units[2];
    final oldLoad = Completer<String>();
    loadGates[unit.id] = oldLoad;
    await configure([unit]);
    expect(count(unit, unit.load), 1);
    manager.stopForTesting();
    final callCount = calls.length;
    oldLoad.completeError(PlatformException(code: 'STOPPED_LOAD_ERROR'));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(calls, hasLength(callCount));
    expect(manager.isAdBusy, isFalse);
    expect(
      events.where((event) => event.$1 == 'nkmdl_ad_return_fail'),
      isEmpty,
    );
  });

  test('源未就绪不提前load，首次初始化失败后自动恢复并加载各源全部ID', () async {
    manager.loadTimeoutForTesting = const Duration(milliseconds: 50);
    final attempts = <String, int>{};
    for (final unit in _units) {
      // 本场景只延迟源初始化，原生load成功后及时回调，避免混入另一条加载超时。
      afterLoad[unit.id] = (_) => emit(unit, 'Loaded');
    }
    manager.retryAdSourceInitializationForTesting = (source) async {
      final attempt = attempts.update(
        source,
        (old) => old + 1,
        ifAbsent: () => 1,
      );
      if (source == 'topon' && attempt == 1) {
        throw StateError('TEST_SOURCE_INIT_TEMPORARILY_UNAVAILABLE');
      }
      manager.setSourceReady(source);
    };
    await configure(_units, readySources: {});
    for (final unit in _units) {
      expect(count(unit, unit.load), 0, reason: '源初始化成功之前不能调用原生load');
    }
    await waitFor(
      () => _units.every((unit) => count(unit, unit.load) == 1),
      reason: '初始化失败后无需再次点击，下一轮恢复成功须自动加载该源每个配置ID',
    );
    expect(attempts, {'topon': 2, 'cloudx': 1});
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(attempts, {'topon': 2, 'cloudx': 1}, reason: '已就绪的源不能持续重复初始化');
    for (final unit in _units) {
      expect(count(unit, unit.load), 1);
    }
    expect(shows(), isEmpty);
  });

  test('同一源多个ID等待初始化时只保留一条在途初始化，不叠加SDK初始化', () async {
    manager.loadTimeoutForTesting = const Duration(milliseconds: 50);
    final units = _units.where((unit) => unit.source == 'cloudx').toList();
    final initGate = Completer<void>();
    var attempts = 0;
    manager.retryAdSourceInitializationForTesting = (source) async {
      expect(source, 'cloudx');
      attempts++;
      await initGate.future;
      manager.setSourceReady(source);
    };
    try {
      await configure(units, readySources: {});
      await waitFor(() => attempts == 1, reason: '未就绪的源须独立于用户点击自动触发恢复');
      await Future<void>.delayed(const Duration(milliseconds: 160));
      expect(attempts, 1, reason: '同源多个ID及多个巡检周期不能并发初始化同一SDK');
      for (final unit in units) {
        expect(count(unit, unit.load), 0);
      }
      initGate.complete();
      await waitFor(
        () => units.every((unit) => count(unit, unit.load) == 1),
        reason: '源真正就绪后统一唤醒所有等待ID',
      );
      expect(attempts, 1);
    } finally {
      if (!initGate.isCompleted) initGate.complete();
      await flush();
    }
  });

  test('配置移除未就绪源后取消该源等待恢复，不再初始化或加载旧ID', () async {
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    final removed = _units[3];
    final retained = _units[0];
    final attempts = <String>[];
    manager.retryAdSourceInitializationForTesting = (source) async {
      attempts.add(source);
    };
    await configure([removed, retained], readySources: {'topon'});
    await emit(retained, 'Loaded');
    await configure([retained], readySources: {'topon'});
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(attempts, isEmpty);
    expect(count(removed, removed.load), 0);
    expect(count(retained, retained.load), 1);
    expect(shows(), isEmpty);
  });

  test('停止后取消未就绪源的等待恢复，不由旧周期重新初始化SDK', () async {
    manager.loadTimeoutForTesting = const Duration(milliseconds: 60);
    final unit = _units[2];
    var attempts = 0;
    manager.retryAdSourceInitializationForTesting = (_) async {
      attempts++;
    };
    await configure([unit], readySources: {});
    manager.stopForTesting();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(attempts, 0);
    expect(count(unit, unit.load), 0);
    expect(manager.isAdBusy, isFalse);
  });

  test('旧源初始化晚完成不能释放同源新配置的在途初始化锁', () async {
    manager.loadTimeoutForTesting = const Duration(milliseconds: 50);
    final removed = _units[3];
    final added = _units[4];
    final oldInit = Completer<void>();
    final newInit = Completer<void>();
    var attempts = 0;
    manager.retryAdSourceInitializationForTesting = (_) {
      attempts++;
      return attempts == 1 ? oldInit.future : newInit.future;
    };
    try {
      await configure([removed], readySources: {});
      await waitFor(() => attempts == 1, reason: '先建立旧配置的初始化在途状态');
      await configure([], readySources: {});
      await configure([added], readySources: {});
      await waitFor(() => attempts == 2, reason: '新配置应能启动自己的初始化尝试');
      oldInit.complete();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(attempts, 2, reason: '旧Future的finally不能删除新source token而再次并发初始化');
      manager.setSourceReady('cloudx');
      newInit.complete();
      await waitFor(
        () => count(added, added.load) == 1,
        reason: '只加载当前配置中的新ID',
      );
      expect(count(removed, removed.load), 0);
    } finally {
      if (!oldInit.isCompleted) oldInit.complete();
      if (!newInit.isCompleted) newInit.complete();
      await flush();
    }
  });
}
