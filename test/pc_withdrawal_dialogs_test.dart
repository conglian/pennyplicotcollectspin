import 'dart:async';

import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCOtherDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalDialogs.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/pc_text.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalQueueTable.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';

void main() {
  var cleanupRegistered = false;
  setUp(() => cleanupRegistered = false);
  Future<void> show(
    WidgetTester tester,
    Widget dialog,
    ValueChanged<Object?> result, {
    bool reduced = true,
  }) async {
    if (!cleanupRegistered) {
      cleanupRegistered = true;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result(await context.tipShow2(dialog, scaleContent: false)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(); // 路由建好后给内容Ticker第一帧，再计动画时长。
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 350));
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(430, 932),
  ]) {
    testWidgets('提现弹窗在$size安全区内按钮可见、图片分层与动态数据正确', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(() => dispose(tester));
      final dialogs = <(Widget, String)>[
        (
          const PCWithdrawalReviewVerificationDialog(collected: 6),
          'pcWithdrawalVerificationContinue',
        ),
        (
          const PCWithdrawalPriorityGiftDialog(autoOpenDuration: Duration.zero),
          'pcWithdrawalGiftOpen',
        ),
        (
          PCWithdrawalGiftRewardDialog(
            diamondAmount: 2.75,
            collected: 6,
            onClaim: () async => true,
          ),
          'pcWithdrawalGiftClaim',
        ),
        (
          PCWithdrawalDiamondCountdownDialog(
            withdrawalTarget: 125,
            deadline: DateTime(2026, 10, 27),
            now: () => DateTime(2026, 10, 26, 23, 59, 12),
            notificationsEnabled: false,
          ),
          'pcWithdrawalRemindMe',
        ),
        (
          PCWithdrawalApprovalDialog(
            withdrawalTarget: 125,
            rank: 13,
            queueCount: 215,
            entries: const [
              PCWithdrawalQueueEntry(
                userId: '001',
                account: 'a***@mail.com',
                amount: 125,
              ),
            ],
            onSkipWait: () async => false,
          ),
          'pcWithdrawalSkipWait',
        ),
        (
          PCWithdrawalLastStepDialog(
            withdrawalTarget: 125,
            taskTitle: 'quiz',
            progress: 7,
            target: 30,
            onAction: () async => false,
          ),
          'pcWithdrawalTaskAction',
        ),
        (
          const PCWithdrawalInsufficientDialog(
            balance: 96,
            withdrawalTarget: 125,
          ),
          'pcWithdrawalKeepEarning',
        ),
      ];
      for (final (dialog, key) in dialogs) {
        await show(tester, dialog, (_) {});
        expect(tester.takeException(), isNull, reason: '$dialog');
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width + .01));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 34 + .01));
        expect(rect.height, greaterThanOrEqualTo(44), reason: '$dialog');
        if (dialog is PCWithdrawalGiftRewardDialog) {
          expect(find.text('8.75/20'), findsOneWidget);
          expect(find.text('×2.75'), findsNWidgets(2));
          expect(
            find.byKey(const ValueKey('pcWithdrawalGiftRewardClose')),
            findsNothing,
          );
          expect(find.byType(IconButton), findsNothing);
          expect(
            find.byWidgetPredicate(
              (w) => w is PCImg && w.name == 'pc_withdraw_gift_diamond',
            ),
            findsOneWidget,
          );
        }
        if (dialog is PCWithdrawalDiamondCountdownDialog) {
          expect(find.text('00:00:48'), findsOneWidget);
          expect(find.text('\$125 Amount Review Approved'), findsOneWidget);
        }
        if (dialog is PCWithdrawalLastStepDialog) {
          expect(find.text('Answer 7/30 Question Right'), findsOneWidget);
          expect(find.text('7/30'), findsOneWidget);
        }
        await dispose(tester);
      }
    });
  }

  for (final (balance, target, remaining) in [
    (56.0, 100.0, '\$44'),
    (56.25, 150.0, '\$93.75'),
    (200.0, 100.0, '\$0'),
  ]) {
    testWidgets('余额不足文案按目标$target减余额$balance显示差额$remaining', (tester) async {
      await show(
        tester,
        PCWithdrawalInsufficientDialog(
          balance: balance,
          withdrawalTarget: target,
        ),
        (_) {},
      );
      expect(find.text('Only '), findsOneWidget);
      expect(find.text(' left to withdraw'), findsOneWidget);
      final amount = tester.widget<PCStrokeText>(
        find.byKey(const ValueKey('pcWithdrawalInsufficientAmount')),
      );
      expect(amount.text, remaining);
      expect(find.text('Answer '), findsNothing);
      expect(find.text(' Question Right'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('审核进度自动从0到40后只关闭一次，关闭不误关后续页面', (tester) async {
    Object? result;
    var results = 0;
    await show(
      tester,
      const PCWithdrawalReviewPendingDialog(withdrawalTarget: 125),
      (value) {
        result = value;
        results++;
      },
      reduced: false,
    );
    expect(find.text('\$125'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    final bar = tester.widget<PCWithdrawalProgressBar>(
      find.byKey(const ValueKey('pcWithdrawalPendingProgress')),
    );
    expect(bar.progress, greaterThan(0));
    expect(bar.progress, lessThan(.4));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, true);
    expect(results, 1);
    expect(find.text('Open'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(results, 1);
    await dispose(tester);
  });

  testWidgets('礼包先抖动倒计时3秒，2999毫秒前不抬盖，开箱后不自动跳页', (tester) async {
    Object? result;
    var results = 0;
    await show(tester, const PCWithdrawalPriorityGiftDialog(), (value) {
      result = value;
      results++;
    }, reduced: false);
    final key = find.byKey(const ValueKey('pcWithdrawalGiftOpen'));
    final diamond = find.byWidgetPredicate(
      (widget) => widget is PCImg && widget.name == 'pc_withdraw_gift_diamond',
    );
    double lidY() => tester
        .widget<Transform>(find.byKey(const ValueKey('pcWithdrawalGiftLid')))
        .transform
        .storage[13];
    expect(
      tester.widget<PCWithdrawalGreenButton>(key).text,
      'Click To Open(3s)',
    );
    expect(tester.widget<PCWithdrawalGreenButton>(key).onTap, isNotNull);
    expect(diamond, findsNothing);
    expect(lidY(), 0);

    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<PCWithdrawalGreenButton>(key).text,
      'Click To Open(2s)',
    );
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('pcWithdrawalGiftArtwork')),
          )
          .transform
          .storage[1],
      isNot(closeTo(0, .001)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<PCWithdrawalGreenButton>(key).text,
      'Click To Open(1s)',
    );
    await tester.pump(const Duration(milliseconds: 999));
    expect(diamond, findsNothing);
    expect(lidY(), 0);
    expect(result, isNull);
    expect(results, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.widget<PCWithdrawalGreenButton>(key).text, 'Click To Open');
    await tester.pump(const Duration(milliseconds: 16));
    expect(lidY(), lessThan(0));
    expect(lidY(), greaterThan(-85));
    expect(diamond, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(lidY(), closeTo(-85, .001));
    await tester.pump(const Duration(seconds: 12));
    expect(result, isNull);
    expect(results, 0);
    expect(find.byType(PCWithdrawalPriorityGiftDialog), findsOneWidget);
    expect(find.byType(PCWithdrawalGiftRewardDialog), findsNothing);
    await tester.tap(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, true);
    expect(results, 1);
    await dispose(tester);
  });

  for (final phase in ['等待', '开箱中', '开箱后']) {
    for (final artwork in [false, true]) {
      testWidgets('礼包$phase点击${artwork ? '礼盒' : '按钮'}立即进入下一步且防重复关闭', (
        tester,
      ) async {
        Object? result;
        var results = 0;
        await show(tester, const PCWithdrawalPriorityGiftDialog(), (value) {
          result = value;
          results++;
        }, reduced: false);
        if (phase != '等待') {
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(Duration(milliseconds: phase == '开箱中' ? 450 : 900));
        }
        final button = find.byKey(const ValueKey('pcWithdrawalGiftOpen'));
        final stale = tester.widget<PCWithdrawalGreenButton>(button).onTap!;
        await tester.tap(
          artwork ? find.byKey(const ValueKey('pcWithdrawalGiftTap')) : button,
        );
        stale();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(result, true);
        expect(results, 1);
        expect(find.byType(PCWithdrawalPriorityGiftDialog), findsNothing);
        expect(find.text('Open'), findsOneWidget);
        stale();
        await tester.pump(const Duration(seconds: 5));
        expect(results, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('礼包空白不触发下一步，关闭按钮仍返回false且取消倒计时', (tester) async {
    Object? result;
    var results = 0;
    await show(tester, const PCWithdrawalPriorityGiftDialog(), (value) {
      result = value;
      results++;
    }, reduced: false);
    final artwork = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalGiftTap')),
    );
    await tester.tapAt(artwork.topLeft - const Offset(20, 20));
    await tester.pump();
    expect(result, isNull);
    expect(results, 0);
    await tester.tap(find.byKey(const ValueKey('pcWithdrawalGiftClose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, false);
    expect(results, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(results, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动画仍完整等待3秒，无抖动，结束后静态打开但不跳页', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    Object? result;
    await show(
      tester,
      const PCWithdrawalPriorityGiftDialog(),
      (value) => result = value,
    );
    final key = find.byKey(const ValueKey('pcWithdrawalGiftOpen'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      tester.widget<PCWithdrawalGreenButton>(key).text,
      'Click To Open(2s)',
    );
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('pcWithdrawalGiftArtwork')),
          )
          .transform
          .storage[1],
      0,
    );
    final diamond = find.byWidgetPredicate(
      (widget) => widget is PCImg && widget.name == 'pc_withdraw_gift_diamond',
    );
    await tester.pump(const Duration(milliseconds: 1499));
    expect(diamond, findsNothing);
    expect(
      tester.widget<PCWithdrawalGreenButton>(key).text,
      'Click To Open(1s)',
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(diamond, findsOneWidget);
    expect(tester.widget<PCWithdrawalGreenButton>(key).text, 'Click To Open');
    final lid = find.byWidgetPredicate(
      (widget) => widget is PCImg && widget.name == 'pc_withdraw_gift_lid',
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: lid, matching: find.byType(Opacity)).first,
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final opening in [false, true]) {
    testWidgets('礼包${opening ? '开箱中' : '等待中'}卸载后释放动画且不再触发回调', (tester) async {
      await show(
        tester,
        const PCWithdrawalPriorityGiftDialog(),
        (_) {},
        reduced: false,
      );
      await tester.pump(Duration(milliseconds: opening ? 3000 : 1500));
      if (opening) await tester.pump(const Duration(milliseconds: 450));
      await dispose(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('激活通道横幅侧面进入、停留2秒并原路退出', (tester) async {
    Object? result;
    var results = 0;
    await show(
      tester,
      const PCWithdrawalChannelActivatedDialog(withdrawalTarget: 125),
      (value) {
        result = value;
        results++;
      },
      reduced: false,
    );
    double offset() => tester
        .widget<Transform>(
          find.byKey(const ValueKey('pcWithdrawalChannelSlide')),
        )
        .transform
        .storage[12];
    expect(offset(), lessThan(-800));
    await tester.pump(const Duration(milliseconds: 466));
    expect(offset(), closeTo(0, .01));
    expect(find.text('Withdrawal Boost\nAccess Unlocked'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(result, isNull);
    expect(offset(), closeTo(0, .01));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 225));
    expect(offset(), lessThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, true);
    expect(results, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(results, 1);
    await dispose(tester);
  });

  for (final throws in [false, true]) {
    testWidgets('礼盒领奖${throws ? '异常' : '失败'}保留、在途防重，成功才返回', (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      Object? result;
      await show(
        tester,
        PCWithdrawalGiftRewardDialog(
          diamondAmount: .65,
          onClaim: () async {
            calls++;
            if (calls == 1) return pending.future;
            return true;
          },
        ),
        (value) => result = value,
      );
      final finder = find.byKey(const ValueKey('pcWithdrawalGiftClaim'));
      final stale = tester.widget<PCWithdrawalGreenButton>(finder).onTap!;
      stale();
      stale();
      await tester.pump();
      expect(calls, 1);
      expect(result, isNull);
      expect(tester.widget<PCWithdrawalGreenButton>(finder).busy, isTrue);
      if (throws) {
        pending.completeError(StateError('save failed'));
      } else {
        pending.complete(false);
      }
      await tester.pump();
      expect(find.byType(PCWithdrawalGiftRewardDialog), findsOneWidget);
      expect(result, isNull);
      expect(tester.widget<PCWithdrawalGreenButton>(finder).busy, isFalse);
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 2);
      expect(result, true);
      await dispose(tester);
    });
  }

  testWidgets('倒计时不为负、通知状态决定提醒按钮且返回正确动作', (tester) async {
    for (final enabled in [false, true]) {
      Object? result;
      await show(
        tester,
        PCWithdrawalDiamondCountdownDialog(
          withdrawalTarget: 150,
          deadline: DateTime(2026, 10, 27),
          now: () => DateTime(2026, 10, 27, 0, 0, 1),
          notificationsEnabled: enabled,
        ),
        (value) => result = value,
      );
      expect(find.text('00:00:00'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pcWithdrawalRemindMe')),
        enabled ? findsNothing : findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          ValueKey(
            enabled ? 'pcWithdrawalOpenTomorrow' : 'pcWithdrawalRemindMe',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        result,
        enabled
            ? PCWithdrawalCountdownAction.openTomorrow
            : PCWithdrawalCountdownAction.remindMe,
      );
      await dispose(tester);
    }
  });

  for (final video in [false, true]) {
    for (final outcome in [
      PCWithdrawalAdResult.cancelled,
      PCWithdrawalAdResult.notApplied,
      PCWithdrawalAdResult.failed,
    ]) {
      testWidgets('${video ? '任务' : '排队'}typed结果$outcome仅真实失败显示广告失败', (
        tester,
      ) async {
        var requests = 0;
        Future<PCWithdrawalAdResult> action() async {
          requests++;
          return outcome;
        }

        await show(
          tester,
          video
              ? PCWithdrawalLastStepDialog(
                  withdrawalTarget: 100,
                  taskTitle: 'video',
                  progress: 2,
                  target: 10,
                  onActionOutcome: action,
                )
              : PCWithdrawalApprovalDialog(
                  withdrawalTarget: 100,
                  rank: 9,
                  queueCount: 20,
                  onSkipWaitOutcome: action,
                ),
          (_) {},
        );
        final button = find.byKey(
          ValueKey(video ? 'pcWithdrawalTaskAction' : 'pcWithdrawalSkipWait'),
        );
        await tester.tap(button);
        await tester.pump();
        expect(requests, 1);
        expect(
          find.byType(PCAdLoadingFailedDialog),
          outcome == PCWithdrawalAdResult.failed
              ? findsOneWidget
              : findsNothing,
        );
        expect(find.byType(PCWithdrawalRankToast), findsNothing);
        if (outcome != PCWithdrawalAdResult.failed) {
          expect(tester.widget<PCWithdrawalBlueButton>(button).busy, isFalse);
          await tester.tap(button);
          await tester.pump();
          expect(requests, 2, reason: '取消后允许用户手动重新尝试');
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${video ? '任务' : '排队'}保存异常只显示保存Toast，保留可重试界面', (tester) async {
      var requests = 0;
      Future<PCWithdrawalAdResult> action() async {
        requests++;
        throw StateError('provider reload failed after successful ad');
      }

      await show(
        tester,
        video
            ? PCWithdrawalLastStepDialog(
                withdrawalTarget: 100,
                taskTitle: 'video',
                progress: 2,
                target: 10,
                onActionOutcome: action,
              )
            : PCWithdrawalApprovalDialog(
                withdrawalTarget: 100,
                rank: 9,
                queueCount: 20,
                onSkipWaitOutcome: action,
              ),
        (_) {},
      );
      final button = find.byKey(
        ValueKey(video ? 'pcWithdrawalTaskAction' : 'pcWithdrawalSkipWait'),
      );
      await tester.tap(button);
      await tester.pump();
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(
        find.text('Unable to save progress. Please try again.'),
        findsOneWidget,
      );
      expect(tester.widget<PCWithdrawalBlueButton>(button).busy, isFalse);
      expect(requests, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('排队广告失败Try Again仅关闭，再次手动进入成功才更新排名', (tester) async {
    var calls = 0;
    var rank = 22;
    var total = 228;
    Object? result;
    await show(
      tester,
      PCWithdrawalApprovalDialog(
        withdrawalTarget: 100,
        rank: rank,
        queueCount: 228,
        currentRank: () => rank,
        currentQueueCount: () => total,
        onSkipWait: () async {
          calls++;
          if (calls == 1) return false;
          rank -= 6;
          total -= 2;
          return true;
        },
      ),
      (value) => result = value,
    );
    final finder = find.byKey(const ValueKey('pcWithdrawalSkipWait'));
    await tester.tap(finder);
    await tester.pump();
    expect(result, isNull);
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(find.byType(PCWithdrawalWhiteCard), findsNothing);
    expect(PCDialogCoordinator.instance.pendingCount, 0);
    expect(rank, 22);
    expect(total, 228);
    await tester.tap(find.byType(PCGreenDialogButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, false);
    expect(calls, 1, reason: 'Try Again只关闭，不再次请求广告');
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    result = null;
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder);
    await tester.pump();
    expect(calls, 2);
    expect(result, isNull);
    final text = tester.widget<PCText>(
      find.byKey(const ValueKey('pcWithdrawalRankToastValue')),
    );
    expect(text.text, '16');
    expect(find.text('226'), findsNWidgets(2));
    await tester.tap(finder);
    await tester.pump();
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isNull, reason: '未到第一名时不能自动关闭排队弹窗');
    expect(find.byType(PCWithdrawalApprovalDialog), findsOneWidget);
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    await tester.tap(finder);
    await tester.pump();
    expect(calls, 3, reason: '反馈结束后可继续观看下一次广告');
    expect(rank, 10);
    expect(total, 224);
    await tester.tap(find.byKey(const ValueKey('pcWithdrawalClose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, false, reason: '广告结束后可在排名反馈期间主动关闭');
    expect(find.byType(PCWithdrawalApprovalDialog), findsNothing);
    await dispose(tester);
  });

  testWidgets('排队弹窗定位99名，广告成功后跟随94名且保留固定表头', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var rank = 99;
    var total = 388;
    await show(
      tester,
      PCWithdrawalApprovalDialog(
        withdrawalTarget: 100,
        rank: rank,
        queueCount: total,
        account: '2***5532',
        currentRank: () => rank,
        currentQueueCount: () => total,
        onSkipWait: () async {
          rank = 94;
          total = 386;
          return true;
        },
      ),
      (_) {},
    );
    final list = find.byKey(const ValueKey('pcWithdrawalQueueList'));
    final header = find.byKey(const ValueKey('pcWithdrawalQueueHeader'));
    final headerRect = tester.getRect(header);
    void expectCurrent(int expected) {
      final current = find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow'));
      expect(
        find.descendant(
          of: current,
          matching: find.text('$expected'.padLeft(3, '0')),
        ),
        findsOneWidget,
      );
      final rowRect = tester.getRect(current);
      final viewport = tester.getRect(list);
      expect(rowRect.top, greaterThanOrEqualTo(viewport.top - .01));
      expect(rowRect.bottom, lessThanOrEqualTo(viewport.bottom + .01));
      expect(
        find.descendant(of: current, matching: find.text('2***5532')),
        findsOneWidget,
      );
    }

    expectCurrent(99);
    final controller = tester.widget<ListView>(list).controller!;
    final before = controller.offset;
    await tester.tap(find.byKey(const ValueKey('pcWithdrawalSkipWait')));
    await tester.pump();
    await tester.pump();
    expectCurrent(94);
    expect(controller.offset, lessThan(before));
    expect(tester.getRect(header), headerRect);
    expect(
      tester
          .widget<PCWithdrawalQueueTable>(find.byType(PCWithdrawalQueueTable))
          .queueCount,
      386,
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(375, 812),
    const Size(430, 932),
  ]) {
    testWidgets('排队关闭按钮在$size与标题对齐且点击关闭', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Object? result;
      await show(
        tester,
        PCWithdrawalApprovalDialog(
          withdrawalTarget: 100,
          rank: 99,
          queueCount: 388,
          onSkipWait: () async => false,
        ),
        (value) => result = value,
      );
      final panel = tester.getRect(
        find.byKey(const ValueKey('pcWithdrawalWhitePanel')),
      );
      final close = find.byKey(const ValueKey('pcWithdrawalClose'));
      final icon = find.descendant(
        of: close,
        matching: find.byIcon(Icons.close_rounded),
      );
      final center = tester.getCenter(icon);
      final scale = panel.width / 304;
      expect(center.dx, closeTo(panel.left + 276 * scale, .01));
      expect(center.dy, closeTo(panel.top + 28 * scale, .01));
      expect(
        center.dy,
        closeTo(tester.getCenter(find.text('Withdrawal Approval')).dy, .01),
      );
      await tester.tap(close);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(result, false);
      expect(find.byType(PCWithdrawalApprovalDialog), findsNothing);
    });
  }

  testWidgets('视频任务失败Try Again仅关闭，手动重开任务成功才计次', (tester) async {
    var pending = Completer<bool>();
    var calls = 0;
    Object? result;
    await show(
      tester,
      PCWithdrawalLastStepDialog(
        withdrawalTarget: 100,
        taskTitle: 'video',
        progress: 2,
        target: 8,
        onAction: () async {
          calls++;
          return pending.future;
        },
      ),
      (value) => result = value,
    );
    final finder = find.byKey(const ValueKey('pcWithdrawalTaskAction'));
    final stale = tester.widget<PCWithdrawalBlueButton>(finder).onTap!;
    stale();
    stale();
    await tester.pump();
    expect(calls, 1);
    pending.complete(false);
    await tester.pump();
    expect(result, isNull);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(find.byType(PCWithdrawalWhiteCard), findsNothing);
    expect(PCDialogCoordinator.instance.pendingCount, 0);
    await tester.tap(find.byType(PCGreenDialogButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, false);
    expect(calls, 1, reason: 'Try Again只关闭，不再次请求视频');
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    pending = Completer<bool>();
    result = null;
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder);
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Watch 2/8 Videos'), findsOneWidget);
    expect(find.text('2/8'), findsOneWidget);
    pending.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, true);
    await dispose(tester);
  });

  testWidgets('视频成功逐次刷新本地进度，未满目标保持弹窗，满额只关闭一次', (tester) async {
    var progress = 0;
    var calls = 0;
    var results = 0;
    Object? result;
    Completer<bool>? pending;
    await show(
      tester,
      PCWithdrawalLastStepDialog(
        withdrawalTarget: 125,
        taskTitle: 'video',
        progress: 0,
        target: 3,
        currentProgress: () => progress,
        onAction: () async {
          calls++;
          pending = Completer<bool>();
          final success = await pending!.future;
          if (success) progress++;
          return success;
        },
      ),
      (value) {
        result = value;
        results++;
      },
    );
    final action = find.byKey(const ValueKey('pcWithdrawalTaskAction'));
    for (var step = 1; step <= 3; step++) {
      final stale = tester.widget<PCWithdrawalBlueButton>(action).onTap!;
      stale();
      stale();
      await tester.pump();
      expect(calls, step);
      expect(tester.widget<PCWithdrawalBlueButton>(action).busy, isTrue);
      expect(result, isNull);
      expect(find.text('Watch ${step - 1}/3 Videos'), findsOneWidget);
      pending!.complete(true);
      await tester.pump();
      await tester.pump();
      if (step < 3) {
        expect(result, isNull);
        expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
        expect(find.text('Watch $step/3 Videos'), findsOneWidget);
        expect(find.text('$step/3'), findsOneWidget);
        expect(tester.widget<PCWithdrawalBlueButton>(action).busy, isFalse);
      } else {
        // 退场期间旧帧再触发也不能再次请求广告或重复关闭。
        stale();
        await tester.pump(const Duration(milliseconds: 400));
        expect(result, true);
        expect(results, 1);
        expect(calls, 3);
      }
    }
    expect(progress, 3);
    await dispose(tester);
  });

  testWidgets('旧视频API以及非视频任务保留成功立即返回行为', (tester) async {
    for (final title in ['video', 'quiz', 'spin']) {
      Object? result;
      await show(
        tester,
        PCWithdrawalLastStepDialog(
          withdrawalTarget: 100,
          taskTitle: title,
          progress: 1,
          target: 8,
          currentProgress: title == 'video' ? null : () => 2,
          onAction: () async => true,
        ),
        (value) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('pcWithdrawalTaskAction')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, true, reason: title);
      await dispose(tester);
    }
  });
}
