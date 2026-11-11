import 'dart:async';

import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';

class PCFakeAudioPlayer implements PCAudioPlayback {
  final plays = <({String asset, bool loop, double volume})>[];
  int pauses = 0, stops = 0, resumes = 0, disposals = 0;
  Completer<void>? playGate;
  @override
  bool playing = false;

  @override
  Future<void> play(
    String asset, {
    required bool loop,
    required double volume,
  }) async {
    plays.add((asset: asset, loop: loop, volume: volume));
    if (playGate != null) await playGate!.future;
    playing = true;
  }

  @override
  Future<void> resume() async {
    resumes++;
    playing = true;
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
  }

  @override
  Future<void> stop() async {
    stops++;
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    playing = false;
  }
}

class PCFakeAudio {
  PCFakeAudio() {
    audio = PCAudioUtils.testing(
      createPlayer: (background) {
        final player = PCFakeAudioPlayer();
        (background ? backgrounds : effects).add(player);
        return player;
      },
    );
  }
  late final PCAudioUtils audio;
  final backgrounds = <PCFakeAudioPlayer>[];
  final effects = <PCFakeAudioPlayer>[];
  int count(String asset) => [...backgrounds, ...effects]
      .expand((player) => player.plays)
      .where((play) => play.asset == asset)
      .length;
}
