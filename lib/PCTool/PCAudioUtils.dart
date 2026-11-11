import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'PCLogger.dart';
import 'pc_LocalProvider.dart';

/// 本地播放器端口；生产通过audioplayers播放，测试无需调用设备声卡。
abstract interface class PCAudioPlayback {
  bool get playing;
  Future<void> play(String asset, {required bool loop, required double volume});
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

class _PCNativeAudioPlayback implements PCAudioPlayback {
  _PCNativeAudioPlayback({required this.background});
  final bool background;
  final AudioPlayer _player = AudioPlayer();
  Future<void>? _preparing;

  @override
  bool get playing => _player.state == PlayerState.playing;

  Future<void> _prepare() => _preparing ??= () async {
    await _player.setPlayerMode(
      background ? PlayerMode.mediaPlayer : PlayerMode.lowLatency,
    );
    await _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
  }();

  @override
  Future<void> play(
    String asset, {
    required bool loop,
    required double volume,
  }) async {
    await _prepare();
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _player.setVolume(volume);
    await _player.play(AssetSource(asset));
  }

  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

/// 应用音乐与音效共用工具：两个开关独立缓存，关闭立即停播。
/// 启动先读缓存再播放，页面切换不重建BGM，后台及原生广告期间不恢复音乐。
class PCAudioUtils with WidgetsBindingObserver {
  static final PCAudioUtils _instance = PCAudioUtils._internal();
  static PCAudioUtils? _testingInstance;
  factory PCAudioUtils() => _testingInstance ?? _instance;
  PCAudioUtils._internal()
    : _createPlayer = ((background) =>
          _PCNativeAudioPlayback(background: background));

  @visibleForTesting
  PCAudioUtils.testing({
    required PCAudioPlayback Function(bool background) createPlayer,
  }) : _createPlayer = createPlayer;

  @visibleForTesting
  static void overrideForTesting(PCAudioUtils? value) {
    if (!kDebugMode) throw UnsupportedError('Debug audio override only');
    _testingInstance = value;
  }

  static const backgroundAsset = 'File/bgm.mp3';
  static const quizOptionAsset = 'File/quiz_option.mp3';
  static const rewardAsset = 'File/reward_collect.mp3';
  final PCAudioPlayback Function(bool background) _createPlayer;
  final List<PCAudioPlayback> playerQueue = [];
  final Map<PCAudioPlayback, int> _effectOperations = {};
  PCAudioPlayback? _bgmPlayer;
  Future<void>? _settingsLoading, _poolLoading, _startup;
  Future<void> _musicTail = Future<void>.value();
  bool _observing = false, _foreground = true, _bgmStarted = false;
  bool _disposed = false;
  bool Function()? _nativeAdShowing;
  int _effectsEpoch = 0;
  int _effectSequence = 0;
  int _adMusicHolds = 0;

  bool get backgroundMusicEnabled => PCLocalProvider.instance.pc_bg_music;
  bool get soundEffectsEnabled => PCLocalProvider.instance.pc_sound_music;

  /// 原生广告状态由启动页注入，避免工具与广告管理器互相依赖。
  Future<void> initializeForStartup({bool Function()? isNativeAdShowing}) {
    _nativeAdShowing = isNativeAdShowing ?? _nativeAdShowing;
    return _startup ??= () async {
      _disposed = false;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      try {
        await loadSettings();
        await playBGM();
      } catch (error) {
        asLog.error('Audio startup failed: $error');
      }
    }();
  }

  Future<void> loadSettings() => _settingsLoading ??= PCLocalProvider.instance
      .loadAudioSettings()
      .catchError((Object error) {
        _settingsLoading = null;
        throw error;
      });

  Future<void> setBackgroundMusicEnabled(bool value) async {
    await loadSettings();
    await PCLocalProvider.instance.updateAudioSettings(backgroundMusic: value);
    if (value) {
      await playBGM();
    } else {
      await stopBGM();
    }
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    await loadSettings();
    await PCLocalProvider.instance.updateAudioSettings(soundEffects: value);
    if (!value) await stopAllTempAudio();
  }

  bool get _mayPlayMusic =>
      !_disposed &&
      _foreground &&
      backgroundMusicEnabled &&
      _adMusicHolds == 0 &&
      !(_nativeAdShowing?.call() ?? false);

  /// 广告展示前持有恢复禁令，并由调用方await pauseBGM后再调用原生show。
  /// 释放幂等；后台、音乐关闭或还有其它广告持有时不会恢复播放。
  VoidCallback holdBGMForAd() {
    _adMusicHolds++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _adMusicHolds--;
      if (!_disposed) unawaited(playBGM());
    };
  }

  Future<void> _music(
    Future<void> Function() action, {
    bool requireSuccess = false,
  }) {
    final operation = _musicTail.then((_) => action());
    _musicTail = operation.catchError((Object error) {
      asLog.error('Background audio failed: $error');
    });
    return requireSuccess ? operation : _musicTail;
  }

  /// 循环背景音乐；已有播放不重复启动，广告关闭及回前台沿用暂停位置。
  Future<void> playBGM({double volume = .6}) async {
    try {
      await loadSettings();
    } catch (error) {
      asLog.error('Audio settings unavailable: $error');
      return;
    }
    await _music(() async {
      if (!_mayPlayMusic) return;
      final player = _bgmPlayer ??= _createPlayer(true);
      if (player.playing) return;
      if (_bgmStarted) {
        await player.resume();
      } else {
        await player.play(backgroundAsset, loop: true, volume: volume);
        _bgmStarted = true;
      }
      // 设置关闭或切后台可能发生在原生prepare/play期间，迟到播放也立即停止。
      if (!_mayPlayMusic) await player.pause();
    });
  }

  Future<void> pauseBGM({bool requireSuccess = false}) => _music(() async {
    final player = _bgmPlayer;
    if (player != null && _bgmStarted) await player.pause();
  }, requireSuccess: requireSuccess);
  Future<void> resumeBGM() => playBGM();
  Future<void> stopBGM() => _music(() async {
    await _bgmPlayer?.stop();
    _bgmStarted = false;
  });

  Future<void> initTempQueue() => _poolLoading ??= () async {
    for (var i = playerQueue.length; i < 2; i++) {
      playerQueue.add(_createPlayer(false));
    }
  }();

  Future<void> playQuizOptionAudio() => playTempAudio(quizOptionAsset);
  Future<void> playRewardAudio() => playTempAudio(rewardAsset);

  Future<void> playTempAudio(String assetPath, {double volume = 1}) async {
    try {
      await loadSettings();
      if (_disposed || !_foreground || !soundEffectsEnabled) return;
      final epoch = _effectsEpoch;
      await initTempQueue();
      if (_disposed ||
          !_foreground ||
          !soundEffectsEnabled ||
          epoch != _effectsEpoch) {
        return;
      }
      final player = playerQueue.firstWhere(
        (player) => !_effectOperations.containsKey(player) && !player.playing,
        orElse: () => playerQueue.first,
      );
      final sequence = ++_effectSequence;
      _effectOperations[player] = sequence;
      try {
        await player.stop();
        if (_effectOperations[player] != sequence ||
            _disposed ||
            !_foreground ||
            !soundEffectsEnabled ||
            epoch != _effectsEpoch) {
          return;
        }
        await player.play(assetPath, loop: false, volume: volume);
        if (_effectOperations[player] == sequence &&
            (_disposed ||
                !_foreground ||
                !soundEffectsEnabled ||
                epoch != _effectsEpoch)) {
          await player.stop();
        }
      } finally {
        if (_effectOperations[player] == sequence) {
          _effectOperations.remove(player);
        }
      }
    } catch (error) {
      asLog.error('Sound effect failed: $error');
    }
  }

  Future<void> stopAllTempAudio() async {
    _effectsEpoch++;
    for (final player in playerQueue) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  // 保留原有音效调用名，到账类统一复用这次提供的奖励音频。
  Future<void> playCashAudio() => playRewardAudio();
  Future<void> playBigwinAudio() => playRewardAudio();
  Future<void> playRewardStage2Audio() => playRewardAudio();
  Future<void> playDolasAudio() => playRewardAudio();
  Future<void> prepareDolasAudio() => initTempQueue();
  Future<void> prepareScratchAudio() => initTempQueue();
  Future<void> playGuaAudio() => playTempAudio('File/scratch.mp3');
  Future<void> playWheelAudio() => playTempAudio('File/wheel.mp3');
  Future<void> playchouAudio() => playTempAudio('File/box_open.mp3');
  Future<void> playFaildAudio() => playTempAudio('File/scratch_fail.mp3');
  Future<void> playErrorCommonAudio() => playTempAudio('File/error_common.mp3');
  Future<void> playOperationAudio() => playTempAudio('File/operation_3.mp3');
  Future<void> playShaiziAudio() => playTempAudio('File/dice_roll.mp3');
  Future<void> playDiceStepAudio() => playTempAudio('File/dice_step.mp3');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(playBGM());
    } else {
      unawaited(pauseBGM());
      unawaited(stopAllTempAudio());
    }
  }

  Future<void> disposeBgm() => _music(() async {
    await _bgmPlayer?.dispose();
    _bgmPlayer = null;
    _bgmStarted = false;
  });

  Future<void> dispose() async {
    _disposed = true;
    _effectsEpoch++;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    await disposeBgm();
    for (final player in playerQueue) {
      await player.dispose();
    }
    playerQueue.clear();
    _effectOperations.clear();
    _poolLoading = null;
    _settingsLoading = null;
    _startup = null;
  }
}
