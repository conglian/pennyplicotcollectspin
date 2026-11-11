import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCLaunchAdController.dart';

void main() {
  late int navigations, holds, releases;
  late bool nativeShowing;
  late List<String> requests, timeouts;
  late PCLaunchAdController controller;

  PCLaunchAdController create({
    Future<bool> Function()? load,
    Future<bool> Function(String)? request,
    Future<void> Function()? permission,
    Future<void> Function()? metadata,
    bool Function()? canRequest,
  }) {
    controller = PCLaunchAdController(
      loadGuideComplete: load ?? () async => true,
      requestInterstitial: (placement) {
        requests.add(placement);
        return request?.call(placement) ?? Future<bool>.value(false);
      },
      waitForStartupPermission: permission,
      prepareApp: metadata,
      continueToApp: () async => navigations++,
      canContinue: () => true,
      isNativeAdShowing: () => nativeShowing,
      canRequestInterstitial: canRequest,
      onWaitTimeout: timeouts.add,
      holdPresentation: () {
        holds++;
        return () => releases++;
      },
    );
    return controller;
  }

  setUp(() {
    navigations = holds = releases = 0;
    nativeShowing = false;
    requests = [];
    timeouts = [];
  });
  tearDown(() => controller.dispose());

  testWidgets('引导读取永不返回时保护新用户并离开启动页，迟到读取不补播', (tester) async {
    final guide = Completer<bool>();
    create(load: () => guide.future);
    final finishing = controller.finish();
    await tester.pump();
    expect(navigations, 0);
    await tester.pump(const Duration(seconds: 8));
    await finishing;
    expect(navigations, 1);
    expect(requests, isEmpty);
    expect(timeouts, ['guide_state']);
    guide.complete(true);
    await tester.pump();
    await controller.finish();
    expect(navigations, 1);
    expect(requests, isEmpty);
  });

  testWidgets('系统权限永不返回时8秒跳过此次广告继续，晚授权不二次启动', (tester) async {
    final permission = Completer<void>();
    create(permission: () => permission.future);
    final finishing = controller.finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await finishing;
    expect(navigations, 1);
    expect(requests, isEmpty);
    expect(holds, 0);
    expect(timeouts, ['notification_permission']);
    permission.complete();
    await tester.pump();
    expect(navigations, 1);
    expect(requests, isEmpty);
  });

  testWidgets('权限等待外部降级返回但窗口仍占用时不能播开屏，恢复前台也不补播', (tester) async {
    var ready = false;
    create(canRequest: () => ready);
    await controller.finish();
    expect(navigations, 1);
    expect(requests, isEmpty);
    expect(holds, 0);
    ready = true;
    await controller.finish();
    expect(navigations, 1);
    expect(requests, isEmpty);
  });

  testWidgets('SDK未展示且业务回调丢失时8秒静默导航，仅尝试一次nkmdl_launch', (tester) async {
    final ad = Completer<bool>();
    create(request: (_) => ad.future);
    final finishing = controller.finish();
    await tester.pump();
    expect(requests, ['nkmdl_launch']);
    expect(holds, 1);
    expect(releases, 0);
    await tester.pump(const Duration(seconds: 7));
    expect(navigations, 0);
    await tester.pump(const Duration(seconds: 1));
    await finishing;
    expect(timeouts, ['interstitial_callback']);
    expect(navigations, 1);
    expect(releases, 1);
    ad.complete(true);
    await tester.pump();
    await controller.finish();
    expect(requests, hasLength(1));
    expect(navigations, 1);
    expect(releases, 1);
  });

  testWidgets('真实原生广告仍展示时8秒不能抢跑，正常关闭才进入首页', (tester) async {
    final ad = Completer<bool>();
    nativeShowing = true;
    create(request: (_) => ad.future);
    final finishing = controller.finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 20));
    expect(navigations, 0);
    expect(releases, 0);
    nativeShowing = false;
    ad.complete(true);
    await tester.pump();
    await finishing;
    expect(navigations, 1);
    expect(releases, 1);
    expect(timeouts, isEmpty);
  });

  testWidgets('原生已结束但漏掉业务Future时从展示标志恢复，不必等120秒', (tester) async {
    final ad = Completer<bool>();
    nativeShowing = true;
    create(request: (_) => ad.future);
    final finishing = controller.finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    nativeShowing = false;
    await tester.pump(const Duration(milliseconds: 250));
    await finishing;
    expect(navigations, 1);
    expect(releases, 1);
    ad.completeError(StateError('late native callback'));
    await tester.pump();
    expect(navigations, 1);
  });

  testWidgets('原生状态永远true时120秒只更换Flutter底页，不抢占原生owner', (tester) async {
    final ad = Completer<bool>();
    nativeShowing = true;
    create(request: (_) => ad.future);
    final finishing = controller.finish();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 111));
    expect(navigations, 0);
    expect(releases, 0);
    await tester.pump(const Duration(seconds: 1));
    await finishing;
    expect(navigations, 1);
    expect(releases, 1);
    expect(nativeShowing, isTrue);
    expect(requests, ['nkmdl_launch']);
    expect(timeouts, ['native_interstitial_callback']);
    ad.complete(true);
    await tester.pump();
    expect(navigations, 1);
  });

  testWidgets('日期和回访信息写入永不返回也不能卡住100%，晚完成不再导航', (tester) async {
    final metadata = Completer<void>();
    create(metadata: () => metadata.future);
    final finishing = controller.finish();
    await tester.pump();
    expect(navigations, 0);
    await tester.pump(const Duration(seconds: 2));
    await finishing;
    expect(timeouts, ['launch_metadata']);
    expect(navigations, 1);
    metadata.completeError(StateError('late disk error'));
    await tester.pump();
    expect(navigations, 1);
  });

  testWidgets('销毁时取消所有启动等待和定时器，迟到广告不跳页', (tester) async {
    final ad = Completer<bool>();
    nativeShowing = true;
    create(request: (_) => ad.future);
    final finishing = controller.finish();
    await tester.pump();
    controller.dispose();
    await tester.pump();
    await finishing;
    expect(navigations, 0);
    expect(releases, 1);
    ad.complete(true);
    await tester.pump(const Duration(seconds: 120));
    expect(timeouts, isEmpty);
    expect(navigations, 0);
  });
}
