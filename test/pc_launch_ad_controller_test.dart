import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCLaunchAdController.dart';

void main() {
  late bool guideComplete;
  late bool visible;
  late bool failLoad;
  late bool failAd;
  late bool adResult;
  late int reads;
  late int navigations;
  late int holds;
  late int releases;
  late List<String> requests;
  Completer<bool>? progress;
  Completer<bool>? ad;
  late PCLaunchAdController controller;

  setUp(() {
    guideComplete = false;
    visible = true;
    failLoad = false;
    failAd = false;
    adResult = true;
    reads = 0;
    navigations = 0;
    holds = 0;
    releases = 0;
    requests = [];
    progress = null;
    ad = null;
    controller = PCLaunchAdController(
      loadGuideComplete: () async {
        reads++;
        if (failLoad) throw StateError('local state unavailable');
        return progress?.future ?? guideComplete;
      },
      requestInterstitial: (placement) async {
        requests.add(placement);
        if (failAd) throw StateError('SDK unavailable');
        return ad?.future ?? adResult;
      },
      continueToApp: () async => navigations++,
      canContinue: () => visible,
      holdPresentation: () {
        holds++;
        return () => releases++;
      },
    );
  });

  tearDown(() => controller.dispose());

  PCLaunchAdController create({
    required Future<bool> Function() load,
    Future<bool> Function(String)? request,
    Future<void> Function()? waitForStartupPermission,
  }) {
    controller.dispose();
    return controller = PCLaunchAdController(
      loadGuideComplete: load,
      requestInterstitial:
          request ??
          (placement) async {
            requests.add(placement);
            return ad?.future ?? adResult;
          },
      continueToApp: () async => navigations++,
      canContinue: () => visible,
      waitForStartupPermission: waitForStartupPermission,
      holdPresentation: () {
        holds++;
        return () => releases++;
      },
    );
  }

  test('启动时读取引导，加载动画完成前不播广告也不进入首页', () async {
    expect(reads, 1);
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);
    expect(navigations, 0);
    await controller.finish();
    expect(navigations, 1);
    expect(holds, 0);
  });

  test('未完成引导不播，本次后来完成或重复回调也不补播', () async {
    // 构造时已捕获false，随后真实用户走完引导也不属于下一次冷启动。
    guideComplete = true;
    await Future.wait([controller.finish(), controller.finish()]);
    await controller.finish();
    expect(reads, 1);
    expect(requests, isEmpty);
    expect(navigations, 1);
  });

  test('系统通知权限未决时不播开屏也不导航，重复完成仅等待和请求一次', () async {
    final permission = Completer<void>();
    var waits = 0;
    create(
      load: () async => true,
      waitForStartupPermission: () {
        waits++;
        return permission.future;
      },
    );
    final first = controller.finish();
    final duplicate = controller.finish();
    expect(identical(first, duplicate), true);
    await Future<void>.delayed(Duration.zero);
    expect(waits, 1);
    expect(requests, isEmpty);
    expect(navigations, 0);
    expect(holds, 0);
    permission.complete();
    await first;
    await duplicate;
    expect(requests, ['nkmdl_launch']);
    expect(navigations, 1);
    expect(holds, 1);
    expect(releases, 1);
  });

  test('新用户不播启动广告，也要等系统通知权限结束才进入引导', () async {
    final permission = Completer<void>();
    create(
      load: () async => false,
      waitForStartupPermission: () => permission.future,
    );
    final finishing = controller.finish();
    await Future<void>.delayed(Duration.zero);
    expect(navigations, 0);
    permission.complete();
    await finishing;
    expect(requests, isEmpty);
    expect(navigations, 1);
  });

  test('等待系统权限时页面销毁，迟到的权限结果不能播放广告或跳页', () async {
    final permission = Completer<void>();
    create(
      load: () async => true,
      waitForStartupPermission: () => permission.future,
    );
    final finishing = controller.finish();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    permission.complete();
    await finishing;
    expect(requests, isEmpty);
    expect(navigations, 0);
    expect(holds, 0);
  });

  test('系统通知权限申请异常静默继续原有开屏与导航逻辑', () async {
    create(
      load: () async => true,
      waitForStartupPermission: () async =>
          throw StateError('permission unavailable'),
    );
    await controller.finish();
    expect(requests, ['nkmdl_launch']);
    expect(navigations, 1);
    expect(holds, releases);
  });

  test('完整老用户仅请求nkmdl_launch，真实关闭前不进入首页或释放展示权', () async {
    ad = Completer<bool>();
    create(load: () async => true);
    final result = controller.finish();
    await Future<void>.delayed(Duration.zero);
    expect(requests, ['nkmdl_launch']);
    expect(navigations, 0);
    expect(holds, 1);
    expect(releases, 0);
    // 广告Activity发生生命周期切换期间重复完成也不能启动第二支广告。
    final duplicate = controller.finish();
    ad!.complete(true);
    await Future.wait([result, duplicate]);
    expect(requests, hasLength(1));
    expect(releases, 1);
    expect(navigations, 1);
  });

  test('没有缓存或播放失败也已调用nkmdl_launch，静默进首页且重建不重试', () async {
    adResult = false;
    create(load: () async => true);
    await controller.finish();
    await controller.finish();
    expect(requests, ['nkmdl_launch']);
    expect(navigations, 1);
    expect(holds, releases);
  });

  test('SDK异常同样继续首页并释放展示权', () async {
    create(
      load: () async => true,
      request: (placement) async {
        requests.add(placement);
        throw StateError('SDK failed');
      },
    );
    await controller.finish();
    expect(requests, ['nkmdl_launch']);
    expect(navigations, 1);
    expect(holds, 1);
    expect(releases, 1);
  });

  test('引导缓存读取失败不能以已安装为由给新用户播广告', () async {
    create(load: () async => throw StateError('read failed'));
    await controller.finish();
    expect(requests, isEmpty);
    expect(navigations, 1);
    expect(holds, 0);
  });

  test('加载动画先结束时等待真实引导状态，不能提前进入首页', () async {
    progress = Completer<bool>();
    create(load: () => progress!.future);
    final result = controller.finish();
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);
    expect(navigations, 0);
    progress!.complete(true);
    await result;
    expect(requests, ['nkmdl_launch']);
    expect(navigations, 1);
  });

  test('启动页销毁或不再可见后，迟到的读取不能播放或导航', () async {
    progress = Completer<bool>();
    create(load: () => progress!.future);
    final result = controller.finish();
    controller.dispose();
    progress!.complete(true);
    await result;
    expect(requests, isEmpty);
    expect(navigations, 0);
    expect(holds, 0);
  });

  test('广告期间启动页销毁仍释放展示权，关闭回调不能再跳首页', () async {
    ad = Completer<bool>();
    create(load: () async => true);
    final result = controller.finish();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    ad!.complete(false);
    await result;
    expect(requests, hasLength(1));
    expect(holds, releases);
    expect(navigations, 0);
  });

  test('启动不再拥有路由时直接丢弃，恢复可见也不补播', () async {
    create(load: () async => true);
    visible = false;
    await controller.finish();
    visible = true;
    await controller.finish();
    expect(requests, isEmpty);
    expect(navigations, 0);
  });
}
