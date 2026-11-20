import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCInAppNotificationHost.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeMessage.dart';
import 'package:pennypilotcollectspin/PCTool/PCNotificationCard.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';

const account = PCNoticeMessage(
  kind: PCNoticeKind.account,
  balance: 59,
  target: 100,
);
const goal = PCNoticeMessage(kind: PCNoticeKind.goal, balance: 59, target: 100);
const highBalanceGoal = PCNoticeMessage(
  kind: PCNoticeKind.goal,
  balance: 106.25,
  target: 100,
);

void main() {
  test('四组固定单次提醒与余额服务独立，未达目标不谎报可提现', () {
    expect(PCNoticeJob.all.map((job) => job.minutes), [26, 62, 117, 162]);
    expect(PCNoticeJob.all.map((job) => job.id).toSet(), {
      5590,
      4562,
      7552,
      9475,
    });
    expect(PCNoticeJob.systemReminders.map((job) => job.id), [
      5590,
      4562,
      7552,
      9475,
    ]);
    expect(PCNoticeJob.all[2].message(99.99, 100).kind, PCNoticeKind.goal);
    expect(PCNoticeJob.all[2].message(100, 100).kind, PCNoticeKind.goal);
    expect(PCNoticeJob.all[2].message(106.25, 100).kind, PCNoticeKind.goal);
    expect(PCNoticeKind.values, [PCNoticeKind.account, PCNoticeKind.goal]);
    expect(PCNoticeJob.all[2].message(100, 150).kind, PCNoticeKind.goal);
  });

  test('金额和冷启动 payload 保留正确的目标页面，拒绝无效 payload', () {
    expect(account.amount, '\$59');
    expect(highBalanceGoal.amount, '\$106.25');
    expect(PCNoticeMessage.money(double.nan), '\$0');
    expect(
      PCNoticeMessage.parseAction(account.payload),
      PCNoticeAction.withdraw,
    );
    expect(PCNoticeMessage.parseAction(goal.payload), PCNoticeAction.earn);
    expect(
      PCNoticeMessage.parseAction(highBalanceGoal.payload),
      PCNoticeAction.earn,
    );
    for (final bad in [
      null,
      '',
      'unknown_notice',
      '{}',
      '[]',
      '{"pcNotice":1,"action":"delete"}',
    ]) {
      expect(PCNoticeMessage.parseAction(bad), isNull);
    }
  });

  test('Home 键新旧通知的点击类型统一为 background，保留提现跳转', () {
    for (final type in ['home_key', 'background']) {
      final payload = account.payloadFor(type: type);
      expect(PCNoticeMessage.analyticsType(payload), 'background');
      expect(PCNoticeMessage.parseAction(payload), PCNoticeAction.withdraw);
    }
    expect(PCNoticeMessage.analyticsType('home_key'), 'background');
    expect(
      PCNoticeMessage.analyticsType(account.payloadFor(type: 'media')),
      'media',
    );
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('通知保留四种展开收起样式在 $width 宽度不溢出', (tester) async {
      tester.view.physicalSize = Size(width, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final pair in [
                    (account, false),
                    (account, true),
                    (goal, false),
                    (goal, true),
                  ])
                    PCNotificationCard(
                      message: pair.$1,
                      compact: pair.$2,
                      onAction: () => actions++,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is PCImg && widget.name.startsWith('pc_notice_payout_'),
        ),
        findsNothing,
      );
      expect(find.text('Cash Out'), findsNothing);
      for (final button
          in find.byKey(const ValueKey('pcNoticeAction')).evaluate()) {
        await tester.tap(find.byWidget(button.widget));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(actions, 4);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('站内横幅不遮住底部操作；按钮、关闭、超时都正确收起', (tester) async {
    final notice = ValueNotifier<PCNoticeMessage?>(null);
    addTearDown(notice.dispose);
    PCNoticeMessage? opened;
    var underlying = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => PCInAppNotificationHost(
          notifier: notice,
          enableSocialNotices: false,
          onAction: (message) => opened = message,
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              onPressed: () {
                if (!PCDialogCoordinator.instance.isBusy) underlying++;
              },
              child: const Text('Underlying'),
            ),
          ),
        ),
      ),
    );
    notice.value = highBalanceGoal;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is PCImg && widget.name.startsWith('pc_notice_payout_'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Underlying'));
    expect(underlying, 1);
    expect(notice.value, isNull);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
    await tester.pump();
    expect(find.byType(PCNotificationCard), findsNothing);
    notice.value = highBalanceGoal;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pcNoticeClose')));
    await tester.pump(const Duration(milliseconds: 50));
    // 通知还在退场时，第一次业务点击也必须立即得到响应。
    await tester.tap(find.text('Underlying'));
    expect(underlying, 2);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(notice.value, isNull);
    expect(opened, isNull);
    notice.value = highBalanceGoal;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pcNoticeAction')));
    await tester.pumpAndSettle();
    expect(opened, same(highBalanceGoal));
    expect(notice.value, isNull);
    await tester.pump(const Duration(milliseconds: 500));
    notice.value = highBalanceGoal;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(
      find.byKey(const ValueKey('pcInAppNotice')),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(notice.value, isNull);
    expect(tester.takeException(), isNull);
    notice.value = goal;
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(notice.value, isNull);
    expect(find.byType(PCNotificationCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
