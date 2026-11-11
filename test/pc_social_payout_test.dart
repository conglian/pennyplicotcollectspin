import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCInAppNotificationHost.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeMessage.dart';
import 'package:pennypilotcollectspin/PCTool/PCNotificationCard.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessFlowController.dart';
import 'package:pennypilotcollectspin/PCTool/PCSocialPayoutCard.dart';
import 'package:pennypilotcollectspin/PCTool/PCSocialPayoutController.dart';
import 'package:pennypilotcollectspin/PCTool/PCSocialPayoutNotice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PCSocialPayoutController create(
    WidgetTester tester,
    SharedPreferences prefs,
  ) => PCSocialPayoutController(
    preferences: prefs,
    random: Random(17),
    now: () => tester.binding.clock.now(),
    withdrawalAmounts: () => [75, 135],
  );

  testWidgets('新用户按2至5分钟计划、未完成引导不显示，首次时间冷启动保留', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final first = create(tester, prefs);
    first.setEnvironment(foreground: true, guideComplete: false, progress: 0);
    await first.load();
    final firstTime = first.firstActive;
    expect(first.nextDue, isNull);
    first.setEnvironment(foreground: true, guideComplete: true, progress: 0);
    final remaining = first.nextDue!.difference(tester.binding.clock.now());
    expect(remaining, greaterThanOrEqualTo(const Duration(minutes: 2)));
    expect(remaining, lessThanOrEqualTo(const Duration(minutes: 5)));
    await tester.pump(remaining);
    expect(first.pending!.name, 'Mary');
    expect([75.0, 135.0], contains(first.pending!.amount));
    expect(first.earlyCount, 0);
    final shown = first.beginPresentation()!;
    expect(
      RegExp(r'^pc_rank_avatar_(0[1-9]|1[0-9]|20)$').hasMatch(shown.avatarName),
      isTrue,
    );
    expect(first.earlyCount, 1);
    first.finishPresentation();
    final due = first.nextDue;
    first.dispose();
    final restored = create(tester, prefs);
    await restored.load();
    restored.setEnvironment(foreground: true, guideComplete: true, progress: 0);
    expect(
      restored.firstActive!.millisecondsSinceEpoch,
      firstTime!.millisecondsSinceEpoch,
    );
    expect(restored.cursor, 1);
    expect(restored.earlyCount, 1);
    expect(
      restored.nextDue!.millisecondsSinceEpoch,
      due!.millisecondsSinceEpoch,
    );
    restored.dispose();
  });

  testWidgets('前10分钟最多10条，窗口结束且进度不足时停止', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PCSocialPayoutController.earlyCountKey, 9);
    final controller = create(tester, prefs);
    controller.setEnvironment(
      foreground: true,
      guideComplete: true,
      progress: .5,
    );
    await controller.load();
    await tester.pump(
      controller.nextDue!.difference(tester.binding.clock.now()),
    );
    expect(controller.beginPresentation(), isNotNull);
    controller.finishPresentation();
    expect(controller.earlyCount, 10);
    expect(controller.nextDue, isNull);
    await tester.pump(const Duration(minutes: 20));
    expect(controller.pending, isNull);
    controller.setEnvironment(
      foreground: true,
      guideComplete: true,
      progress: .51,
    );
    final delay = controller.nextDue!.difference(tester.binding.clock.now());
    expect(delay, greaterThanOrEqualTo(const Duration(minutes: 5)));
    expect(delay, lessThanOrEqualTo(const Duration(minutes: 10)));
    controller.dispose();
  });

  testWidgets('后台暂停，超过10分钟回前台不补弹，20组文案循环并取配置档位', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = create(tester, prefs);
    controller.setEnvironment(
      foreground: true,
      guideComplete: true,
      progress: .75,
    );
    await controller.load();
    await tester.pump(const Duration(seconds: 60));
    controller.setEnvironment(
      foreground: false,
      guideComplete: true,
      progress: .75,
    );
    await tester.pump(const Duration(minutes: 12));
    expect(controller.pending, isNull);
    controller.setEnvironment(
      foreground: true,
      guideComplete: true,
      progress: .75,
    );
    expect(
      controller.nextDue!.difference(tester.binding.clock.now()),
      greaterThanOrEqualTo(const Duration(minutes: 5)),
    );
    final titles = <String>[];
    for (var index = 0; index < 21; index++) {
      await tester.pump(
        controller.nextDue!.difference(tester.binding.clock.now()),
      );
      final notice = controller.beginPresentation()!;
      titles.add(notice.name);
      expect([75.0, 135.0], contains(notice.amount));
      expect(notice.body, contains(notice.amountText));
      controller.finishPresentation();
    }
    expect(titles.take(20).toSet().length, 20);
    expect(titles.first, 'Mary');
    expect(titles.last, 'Mary');
    controller.dispose();
  });

  testWidgets('等待业务弹窗期间不计展示，过期的早期播报不显示', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = create(tester, prefs);
    controller.setEnvironment(
      foreground: true,
      guideComplete: true,
      progress: 0,
    );
    await controller.load();
    await tester.pump(
      controller.nextDue!.difference(tester.binding.clock.now()),
    );
    expect(controller.pending, isNotNull);
    await tester.pump(const Duration(minutes: 11));
    expect(controller.beginPresentation(), isNull);
    expect(controller.earlyCount, 0);
    expect(controller.nextDue, isNull);
    controller.dispose();
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('社交播报$width宽按设计分层并点击提现', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      const notice = PCSocialPayoutNotice(
        sequence: 0,
        name: 'Mary',
        title: '🎉 PayPal Payout Success',
        bodyTemplate: 'received {amount} via PayPal successfully 💰',
        amount: 135,
        avatarName: 'pc_rank_avatar_01',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PCSocialPayoutCard(notice: notice, onAction: () => taps++),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(RichText), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('pcSocialNoticeAction')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(taps, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('通知独占展示；业务弹窗等退场后进入，旧余额提醒优先且不重叠', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final social = create(tester, prefs);
    final coordinator = PCDialogCoordinator();
    final notice = ValueNotifier<PCNoticeMessage?>(null);
    addTearDown(social.dispose);
    addTearDown(coordinator.dispose);
    addTearDown(notice.dispose);
    final releaseBusiness = coordinator.holdPresentation();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => PCInAppNotificationHost(
          notifier: notice,
          socialController: social,
          coordinator: coordinator,
          socialReady: () => true,
          socialProgress: () => .75,
          child: child!,
        ),
        home: const Scaffold(body: Text('Body')),
      ),
    );
    await tester.pump();
    await social.load();
    await tester.pump(social.nextDue!.difference(tester.binding.clock.now()));
    await tester.pump(const Duration(seconds: 1));
    expect(social.pending, isNotNull);
    expect(find.byType(PCSocialPayoutCard), findsNothing);
    releaseBusiness();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byType(PCSocialPayoutCard),
      findsOneWidget,
      reason: 'social should enter after business hold releases',
    );
    expect(coordinator.holdCount, 1);
    notice.value = const PCNoticeMessage(
      kind: PCNoticeKind.goal,
      balance: 75,
      target: 100,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PCSocialPayoutCard), findsNothing);
    expect(
      find.byType(PCNotificationCard),
      findsOneWidget,
      reason: 'account waits for social exit',
    );
    // Claim持续呼吸，按入场时长推进，不能等到8秒自动消失后才测互斥。
    await tester.pump(const Duration(milliseconds: 300));
    var businessEntered = false;
    final done = Completer<void>();
    final request = coordinator.enqueue<void>(
      key: 'business',
      present: () async {
        businessEntered = true;
        await done.future;
      },
    );
    await tester.pump();
    expect(businessEntered, isFalse);
    await tester.pumpAndSettle();
    expect(find.byType(PCNotificationCard), findsNothing);
    expect(businessEntered, isTrue);
    done.complete();
    await request;
    notice.value = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('流程提示待处理时社交通知先退场交权，无队列自持死锁', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final social = create(tester, prefs);
    final coordinator = PCDialogCoordinator();
    final flow = PCProcessFlowController(preferences: prefs);
    final notice = ValueNotifier<PCNoticeMessage?>(null);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => PCInAppNotificationHost(
          notifier: notice,
          socialController: social,
          coordinator: coordinator,
          processFlow: flow,
          socialReady: () => true,
          socialProgress: () => .75,
          child: child!,
        ),
        home: const Scaffold(body: Text('Body')),
      ),
    );
    await tester.pump();
    await social.load();
    await tester.pump(social.nextDue!.difference(tester.binding.clock.now()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pumpAndSettle();
    expect(find.byType(PCSocialPayoutCard), findsOneWidget);
    expect(coordinator.holdCount, 1);
    await prefs.setInt('pc_quiz_num_index', 3);
    await flow.refresh();
    await tester.pumpAndSettle();
    expect(flow.hasPending, isTrue);
    expect(find.byType(PCSocialPayoutCard), findsNothing);
    expect(coordinator.holdCount, 0);
    var entered = false;
    await coordinator.enqueue<void>(
      key: 'process',
      present: () async {
        entered = true;
      },
    );
    expect(entered, isTrue);
    // 即使下一条播报到期，也不能抢待处理流程提示。
    await tester.pump(const Duration(minutes: 6));
    await tester.pumpAndSettle();
    expect(find.byType(PCSocialPayoutCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    social.dispose();
    flow.dispose();
    coordinator.dispose();
    notice.dispose();
    expect(tester.takeException(), isNull);
  });
}
