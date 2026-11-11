// TopOn原生通道按dart:io平台选择，需在Flutter VM测试环境验证。
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
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_ad_manger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_fake_audio.dart';
import 'support/pc_number_test_assets.dart';

class _AdSpec {
  const _AdSpec(this.source, this.rewarded);
  final String source;
  final bool rewarded;
  String get id => '$source-${rewarded ? 'reward' : 'interstitial'}';
  String get placement => rewarded ? 'audio_test_rv' : 'audio_test_int';
  String get showMethod => source == 'cloudx'
      ? (rewarded ? 'showRewarded' : 'showInterstitial')
      : (rewarded ? 'showRewardedVideo' : 'showInterstitialAd');
}

class _PauseGatePlayer extends PCFakeAudioPlayer {
  Completer<void>? gate;
  bool failPause = false;
  @override
  Future<void> pause() async {
    if (failPause) throw StateError('TEST_PAUSE_FAILED');
    final pending = gate;
    if (pending != null) await pending.future;
    await super.pause();
  }
}

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
  final originalReportEvent = manager.reportEvent;
  final originalReportRevenue = manager.reportRevenue;
  final originalReporter = PCAnalytics.reporter;
  late PCFakeAudio fake;
  late PCAudioUtils audio;
  late _AdSpec spec;
  var ready = true;
  var throwOnShow = false;
  final showStates = <bool>[];
  final methods = <String>[];

  Future<void> flush() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<dynamic> nativeCall(MethodCall call, {required bool cloud}) async {
    methods.add(call.method);
    if (call.method == 'isInitialized') return false;
    if (call.method == 'initialize') return {'success': true};
    if ({
      'isRewardedReady',
      'isInterstitialReady',
      'rewardedVideoReady',
      'hasInterstitialAdReady',
    }.contains(call.method)) {
      return ready;
    }
    if ({
      'showRewarded',
      'showInterstitial',
      'showRewardedVideo',
      'showInterstitialAd',
    }.contains(call.method)) {
      // SDK展示入口本身观察实际播放器，不能依赖之后的Displayed回调才暂停。
      showStates.add(fake.backgrounds.single.playing);
      if (throwOnShow) throw PlatformException(code: 'TEST_SHOW_FAILURE');
    }
    if (call.method.endsWith('ValidAds')) return '[]';
    return cloud ? null : '';
  }

  Future<void> configure(_AdSpec value) async {
    spec = value;
    final ad = PCAdModellist(
      byfxjhld: spec.id,
      dmhytwql: spec.source,
      ugebepat: spec.rewarded ? 'reward' : 'interstitial',
      gqqvwedz: 3000,
      wdzqbsbt: 1,
    );
    await manager.init(
      inputAd: PCAdModel(
        nkmdl_int: spec.rewarded ? [] : [ad],
        nkmdl_rv: spec.rewarded ? [ad] : [],
      ),
      readySources: {spec.source},
    );
    // 实际平台初始化完成也经过setSourceReady，分别绑定两家SDK的监听器。
    manager.setSourceReady(spec.source);
    await flush();
  }

  Future<bool> request() => spec.rewarded
      ? manager.requestRewarded(spec.placement)
      : manager.requestInterstitial(spec.placement);

  Future<void> emit(String kind) async {
    if (kind == 'Hidden' || kind == 'DisplayFailed') ready = false;
    final result = Completer<void>();
    final MethodCall call;
    if (spec.source == 'cloudx') {
      call = MethodCall(
        'On${spec.rewarded ? 'Rewarded' : 'Interstitial'}${kind}Event',
        {
          'adUnitId': spec.id,
          'ad': {
            'adUnitId': spec.id,
            'adFormat': spec.rewarded ? 'rewarded' : 'interstitial',
            'networkName': 'Test Network',
            'revenue': 0.0,
            'placement': spec.placement,
          },
          'error': {'code': 302, 'message': 'Test failure'},
          'reward': {'amount': 1, 'label': 'coin'},
        },
      );
    } else {
      final name = switch (kind) {
        'Displayed' =>
          spec.rewarded
              ? 'rewardedVideoDidStartPlaying'
              : 'interstitialDidShowSucceed',
        'Hidden' =>
          spec.rewarded ? 'rewardedVideoDidClose' : 'interstitialAdDidClose',
        'ReceivedReward' => 'rewardedVideoDidRewardSuccess',
        'DisplayFailed' =>
          spec.rewarded
              ? 'rewardedVideoDidFailToPlay'
              : 'interstitialFailedToShow',
        _ => throw StateError('Unknown test event'),
      };
      call = MethodCall(
        spec.rewarded ? 'RewardedVideoCall' : 'InterstitialCall',
        {
          'placementID': spec.id,
          'callbackName': name,
          'requestMessage': '',
          'extraDic': {'publisher_revenue': 0.0},
        },
      );
    }
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      spec.source == 'cloudx' ? cloudX.name : topOn.name,
      const StandardMethodCodec().encodeMethodCall(call),
      (_) => result.complete(),
    );
    await result.future;
    await flush();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': true,
      'pc_sound_music': false,
    });
    await PCLocalProvider.instance.init();
    manager.stopForTesting();
    manager.skipAdForTesting = false;
    manager.reportEvent = (_, _) {};
    manager.reportRevenue = (_) {};
    PCAnalytics.reporter = (_, _) {};
    ready = true;
    throwOnShow = false;
    methods.clear();
    showStates.clear();
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
    fake = PCFakeAudio();
    audio = fake.audio;
    PCAudioUtils.overrideForTesting(audio);
    await audio.initializeForStartup(
      isNativeAdShowing: () => manager.isNativeAdShowing,
    );
    expect(fake.backgrounds.single.playing, isTrue);
  });

  tearDown(() async {
    manager.stopForTesting();
    await flush();
    await audio.dispose();
    PCAudioUtils.overrideForTesting(null);
    manager.skipAdForTesting = null;
    manager.reportEvent = originalReportEvent;
    manager.reportRevenue = originalReportRevenue;
    await PCAnalytics.flush();
    PCAnalytics.reporter = originalReporter;
    for (final channel in [cloudX, topOn, adjust, facebook]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final source in ['cloudx', 'topon']) {
    for (final rewarded in [false, true]) {
      final value = _AdSpec(source, rewarded);
      test('${value.id}原生show前BGM已暂停，显示回调不重复暂停，关闭后恢复原曲', () async {
        await configure(value);
        manager.compareMode = rewarded;
        final result = request();
        await flush();
        expect(showStates, [false]);
        expect(
          methods.where((method) => method == spec.showMethod),
          hasLength(1),
        );
        expect(fake.backgrounds.single.playing, isFalse);
        final pauses = fake.backgrounds.single.pauses;
        await emit('Displayed');
        await emit('Displayed');
        expect(fake.backgrounds.single.pauses, pauses);
        await audio.playBGM();
        expect(fake.backgrounds.single.playing, isFalse);
        if (rewarded) await emit('ReceivedReward');
        await emit('Hidden');
        expect(await result, isTrue);
        expect(fake.backgrounds.single.playing, isTrue);
        expect(fake.count(PCAudioUtils.backgroundAsset), 1);
        expect(fake.backgrounds.single.resumes, 1);
        await emit('Hidden');
        expect(fake.backgrounds.single.resumes, 1);
      });

      test('${value.id}展示失败释放音频挂起，未进入后台时恢复BGM', () async {
        await configure(value);
        final result = request();
        await flush();
        expect(showStates, [false]);
        await emit('DisplayFailed');
        expect(await result, isFalse);
        expect(fake.backgrounds.single.playing, isTrue);
        expect(fake.backgrounds.single.resumes, 1);
      });
    }

    test('$source后台收到广告关闭不恢复，回前台且开关开启才恢复', () async {
      await configure(_AdSpec(source, false));
      final result = request();
      await flush();
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      await flush();
      await emit('Hidden');
      expect(await result, isTrue);
      expect(fake.backgrounds.single.playing, isFalse);
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(fake.backgrounds.single.playing, isTrue);
      expect(fake.backgrounds.single.resumes, 1);
    });

    test('$source广告期间关闭用户BGM开关，关闭广告及回前台都不恢复', () async {
      await configure(_AdSpec(source, true));
      final result = request();
      await flush();
      await audio.setBackgroundMusicEnabled(false);
      await emit('Hidden');
      expect(await result, isFalse);
      expect(fake.backgrounds.single.playing, isFalse);
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(fake.backgrounds.single.playing, isFalse);
      expect(fake.backgrounds.single.resumes, 0);
    });

    test('$source无缓存或跳过广告不暂停BGM', () async {
      ready = false;
      await configure(_AdSpec(source, false));
      expect(await request(), isFalse);
      expect(fake.backgrounds.single.playing, isTrue);
      expect(fake.backgrounds.single.pauses, 0);
      await flush();
      manager.skipAdForTesting = true;
      expect(await request(), isTrue);
      expect(fake.backgrounds.single.playing, isTrue);
      expect(fake.backgrounds.single.pauses, 0);
      expect(showStates, isEmpty);
    });
  }

  for (final rewarded in [false, true]) {
    test(
      'TopOn ${rewarded ? 'reward' : 'interstitial'}原生show抛错后恢复音乐',
      () async {
        await configure(_AdSpec('topon', rewarded));
        throwOnShow = true;
        expect(await request(), isFalse);
        await flush();
        expect(showStates, [false]);
        expect(fake.backgrounds.single.playing, isTrue);
        expect(manager.isNativeAdShowing, isFalse);
        expect(manager.onAdClosed, isNull);
      },
    );
  }

  Future<_PauseGatePlayer> usePauseGate() async {
    await audio.dispose();
    fake.backgrounds.clear();
    final player = _PauseGatePlayer()..gate = Completer<void>();
    final gate = player.gate!;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    audio = PCAudioUtils.testing(
      createPlayer: (background) {
        if (background) {
          fake.backgrounds.add(player);
          return player;
        }
        final effect = PCFakeAudioPlayer();
        fake.effects.add(effect);
        return effect;
      },
    );
    PCAudioUtils.overrideForTesting(audio);
    await audio.initializeForStartup(
      isNativeAdShowing: () => manager.isNativeAdShowing,
    );
    return player;
  }

  test('BGM暂停尚未完成时不调用SDK，不标记原生展示，完成后才show', () async {
    final player = await usePauseGate();
    await configure(const _AdSpec('cloudx', false));
    final result = request();
    await flush();
    expect(showStates, isEmpty);
    expect(manager.isNativeAdShowing, isFalse);
    expect(manager.adSessionVersion, 0);
    player.gate!.complete();
    player.gate = null;
    await flush();
    expect(showStates, [false]);
    expect(manager.isNativeAdShowing, isTrue);
    await emit('Hidden');
    expect(await result, isTrue);
  });

  test('BGM暂停失联两秒内退让，不调用SDK；晚返回后可重新请求且旧token不拦截', () async {
    final player = await usePauseGate();
    await configure(const _AdSpec('cloudx', false));
    final watch = Stopwatch()..start();
    expect(await request(), isFalse);
    watch.stop();
    await flush();
    expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    expect(showStates, isEmpty);
    expect(manager.isAdBusy, isFalse);
    expect(manager.isNativeAdShowing, isFalse);
    expect(manager.adSessionVersion, 0);
    player.gate!.complete();
    player.gate = null;
    await flush();
    expect(player.playing, isTrue);
    final retry = request();
    await flush();
    expect(showStates, [false]);
    await emit('Hidden');
    expect(await retry, isTrue);
    expect(player.playing, isTrue);
  });

  test('底层暂停抛错不能继续播放广告，恢复正常后仍可再次展示', () async {
    final player = await usePauseGate();
    player.gate!.complete();
    player.gate = null;
    player.failPause = true;
    await configure(const _AdSpec('cloudx', false));
    expect(await request(), isFalse);
    await flush();
    expect(showStates, isEmpty);
    expect(manager.isNativeAdShowing, isFalse);
    expect(manager.isAdBusy, isFalse);
    expect(player.playing, isTrue);
    player.failPause = false;
    final retry = request();
    await flush();
    expect(showStates, [false]);
    await emit('Hidden');
    expect(await retry, isTrue);
    expect(player.playing, isTrue);
  });
}
