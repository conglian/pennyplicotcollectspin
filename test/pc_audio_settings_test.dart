import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PCFakeAudio fake;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = PCFakeAudio();
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  tearDown(() async => fake.audio.dispose());

  test('默认均开启，启动循环正确英文资源，重复启动不叠加BGM', () async {
    await fake.audio.initializeForStartup();
    await fake.audio.initializeForStartup();
    await fake.audio.playBGM();
    expect(fake.audio.backgroundMusicEnabled, isTrue);
    expect(fake.audio.soundEffectsEnabled, isTrue);
    expect(fake.count(PCAudioUtils.backgroundAsset), 1);
    expect(fake.backgrounds.single.plays.single.loop, isTrue);
  });

  test('冷启动先读取关闭缓存，不会短暂播放BGM或音效', () async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_sound_music': false,
    });
    PCLocalProvider.instance.pc_bg_music = true;
    PCLocalProvider.instance.pc_sound_music = true;
    await fake.audio.initializeForStartup();
    await fake.audio.playQuizOptionAudio();
    await fake.audio.playRewardAudio();
    expect(fake.backgrounds, isEmpty);
    expect(fake.effects, isEmpty);
  });

  test('BGM关闭立即停播并持久化，不影响音效；重开立即播放', () async {
    await fake.audio.initializeForStartup();
    final music = fake.backgrounds.single;
    await fake.audio.setBackgroundMusicEnabled(false);
    expect(music.playing, isFalse);
    expect(music.stops, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool('pc_bg_music'),
      isFalse,
    );
    await fake.audio.playRewardAudio();
    expect(fake.count(PCAudioUtils.rewardAsset), 1);
    await fake.audio.setBackgroundMusicEnabled(true);
    expect(music.playing, isTrue);
    expect(fake.count(PCAudioUtils.backgroundAsset), 2);
  });

  test('音效关闭立即停止全部短音，后续对错及奖励均静音，BGM独立继续', () async {
    await fake.audio.initializeForStartup();
    await fake.audio.playQuizOptionAudio();
    await fake.audio.playRewardAudio();
    await fake.audio.setSoundEffectsEnabled(false);
    expect(fake.effects.every((player) => !player.playing), isTrue);
    expect(fake.backgrounds.single.playing, isTrue);
    final before =
        fake.count(PCAudioUtils.quizOptionAsset) +
        fake.count(PCAudioUtils.rewardAsset);
    await fake.audio.playQuizOptionAudio();
    await fake.audio.playRewardAudio();
    expect(
      fake.count(PCAudioUtils.quizOptionAsset) +
          fake.count(PCAudioUtils.rewardAsset),
      before,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool('pc_sound_music'),
      isFalse,
    );
    await fake.audio.setSoundEffectsEnabled(true);
    await fake.audio.playRewardAudio();
    expect(fake.count(PCAudioUtils.rewardAsset), 2);
  });

  test('后台暂停，前台按用户开关恢复；原生广告期间不恢复抢音轨', () async {
    var adShowing = false;
    await fake.audio.initializeForStartup(isNativeAdShowing: () => adShowing);
    final music = fake.backgrounds.single;
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.paused);
    await fake.audio.pauseBGM();
    expect(music.playing, isFalse);
    adShowing = true;
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fake.audio.playBGM();
    expect(music.playing, isFalse);
    adShowing = false;
    await fake.audio.playBGM();
    expect(music.playing, isTrue);
    expect(fake.count(PCAudioUtils.backgroundAsset), 1);
    expect(music.resumes, 1);
    await fake.audio.setBackgroundMusicEnabled(false);
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.paused);
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fake.audio.playBGM();
    expect(music.playing, isFalse);
  });

  test('关闭音效后迟到的原生播放也会停止，不会复活', () async {
    await fake.audio.loadSettings();
    await fake.audio.initTempQueue();
    final gate = Completer<void>();
    fake.effects.first.playGate = gate;
    final pending = fake.audio.playQuizOptionAudio();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(fake.count(PCAudioUtils.quizOptionAsset), 1);
    await fake.audio.setSoundEffectsEnabled(false);
    gate.complete();
    await pending;
    expect(fake.effects.first.playing, isFalse);
  });

  test('广告持有期间原生状态暂时清空或回前台也不恢复，释放幂等', () async {
    await fake.audio.initializeForStartup();
    final player = fake.backgrounds.single;
    final releaseFirst = fake.audio.holdBGMForAd();
    await fake.audio.pauseBGM(requireSuccess: true);
    final releaseSecond = fake.audio.holdBGMForAd();
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fake.audio.playBGM();
    expect(player.playing, isFalse);
    releaseFirst();
    releaseFirst();
    await fake.audio.playBGM();
    expect(player.playing, isFalse);
    releaseSecond();
    await fake.audio.playBGM();
    expect(player.playing, isTrue);
    expect(player.resumes, 1);
    expect(fake.count(PCAudioUtils.backgroundAsset), 1);
  });

  test('后台收到广告关闭保持暂停，只有回前台才恢复', () async {
    await fake.audio.initializeForStartup();
    final player = fake.backgrounds.single;
    final release = fake.audio.holdBGMForAd();
    await fake.audio.pauseBGM(requireSuccess: true);
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await fake.audio.pauseBGM();
    release();
    await fake.audio.playBGM();
    expect(player.playing, isFalse);
    expect(player.resumes, 0);
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fake.audio.playBGM();
    expect(player.playing, isTrue);
    expect(player.resumes, 1);
  });

  test('广告期间关闭音乐，广告结束及重复前台事件都不恢复', () async {
    await fake.audio.initializeForStartup();
    final player = fake.backgrounds.single;
    final release = fake.audio.holdBGMForAd();
    await fake.audio.pauseBGM(requireSuccess: true);
    await fake.audio.setBackgroundMusicEnabled(false);
    release();
    release();
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fake.audio.playBGM();
    expect(player.playing, isFalse);
    expect(player.resumes, 0);
    expect(
      (await SharedPreferences.getInstance()).getBool('pc_bg_music'),
      isFalse,
    );
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.paused);
    await fake.audio.setBackgroundMusicEnabled(true);
    expect(player.playing, isFalse);
    fake.audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await fake.audio.playBGM();
    expect(player.playing, isTrue);
  });

  test('BGM原生启动迟到时广告禁令仍会暂停，不因前台回调重新响起', () async {
    final gate = Completer<void>();
    final player = PCFakeAudioPlayer()..playGate = gate;
    final audio = PCAudioUtils.testing(createPlayer: (_) => player);
    try {
      final started = audio.initializeForStartup();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(player.plays, hasLength(1));
      final release = audio.holdBGMForAd();
      final paused = audio.pauseBGM(requireSuccess: true);
      gate.complete();
      await started;
      await paused;
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await audio.playBGM();
      expect(player.playing, isFalse);
      release();
      await audio.playBGM();
      expect(player.playing, isTrue);
    } finally {
      await audio.dispose();
    }
  });

  test('广告要求暂停成功时保留原生异常，普通后台暂停仍安全容错', () async {
    final player = _FailingPausePlayer();
    final audio = PCAudioUtils.testing(createPlayer: (_) => player);
    try {
      await audio.initializeForStartup();
      await expectLater(audio.pauseBGM(requireSuccess: true), throwsStateError);
      expect(player.playing, isTrue);
      await expectLater(audio.pauseBGM(), completes);
    } finally {
      await audio.dispose();
    }
  });
}

class _FailingPausePlayer extends PCFakeAudioPlayer {
  @override
  Future<void> pause() async => throw StateError('pause failed');
}
