import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCPushNotificationDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNotificationPermissionHost.dart';
import 'package:pennypilotcollectspin/PCTool/PCNotificationPermissionSession.dart';

void main() {
  Future<void> frames(WidgetTester tester, [int count = 8]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> clear(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
  }

  Future<void> mount(
    WidgetTester tester, {
    required Future<bool> Function() isEnabled,
    bool Function()? canPresent,
    Future<void> Function()? openSettings,
    Future<void> Function()? refreshSchedules,
    Future<void> Function()? waitForStartupPermission,
    PCNotificationPermissionSession? permissionSession,
    bool isHomeVisible = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PCNotificationPermissionHost(
            isHomeVisible: isHomeVisible,
            canPresent: canPresent ?? () => true,
            isEnabled: isEnabled,
            openSettings: openSettings ?? () async {},
            refreshSchedules: refreshSchedules ?? () async {},
            waitForStartupPermission: waitForStartupPermission,
            permissionSession:
                permissionSession ?? PCNotificationPermissionSession(),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await frames(tester);
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('未授权每次冷启动提醒一次，同次关闭及回前台不重复弹', (tester) async {
    addTearDown(() => clear(tester));
    var checks = 0;
    Future<bool> permission() async {
      checks++;
      return false;
    }

    for (var launch = 0; launch < 2; launch++) {
      await mount(tester, isEnabled: permission);
      expect(find.byType(PCPushNotificationDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pcNotificationRecallClose')));
      await frames(tester, 20);
      expect(find.byType(PCPushNotificationDialog), findsNothing);
      final before = checks;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester, 20);
      expect(checks, greaterThan(before));
      expect(find.byType(PCPushNotificationDialog), findsNothing);
      await clear(tester);
    }
    expect(PCDialogCoordinator.instance.isBusy, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已授权不弹引导，启动及回前台恢复通知计划', (tester) async {
    addTearDown(() => clear(tester));
    var scheduled = 0;
    var enabled = true;
    await mount(
      tester,
      isEnabled: () async => enabled,
      refreshSchedules: () async {
        scheduled++;
      },
    );
    expect(scheduled, 1);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    expect(scheduled, 2);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    enabled = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    expect(scheduled, 3);
    expect(
      find.byType(PCPushNotificationDialog),
      findsNothing,
      reason: '授权撤回后下次冷启动召回，同次回前台不新增提示',
    );
  });

  testWidgets('等待启动系统申请结束，拒绝后才显示一次权限引导', (tester) async {
    addTearDown(() => clear(tester));
    final startup = Completer<void>();
    var checks = 0;
    await mount(
      tester,
      waitForStartupPermission: () => startup.future,
      isEnabled: () async {
        checks++;
        return false;
      },
    );
    expect(checks, 0);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    startup.complete();
    await frames(tester, 16);
    expect(checks, 1);
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
  });

  testWidgets('启动系统申请获准后不再用旧状态弹自定义引导', (tester) async {
    addTearDown(() => clear(tester));
    final startup = Completer<void>();
    var enabled = false, refreshes = 0;
    await mount(
      tester,
      waitForStartupPermission: () => startup.future,
      isEnabled: () async => enabled,
      refreshSchedules: () async {
        refreshes++;
      },
    );
    expect(refreshes, 0);
    enabled = true;
    startup.complete();
    await frames(tester, 16);
    expect(refreshes, 1);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
  });

  testWidgets('未授权在其他Tab不弹，切回首页后显示一次且保留业务门禁', (tester) async {
    addTearDown(() => clear(tester));
    final session = PCNotificationPermissionSession();
    var ready = false;
    Future<bool> permission() async => false;
    await mount(
      tester,
      isEnabled: permission,
      isHomeVisible: false,
      canPresent: () => ready,
      permissionSession: session,
    );
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    expect(session.handled, false);
    await mount(
      tester,
      isEnabled: permission,
      isHomeVisible: true,
      canPresent: () => ready,
      permissionSession: session,
    );
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    expect(session.handled, false);
    ready = true;
    await mount(
      tester,
      isEnabled: permission,
      isHomeVisible: false,
      canPresent: () => ready,
      permissionSession: session,
    );
    await mount(
      tester,
      isEnabled: permission,
      isHomeVisible: true,
      canPresent: () => ready,
      permissionSession: session,
    );
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcNotificationRecallClose')));
    await frames(tester, 20);
    await mount(
      tester,
      isEnabled: permission,
      isHomeVisible: false,
      permissionSession: session,
    );
    await mount(
      tester,
      isEnabled: permission,
      isHomeVisible: true,
      permissionSession: session,
    );
    expect(find.byType(PCPushNotificationDialog), findsNothing);
  });

  testWidgets('启动Future失联有界放行，系统窗口非前台时不叠引导，返回立即复查', (tester) async {
    addTearDown(() => clear(tester));
    final startup = Completer<void>();
    var enabled = false, checks = 0, authorizedRefreshes = 0;
    await mount(
      tester,
      waitForStartupPermission: () => startup.future,
      isEnabled: () async {
        checks++;
        return enabled;
      },
      refreshSchedules: () async {
        if (enabled) authorizedRefreshes++;
      },
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 9));
    await frames(tester, 16);
    expect(checks, 1);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 16);
    expect(checks, 2);
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
    enabled = true;
    startup.complete();
    await frames(tester, 20);
    expect(authorizedRefreshes, 1);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, false);
  });

  testWidgets('通知计划刷新失联不永久阻塞未授权首页召回', (tester) async {
    addTearDown(() => clear(tester));
    final schedule = Completer<void>();
    await mount(
      tester,
      isEnabled: () async => false,
      refreshSchedules: () => schedule.future,
    );
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    await tester.pump(const Duration(seconds: 9));
    await frames(tester, 16);
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
    schedule.complete();
  });

  testWidgets('同次启动重建宿主不重复提示，下一次冷启动重新提示', (tester) async {
    addTearDown(() => clear(tester));
    final session = PCNotificationPermissionSession();
    await mount(
      tester,
      permissionSession: session,
      isEnabled: () async => false,
    );
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcNotificationRecallClose')));
    await frames(tester, 20);
    await clear(tester);
    await mount(
      tester,
      permissionSession: session,
      isEnabled: () async => false,
    );
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    await clear(tester);
    await mount(
      tester,
      permissionSession: PCNotificationPermissionSession(),
      isEnabled: () async => false,
    );
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
  });

  testWidgets('关闭引导后从系统开启权限，回前台仍恢复通知且不重复弹窗', (tester) async {
    addTearDown(() => clear(tester));
    var enabled = false, authorizedRefreshes = 0;
    await mount(
      tester,
      isEnabled: () async => enabled,
      refreshSchedules: () async {
        if (enabled) authorizedRefreshes++;
      },
    );
    await tester.tap(find.byKey(const ValueKey('pcNotificationRecallClose')));
    await frames(tester, 20);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 20);
    expect(authorizedRefreshes, 1);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
  });

  testWidgets('通知引导等待业务流程及已有浮层，设置授权后自动关闭且恢复计划', (tester) async {
    addTearDown(() => clear(tester));
    var ready = false, enabled = false;
    var opened = 0, authorizedSchedules = 0;
    final release = PCDialogCoordinator.instance.holdPresentation();
    addTearDown(release);
    await mount(
      tester,
      canPresent: () => ready,
      isEnabled: () async => enabled,
      openSettings: () async {
        opened++;
      },
      refreshSchedules: () async {
        if (enabled) authorizedSchedules++;
      },
    );
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    ready = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    release();
    await frames(tester);
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcNotificationRecallOpen')));
    await frames(tester);
    expect(opened, 1);
    expect(find.byType(PCPushNotificationDialog), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 20);
    expect(authorizedSchedules, 1);
    expect(find.byType(PCPushNotificationDialog), findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, false);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(375, 812),
    const Size(430, 932),
  ]) {
    testWidgets('通知副标题在$size完整显示且按钮留在安全区', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(() => clear(tester));
      await mount(tester, isEnabled: () async => false);
      final subtitle = find.descendant(
        of: find.byKey(const ValueKey('pcNotificationRecallSubtitle')),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(subtitle);
      expect(
        paragraph.text.toPlainText(),
        'Keep your earnings safe—get notified when it’s time to cash out',
      );
      expect(paragraph.didExceedMaxLines, false);
      final button = tester.getRect(
        find.byKey(const ValueKey('pcNotificationRecallOpen')),
      );
      expect(button.bottom, lessThanOrEqualTo(size.height - 34));
      expect(button.top, greaterThan(tester.getRect(subtitle).bottom));
      expect(tester.takeException(), isNull);
    });
  }
}
