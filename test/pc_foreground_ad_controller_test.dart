import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCForegroundAdController.dart';

void main() {
  late PCForegroundAdController controller;
  late DateTime now;
  late bool busy;
  late int session;
  late DateTime? finishedAt;
  late bool canPresent;
  late int holds;
  late int releases;
  late List<String> requests;
  Completer<bool>? pending;
  late bool throwRequest;

  Future<bool> lifecycle(AppLifecycleState state) =>
      controller.didChangeAppLifecycleState(state);
  Future<bool> visit() async {
    await lifecycle(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 10));
    return lifecycle(AppLifecycleState.resumed);
  }

  setUp(() {
    now = DateTime(2026, 10, 27, 12);
    busy = false;
    session = 0;
    finishedAt = null;
    canPresent = true;
    holds = 0;
    releases = 0;
    requests = [];
    pending = null;
    throwRequest = false;
    controller = PCForegroundAdController(
      adShowing: () => busy,
      adSessionVersion: () => session,
      lastAdFinishedAt: () => finishedAt,
      canPresent: () => canPresent,
      now: () => now,
      holdPresentation: () {
        holds++;
        return () => releases++;
      },
      requestInterstitial: (placement) async {
        requests.add(placement);
        if (throwRequest) throw StateError('SDK unavailable');
        return pending == null ? true : pending!.future;
      },
    );
  });

  tearDown(() => controller.dispose());

  test('冷启动、重复resumed、权限窗口inactive和仅hidden不播放', () async {
    await lifecycle(AppLifecycleState.resumed);
    await lifecycle(AppLifecycleState.resumed);
    await lifecycle(AppLifecycleState.inactive);
    await lifecycle(AppLifecycleState.resumed);
    await lifecycle(AppLifecycleState.hidden);
    await lifecycle(AppLifecycleState.resumed);
    expect(requests, isEmpty);
    expect(holds, 0);
  });

  test('真实后台返回直接请求一次nkmdl_launch，并完整释放展示权', () async {
    expect(await visit(), isTrue);
    await lifecycle(AppLifecycleState.resumed);
    expect(requests, [PCForegroundAdController.placement]);
    expect(PCForegroundAdController.placement, 'nkmdl_launch');
    expect(holds, 1);
    expect(releases, 1);
    expect(await visit(), isTrue);
    expect(requests, hasLength(2));
  });

  test('原生广告进入后台后关闭，返回前台不紧接着播插屏', () async {
    busy = true;
    await lifecycle(AppLifecycleState.paused);
    busy = false;
    finishedAt = now;
    now = now.add(const Duration(seconds: 3));
    await lifecycle(AppLifecycleState.paused); // 重复不能改掉当时busy记录。
    expect(await lifecycle(AppLifecycleState.resumed), isFalse);
    expect(requests, isEmpty);
    expect(await visit(), isTrue);
  });

  test('后台期间开始并结束广告，即使resume时空闲也不补播', () async {
    await lifecycle(AppLifecycleState.paused);
    session++;
    now = now.add(const Duration(seconds: 30));
    expect(await lifecycle(AppLifecycleState.resumed), isFalse);
    expect(requests, isEmpty);
  });

  test('先到原生关闭回调再到paused仍屏蔽该次生命周期往返', () async {
    finishedAt = now;
    now = now.add(const Duration(milliseconds: 100));
    expect(await visit(), isFalse);
    expect(requests, isEmpty);
    expect(await visit(), isTrue);
  });

  test('后台中的关闭时间标记屏蔽resume，不依赖session序号或冷却时长', () async {
    await lifecycle(AppLifecycleState.paused);
    finishedAt = now.add(const Duration(seconds: 2));
    now = now.add(const Duration(minutes: 1));
    expect(await lifecycle(AppLifecycleState.resumed), isFalse);
    expect(requests, isEmpty);
  });

  test('返回时已有原生广告播放就丢弃，空闲后不定时补播', () async {
    await lifecycle(AppLifecycleState.paused);
    busy = true;
    expect(await lifecycle(AppLifecycleState.resumed), isFalse);
    busy = false;
    await lifecycle(AppLifecycleState.resumed);
    expect(requests, isEmpty);
    expect(await visit(), isTrue);
  });

  test('引导、业务弹窗或冷启launch占用时跳过，释放不补播', () async {
    canPresent = false;
    expect(await visit(), isFalse);
    canPresent = true;
    await lifecycle(AppLifecycleState.resumed);
    expect(requests, isEmpty);
    expect(await visit(), isTrue);
  });

  test('插屏异步未结束不重复请求，被丢弃的回流结束后也不补播', () async {
    pending = Completer<bool>();
    final result = visit();
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(1));
    expect(holds, 1);
    expect(releases, 0);
    expect(await visit(), isFalse);
    pending!.complete(true);
    expect(await result, isTrue);
    expect(releases, 1);
    await lifecycle(AppLifecycleState.resumed);
    expect(requests, hasLength(1));
  });

  test('无缓存也直接调用展示，失败不排队，下次真实回前台可再请求', () async {
    pending = Completer<bool>()..complete(false);
    expect(await visit(), isFalse);
    pending = null;
    await lifecycle(AppLifecycleState.resumed);
    expect(requests, hasLength(1));
    expect(await visit(), isTrue);
    expect(requests, hasLength(2));
    expect(holds, releases);
  });

  test('SDK异常释放展示权，dispose与detached取消旧回流', () async {
    throwRequest = true;
    expect(await visit(), isFalse);
    expect(holds, releases);
    throwRequest = false;
    expect(await visit(), isTrue);
    await lifecycle(AppLifecycleState.paused);
    await lifecycle(AppLifecycleState.detached);
    await lifecycle(AppLifecycleState.resumed);
    controller.dispose();
    expect(await visit(), isFalse);
    expect(requests, hasLength(2));
  });
}
