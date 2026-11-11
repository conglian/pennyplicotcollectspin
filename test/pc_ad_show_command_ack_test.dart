// TopOn原生通道依赖dart:io，需在Flutter VM中验证不返回result的show命令。
@TestOn('vm')
library;

import 'dart:async';

import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCModel/PCAdModel.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_ad_manger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_fake_audio.dart';
import 'support/pc_number_test_assets.dart';

class _Unit {
  const _Unit(this.source, this.rewarded);
  final String source;
  final bool rewarded;
  String get id => 'show-ack-$source-${rewarded ? 'rv' : 'int'}';
  String get placement => 'show_ack_${rewarded ? 'rv' : 'int'}';
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
  final ready = <String, bool>{};
  final calls = <MethodCall>[];
  final events = <(String, Map<String, dynamic>)>[];
  final pendingCommands = <String, List<Completer<String>>>{};
  final pendingCacheChecks = <String, Completer<bool>>{};
  final allGates = <Completer<String>>[];
  final failShow = <String>{};
  late PCFakeAudio audio;

  String? callId(MethodCall call) =>
      (call.arguments as Map?)?['adUnitId'] as String? ??
      (call.arguments as Map?)?['placementID'] as String?;

  int shows(_Unit unit) => calls
      .where((call) => call.method == unit.show && callId(call) == unit.id)
      .length;

  Future<void> flush() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Completer<String> hangNextShow(_Unit unit) {
    final gate = Completer<String>();
    allGates.add(gate);
    pendingCommands.putIfAbsent(unit.id, () => []).add(gate);
    return gate;
  }

  Future<dynamic> nativeCall(MethodCall call, {required bool cloud}) async {
    calls.add(call);
    if (call.method == 'isInitialized') return false;
    if (call.method == 'initialize') return {'success': true};
    final id = callId(call);
    if ({
      'isRewardedReady',
      'isInterstitialReady',
      'rewardedVideoReady',
      'hasInterstitialAdReady',
    }.contains(call.method)) {
      final cacheCheck = pendingCacheChecks.remove(id);
      if (cacheCheck != null) return cacheCheck.future;
      return ready[id] ?? false;
    }
    if ({
      'checkRewardedVideoLoadStatus',
      'checkInterstitialLoadStatus',
    }.contains(call.method)) {
      return {'isLoading': false, 'isReady': ready[id] ?? false};
    }
    if (_units.any((unit) => unit.show == call.method)) {
      expect(audio.backgrounds.single.playing, isFalse);
      ready[id!] = false;
      if (failShow.contains(id)) {
        throw PlatformException(code: 'TEST_SHOW_COMMAND_FAILED');
      }
      final queue = pendingCommands[id];
      if (queue != null && queue.isNotEmpty) return queue.removeAt(0).future;
    }
    if (call.method.endsWith('ValidAds')) return '[]';
    return cloud ? null : '';
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
            'revenue': 0.0,
            'placement': unit.placement,
          },
          'error': {'code': 302, 'message': 'Test show failure'},
          'reward': {'amount': 1, 'label': 'coin'},
        },
      );
    } else {
      final callback = switch (kind) {
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
        'Ended' => 'rewardedVideoDidEndPlaying',
        'LoadFailed' =>
          unit.rewarded
              ? 'rewardedVideoDidFailToLoad'
              : 'interstitialAdFailToLoadAD',
        'DisplayFailed' =>
          unit.rewarded
              ? 'rewardedVideoDidFailToPlay'
              : 'interstitialFailedToShow',
        _ => throw StateError('Unknown test event: $kind'),
      };
      call = MethodCall(
        unit.rewarded ? 'RewardedVideoCall' : 'InterstitialCall',
        {
          'placementID': unit.id,
          'callbackName': callback,
          'requestMessage': '',
          'extraDic': {'publisher_revenue': 0.0},
        },
      );
    }
    final done = Completer<void>();
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      unit.source == 'cloudx' ? cloudX.name : topOn.name,
      const StandardMethodCodec().encodeMethodCall(call),
      (_) => done.complete(),
    );
    await done.future;
    await flush();
  }

  Future<bool> request(_Unit unit, {String? placement}) => unit.rewarded
      ? manager.requestRewarded(placement ?? unit.placement)
      : manager.requestInterstitial(placement ?? unit.placement);

  Future<PCAdOutcome> requestOutcome(_Unit unit) => unit.rewarded
      ? PCRewardedAdService.instance.requestOutcome(unit.placement)
      : PCInterstitialAdService.instance.requestOutcome(unit.placement);

  Future<void> finish(_Unit unit, Future<bool> result) async {
    if (unit.rewarded) await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await result.timeout(const Duration(seconds: 1)), isTrue);
  }

  Future<void> prepareNext(_Unit unit) async {
    await emit(unit, 'Loaded');
    expect(audio.backgrounds.single.playing, isTrue);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': true,
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
    ready
      ..clear()
      ..addEntries(_units.map((unit) => MapEntry(unit.id, true)));
    pendingCommands.clear();
    pendingCacheChecks.clear();
    allGates.clear();
    failShow.clear();
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
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    audio = PCFakeAudio();
    PCAudioUtils.overrideForTesting(audio.audio);
    await audio.audio.initializeForStartup(
      isNativeAdShowing: () => manager.isNativeAdShowing,
    );
    PCAdModellist model(_Unit unit) => PCAdModellist(
      byfxjhld: unit.id,
      dmhytwql: unit.source,
      ugebepat: unit.rewarded ? 'reward' : 'interstitial',
      wdzqbsbt: unit.source == 'topon' ? 2 : 1,
    );
    await manager.init(
      inputAd: PCAdModel(
        nkmdl_int: _units.where((u) => !u.rewarded).map(model).toList(),
        nkmdl_rv: _units.where((u) => u.rewarded).map(model).toList(),
      ),
      readySources: {'topon', 'cloudx'},
    );
    await flush();
  });

  tearDown(() async {
    for (final gate in allGates) {
      if (!gate.isCompleted) gate.complete('');
    }
    await flush();
    manager.stopForTesting();
    await flush();
    await audio.audio.dispose();
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

  for (final unit in _units) {
    final label = '${unit.source}${unit.rewarded ? '激励' : '插屏'}';
    test('$label服务typed结果成功关闭为success', () async {
      if (unit.source == 'cloudx') {
        ready[_Unit('topon', unit.rewarded).id] = false;
      }
      final result = requestOutcome(unit);
      await flush();
      await emit(unit, 'Displayed');
      expect(await requestOutcome(unit), PCAdOutcome.cancelled);
      if (unit.rewarded) await emit(unit, 'ReceivedReward');
      await emit(unit, 'Hidden');
      expect(
        await result.timeout(const Duration(seconds: 1)),
        PCAdOutcome.success,
      );
    });

    test('$label真实SDK失败与无缓存typed结果均为failed', () async {
      if (unit.source == 'cloudx') {
        ready[_Unit('topon', unit.rewarded).id] = false;
      }
      final result = requestOutcome(unit);
      await flush();
      await emit(unit, 'DisplayFailed');
      expect(
        await result.timeout(const Duration(seconds: 1)),
        PCAdOutcome.failed,
      );
      ready[_Unit('topon', unit.rewarded).id] = false;
      ready[_Unit('cloudx', unit.rewarded).id] = false;
      expect(await requestOutcome(unit), PCAdOutcome.failed);
    });

    test('${label}skip模式typed仍直接成功且不调用真实展示', () async {
      manager.skipAdForTesting = true;
      expect(await requestOutcome(unit), PCAdOutcome.success);
      expect(shows(unit), 0);
      expect(manager.isNativeAdShowing, isFalse);
    });

    test('$label真实展示后同笔show命令迟到异常不能改判失败', () async {
      if (unit.source == 'cloudx') {
        ready[_Unit('topon', unit.rewarded).id] = false;
      }
      final gate = hangNextShow(unit);
      final results = <bool>[];
      final result = request(unit).then((value) {
        results.add(value);
        return value;
      });
      await flush();
      await emit(unit, 'Displayed');
      if (unit.rewarded) await emit(unit, 'ReceivedReward');
      gate.completeError(PlatformException(code: 'LATE_CURRENT_COMMAND_ERROR'));
      await flush();

      expect(results, isEmpty);
      expect(manager.isNativeAdShowing, isTrue);
      expect(manager.quizAdPlaceID, unit.placement);
      expect(audio.backgrounds.single.playing, isFalse);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );

      await emit(unit, 'Hidden');
      expect(await result.timeout(const Duration(seconds: 1)), isTrue);
      await emit(unit, 'Hidden');
      await emit(unit, 'DisplayFailed');
      expect(results, [true]);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );
      expect(audio.backgrounds.single.playing, isTrue);
    });

    test('$label后台加载失败不能影响当前已展示广告', () async {
      if (unit.source == 'cloudx') {
        ready[_Unit('topon', unit.rewarded).id] = false;
      }
      var finished = false;
      final result = request(unit).then((value) {
        finished = true;
        return value;
      });
      await flush();
      await emit(unit, 'Displayed');
      await emit(unit, 'LoadFailed');
      await emit(
        _Unit(unit.source == 'topon' ? 'cloudx' : 'topon', unit.rewarded),
        'LoadFailed',
      );
      expect(finished, isFalse);
      expect(manager.isNativeAdShowing, isTrue);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );
      await finish(unit, result);
    });

    if (!unit.rewarded) continue;
    test('$label主动关闭未获激励为cancelled且第二笔拒绝不改第一笔结果', () async {
      if (unit.source == 'cloudx') ready[_Unit('topon', true).id] = false;
      final result = requestOutcome(unit);
      await flush();
      await emit(unit, 'Displayed');
      expect(await requestOutcome(unit), PCAdOutcome.cancelled);
      if (unit.source == 'topon') await emit(unit, 'Ended');
      await emit(unit, 'Hidden');
      expect(
        await result.timeout(const Duration(seconds: 1)),
        PCAdOutcome.cancelled,
      );
      expect(manager.isAdBusy, isFalse);
    });
    test('$label真实激励成功后迟到SDK失败不撤销奖励资格', () async {
      if (unit.source == 'cloudx') ready[_Unit('topon', true).id] = false;
      var finished = false;
      final result = request(unit).then((value) {
        finished = true;
        return value;
      });
      await flush();
      await emit(unit, 'Displayed');
      await emit(unit, 'ReceivedReward');
      await emit(unit, 'DisplayFailed');
      expect(finished, isFalse);
      expect(manager.isNativeAdShowing, isTrue);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );
      await emit(unit, 'Hidden');
      expect(await result.timeout(const Duration(seconds: 1)), isTrue);
    });

    test('$label仅展示或播放结束但没有真实激励成功仍不发奖励', () async {
      if (unit.source == 'cloudx') ready[_Unit('topon', true).id] = false;
      final gate = hangNextShow(unit);
      final result = request(unit);
      await flush();
      await emit(unit, 'Displayed');
      if (unit.source == 'topon') await emit(unit, 'Ended');
      gate.completeError(
        PlatformException(code: 'LATE_COMMAND_ERROR_NO_REWARD'),
      );
      await flush();
      expect(manager.isNativeAdShowing, isTrue);
      await emit(unit, 'Hidden');
      expect(await result.timeout(const Duration(seconds: 1)), isFalse);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        isEmpty,
      );
    });

    test('$label真实播放错误且没有激励成功仍返回失败', () async {
      if (unit.source == 'cloudx') ready[_Unit('topon', true).id] = false;
      final result = request(unit);
      await flush();
      await emit(unit, 'Displayed');
      await emit(unit, 'DisplayFailed');
      expect(await result.timeout(const Duration(seconds: 1)), isFalse);
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        hasLength(1),
      );
      await emit(unit, 'Hidden');
      expect(
        events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
        hasLength(1),
      );
    });
  }

  test('缓存检查在途第二笔只取消且不把当前成功请求覆盖成失败', () async {
    const unit = _Unit('topon', true);
    final cacheCheck = Completer<bool>();
    pendingCacheChecks[unit.id] = cacheCheck;
    addTearDown(() {
      if (!cacheCheck.isCompleted) cacheCheck.complete(false);
    });
    final first = requestOutcome(unit);
    await flush();
    expect(manager.isAdBusy, isTrue);
    expect(manager.isNativeAdShowing, isFalse);
    expect(shows(unit), 0);
    expect(
      await requestOutcome(const _Unit('cloudx', true)),
      PCAdOutcome.cancelled,
    );
    expect(manager.quizAdPlaceID, unit.placement);
    cacheCheck.complete(true);
    await flush();
    await emit(unit, 'Displayed');
    await emit(unit, 'ReceivedReward');
    await emit(unit, 'Hidden');
    expect(await first, PCAdOutcome.success);
    expect(manager.onAdClosed, isNull);
  });

  test('typed先回调且旧业务异常或Future结束不能清理下一笔广告owner', () async {
    const first = _Unit('topon', true);
    const next = _Unit('cloudx', true);
    final callbackGate = Completer<void>();
    final seen = <Object>[];
    Future<PCAdOutcome>? nextResult;
    manager.pc_showAd(
      null,
      first.placement,
      rewarded: true,
      showDialog: false,
      onCacheResponse: (_) {},
      onOutcome: (outcome) {
        seen.add(outcome);
        nextResult = requestOutcome(next);
        return callbackGate.future;
      },
      adDidClosed: (value) {
        seen.add(value);
        throw StateError('business callback failure is not ad failure');
      },
    );
    await flush();
    await emit(first, 'Displayed');
    await emit(first, 'ReceivedReward');
    await emit(first, 'Hidden');
    expect(seen, [PCAdOutcome.success, true]);
    expect(shows(next), 1);
    expect(manager.onAdClosed, isNotNull);
    callbackGate.complete();
    await flush();
    expect(manager.isNativeAdShowing, isTrue);
    expect(manager.onAdClosed, isNotNull);
    await emit(next, 'Displayed');
    await emit(next, 'ReceivedReward');
    await emit(next, 'Hidden');
    expect(await nextResult!, PCAdOutcome.success);
  });

  for (final rewarded in [false, true]) {
    final first = _Unit('topon', rewarded);
    final label = rewarded ? '激励' : '插屏';
    test('CloudX$label原生show命令立即异常仍安全失败并释放BGM和owner', () async {
      final unit = _Unit('cloudx', rewarded);
      ready[first.id] = false;
      failShow.add(unit.id);
      expect(await request(unit).timeout(const Duration(seconds: 1)), isFalse);
      await flush();
      expect(shows(unit), 1);
      expect(manager.isAdBusy, isFalse);
      expect(manager.isNativeAdShowing, isFalse);
      expect(manager.onAdClosed, isNull);
      expect(audio.backgrounds.single.playing, isTrue);
    });

    for (final nextSource in ['cloudx', 'topon']) {
      final next = _Unit(nextSource, rewarded);
      test('TopOn$label命令不回result，真实关闭后可继续播放$nextSource缓存', () async {
        final gate = hangNextShow(first);
        final firstResult = request(first);
        await flush();
        expect(shows(first), 1);
        await emit(first, 'Displayed');
        await finish(first, firstResult);
        expect(gate.isCompleted, isFalse);
        expect(manager.isAdBusy, isFalse);
        expect(audio.backgrounds.single.playing, isTrue);
        if (nextSource == 'topon') await prepareNext(next);
        final secondResult = request(
          next,
          placement: 'second_${next.placement}',
        );
        await flush();
        expect(shows(next), nextSource == 'topon' ? 2 : 1);
        expect(manager.quizAdPlaceID, 'second_${next.placement}');
        expect(
          events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
          isEmpty,
        );
        await finish(next, secondResult);
      });

      test('TopOn$label旧show命令迟到异常不清理正在播放的$nextSource新owner', () async {
        final gate = hangNextShow(first);
        final firstResult = request(first);
        await flush();
        await emit(first, 'Displayed');
        await finish(first, firstResult);
        if (nextSource == 'topon') await prepareNext(next);
        var secondClosed = false;
        final secondResult =
            request(next, placement: 'current_${next.placement}').then((value) {
              secondClosed = true;
              return value;
            });
        await flush();
        expect(shows(next), nextSource == 'topon' ? 2 : 1);
        gate.completeError(PlatformException(code: 'LATE_OLD_SHOW_FAILURE'));
        await flush();
        expect(secondClosed, isFalse);
        expect(manager.isNativeAdShowing, isTrue);
        expect(manager.quizAdPlaceID, 'current_${next.placement}');
        expect(manager.onAdClosed, isNotNull);
        expect(audio.backgrounds.single.playing, isFalse);
        expect(
          events.where((event) => event.$1 == 'nkmdl_ad_impression_fail'),
          isEmpty,
        );
        await finish(next, secondResult);
      });
    }

    test('TopOn$label命令立即失败仍返回false并释放BGM和owner', () async {
      failShow.add(first.id);
      expect(await request(first).timeout(const Duration(seconds: 1)), isFalse);
      await flush();
      expect(manager.isAdBusy, isFalse);
      expect(manager.isNativeAdShowing, isFalse);
      expect(manager.onAdClosed, isNull);
      expect(audio.backgrounds.single.playing, isTrue);
    });

    test('TopOn$label命令不回result且尚未真实关闭时仍阻止第二条展示', () async {
      hangNextShow(first);
      final firstResult = request(first);
      await flush();
      final second = _Unit('cloudx', rewarded);
      expect(await request(second), isFalse);
      expect(shows(first), 1);
      expect(shows(second), 0);
      expect(manager.isNativeAdShowing, isTrue);
      expect(audio.backgrounds.single.playing, isFalse);
      await finish(first, firstResult);
    });

    test('TopOn$label命令ack成功不等于SDK业务完成', () async {
      var closed = false;
      final result = request(first).then((value) {
        closed = true;
        return value;
      });
      await flush();
      expect(shows(first), 1);
      expect(closed, isFalse);
      expect(manager.isNativeAdShowing, isTrue);
      await emit(first, 'Displayed');
      expect(closed, isFalse);
      await finish(first, result);
    });

    test('TopOn$label命令不回result，SDK播放失败回调仍释放状态', () async {
      final gate = hangNextShow(first);
      final result = request(first);
      await flush();
      await emit(first, 'DisplayFailed');
      expect(await result.timeout(const Duration(seconds: 1)), isFalse);
      expect(gate.isCompleted, isFalse);
      expect(manager.isAdBusy, isFalse);
      expect(audio.backgrounds.single.playing, isTrue);
    });
  }

  test('TopOn开屏插屏命令不回result，关闭后首页CloudX激励缓存仍可播放', () async {
    const launch = _Unit('topon', false);
    const reward = _Unit('cloudx', true);
    hangNextShow(launch);
    final launchResult = request(launch, placement: 'nkmdl_launch');
    await flush();
    await emit(launch, 'Displayed');
    await finish(launch, launchResult);
    ready[_Unit('topon', true).id] = false;
    final rewardResult = request(reward, placement: 'nkmdl_moneybub_getpop_rv');
    await flush();
    expect(shows(reward), 1);
    expect(manager.quizAdPlaceID, 'nkmdl_moneybub_getpop_rv');
    await emit(reward, 'Displayed');
    await finish(reward, rewardResult);
  });
}
