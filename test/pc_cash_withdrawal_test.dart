import 'dart:async';

import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCOtherDialogWidgets.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCCash.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCCashWithdrawalContent.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessAccountDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalRankToast.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:pennypilotcollectspin/PCTool/PCAdOutcome.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalQueueTable.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_GradientText.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  DateTime clock = DateTime(2030, 1, 1, 12);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  Future<void> advance(WidgetTester tester, [int milliseconds = 400]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  Future<PCWithdrawalController> create(
    PCWithdrawalStage stage, {
    String task = 'quiz',
    int withdrawalTarget = 100,
    int boundPayment = 0,
    int? viewedPayment,
    String account = 'p***.com',
    Future<bool> Function(String)? ad,
    Future<PCAdOutcome> Function(String)? adOutcome,
    Future<void> Function()? onSync,
  }) async {
    clock = DateTime(2030, 1, 1, 12);
    final level = stage == PCWithdrawalStage.insufficient
        ? 0
        : stage == PCWithdrawalStage.reviewing ||
              stage == PCWithdrawalStage.reviewApproved
        ? 1
        : 2;
    SharedPreferences.setMockInitialValues({
      'pc_pig_level': level,
      'pc_dollar_number': level == 0 ? 10.0 : 100.0,
      'pc_quiz_diamonds': stage == PCWithdrawalStage.reviewApproved
          ? 20.0
          : level == 0
          ? 0.0
          : 5.0,
      'pc_quiz_gold':
          stage == PCWithdrawalStage.queue ||
              stage == PCWithdrawalStage.lastStep
          ? 10.0
          : level == 2
          ? 2.5
          : 0.0,
      'pc_account_id': account,
      'pc_account_seled_index': boundPayment,
      if (viewedPayment != null) PCCash.viewPaymentKey: viewedPayment,
      'pc_pig_upgrade_seen_level_v1': level,
      PCPigProgress.diamondEnteredKey: clock.toIso8601String(),
      PCPigProgress.diamondDeadlineKey: DateTime(2030, 1, 2).toIso8601String(),
      if (stage == PCWithdrawalStage.reviewApproved)
        PCPigProgress.diamondCountdownStartedKey: clock.toIso8601String(),
      PCNumberHelpers.configKey: jsonEncode({
        if (withdrawalTarget != 100)
          'eq_range': [
            withdrawalTarget,
            withdrawalTarget + 20,
            withdrawalTarget + 50,
            withdrawalTarget + 100,
          ],
        'queue_number': [
          {
            'int_all': 20,
            'int_current': 5,
            'int_all_delete': [1, 1],
            'int_current_delete': [2, 2],
          },
        ],
        'tixian_task': [
          {'title': task, 'data': 10},
        ],
      }),
      PCWithdrawalController.storageKey: jsonEncode({
        'version': 1,
        'observedLevel': level,
        'diamondStarted': level == 1,
        'diamondStep': 7,
        'goldUpgradeAcknowledged': true,
        'queueInitialized': level == 2,
        'queueRank': stage == PCWithdrawalStage.lastStep ? 1 : 5,
        'queueTotal': 20,
        'queueSeed': 17,
        'taskIndex': 0,
        'taskCycle': 0,
        'taskProgress': 3,
        'quizCursor': 0,
        'pending': [],
      }),
    });
    final controller = PCWithdrawalController(
      now: () => clock,
      requestAd: ad ?? (_) async => false,
      requestAdOutcome: adOutcome,
      onSync: onSync,
      scheduleMidnightTimer: false,
    );
    await controller.load();
    await PCLocalProvider.instance.init();
    expect(controller.stage, stage);
    return controller;
  }

  Future<void> mount(
    WidgetTester tester,
    PCWithdrawalController controller, {
    VoidCallback? quiz,
    VoidCallback? wheel,
    Future<bool> Function()? permission,
    Future<bool> Function()? requestPermission,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await advance(tester);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PCCash(
          controller: controller,
          onGoQuiz: quiz,
          onGoWheel: wheel,
          isNotificationEnabled: permission ?? () async => false,
          requestNotifications: requestPermission ?? () async => false,
        ),
      ),
    );
    await advance(tester);
  }

  Future<void> clean(
    WidgetTester tester,
    PCWithdrawalController controller,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await advance(tester);
    controller.dispose();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await advance(tester);
  }

  Future<void> repeatDisabled(WidgetTester tester, String key) async {
    final button = tester.widget<ParticleButton>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(ParticleButton),
      ),
    );
    expect(button.enabled, isFalse);
    button.onTap(); // 已派发的旧点击回调也必须被业务层拒绝。
    await tester.pump();
  }

  for (final video in [false, true]) {
    for (final outcome in [PCAdOutcome.cancelled, PCAdOutcome.failed]) {
      testWidgets('Cash${video ? '视频任务' : '排队'}$outcome仅真实失败显示广告失败', (
        tester,
      ) async {
        var requests = 0;
        final controller = await create(
          video ? PCWithdrawalStage.lastStep : PCWithdrawalStage.queue,
          task: 'video',
          adOutcome: (_) async {
            requests++;
            return outcome;
          },
        );
        await mount(tester, controller);
        final action = video ? 'pcCashTaskGo' : 'pcCashSkipQueue';
        await tap(tester, action);
        expect(requests, 1);
        expect(controller.taskProgress, 3);
        expect(controller.queueRank, video ? 1 : 5);
        expect(PCDialogCoordinator.instance.holdCount, 0);
        expect(
          find.byType(PCAdLoadingFailedDialog),
          outcome == PCAdOutcome.failed ? findsOneWidget : findsNothing,
        );
        if (outcome == PCAdOutcome.failed) {
          await tester.tap(find.byType(PCGreenDialogButton));
          await advance(tester);
          expect(requests, 1, reason: '失败提示仅关闭，不自动重试');
        } else {
          await tap(tester, action);
          expect(requests, 2, reason: '取消后原入口仍可手动重试');
        }
        expect(tester.takeException(), isNull);
        await clean(tester, controller);
      });
    }

    testWidgets('Cash${video ? '视频任务' : '排队'}广告成功后保存同步异常只提示保存问题', (
      tester,
    ) async {
      final controller = await create(
        video ? PCWithdrawalStage.lastStep : PCWithdrawalStage.queue,
        task: 'video',
        adOutcome: (_) async => PCAdOutcome.success,
        onSync: () async => throw StateError('provider reload unavailable'),
      );
      await mount(tester, controller);
      await tap(tester, video ? 'pcCashTaskGo' : 'pcCashSkipQueue');
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(
        find.text('Unable to save progress. Please try again.'),
        findsOneWidget,
      );
      expect(controller.isBusy, isFalse);
      expect(PCDialogCoordinator.instance.holdCount, 0);
      expect(
        video ? controller.taskProgress > 3 : controller.queueRank < 5,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await clean(tester, controller);
    });
  }

  for (final stage in [
    PCWithdrawalStage.reviewing,
    PCWithdrawalStage.reviewApproved,
  ]) {
    testWidgets('提现${stage.name}设计文案使用配置目标125且不改变真实收集状态', (tester) async {
      final controller = await create(stage, withdrawalTarget: 125);
      await mount(tester, controller);
      expect(
        find.text('Collect 20 Diamonds To Speed Up Your \$125 Approval.'),
        findsOneWidget,
      );
      expect(
        find.text('Collect 20 Diamonds To Speed Up Your \$100 Approval.'),
        findsNothing,
      );
      expect(controller.stage, stage);
      expect(
        controller.diamonds,
        stage == PCWithdrawalStage.reviewing ? 5 : 20,
      );
      await clean(tester, controller);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(430, 932),
  ]) {
    testWidgets('提现六状态在$size安全区内可滚动，按钮背景完整且数据正确', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      for (final stage in PCWithdrawalStage.values) {
        final controller = await create(stage);
        await mount(tester, controller);
        expect(find.text('Choose payout amount'), findsOneWidget);
        if (stage != PCWithdrawalStage.insufficient) {
          expect(
            find.byKey(ValueKey('pcCashStage_${stage.name}')),
            findsOneWidget,
          );
          final key = switch (stage) {
            PCWithdrawalStage.reviewing => 'pcCashCollectDiamonds',
            PCWithdrawalStage.reviewApproved => 'pcCashRemindTomorrow',
            PCWithdrawalStage.releasing => 'pcCashCollectGold',
            PCWithdrawalStage.queue => 'pcCashSkipQueue',
            _ => 'pcCashTaskGo',
          };
          final action = find.byKey(ValueKey(key));
          await tester.ensureVisible(action);
          await tester.pump();
          final rect = tester.getRect(action);
          expect(rect.top, greaterThanOrEqualTo(24));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 34 + .01));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          final background = find.descendant(
            of: action,
            matching: find.byKey(const ValueKey('pcCashActionBackground')),
          );
          expect(tester.getRect(background), rect, reason: '渐变背景必须填满点击框');
          expect(action.hitTestable(), findsOneWidget);
        }
        switch (stage) {
          case PCWithdrawalStage.reviewing:
            expect(find.text('5/20'), findsNWidgets(2));
            expect(find.text('Review Task'), findsOneWidget);
            expect(
              find.text('Collect 20 Diamonds To Speed Up Your \$100 Approval.'),
              findsOneWidget,
            );
            expect(controller.diamondDeadline, isNull);
            expect(
              find.byKey(const ValueKey('pcCashCountdownPanel')),
              findsNothing,
            );
          case PCWithdrawalStage.reviewApproved:
            expect(
              find.text('Come Back Tomorrow To Confirm Release Details.'),
              findsOneWidget,
            );
            expect(
              find.text('Collect 20 Diamonds To Speed Up Your \$100 Approval.'),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<PCGradientStrokeText>(
                    find.byKey(const ValueKey('pcCashCountdownNumber')),
                  )
                  .text,
              '12:00:00',
            );
          case PCWithdrawalStage.releasing:
            expect(find.text('2.5/10'), findsNWidgets(2));
            expect(find.text('Reviewing'), findsOneWidget);
            expect(find.text('Release details confirmed'), findsOneWidget);
            expect(
              find.text('Come Back Tomorrow To Confirm Release Details.'),
              findsOneWidget,
            );
            expect(find.text('Collect 10 Golden Brick'), findsOneWidget);
          case PCWithdrawalStage.queue:
            expect(
              find.text('20 In Queue, Your Current Rank: 5'),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('pcCashQueueTable')),
              findsOneWidget,
            );
          case PCWithdrawalStage.lastStep:
            expect(find.text('3/10'), findsNWidgets(2));
            expect(find.text('Answer 3/10 Question Right'), findsNWidgets(2));
            expect(find.text('Final Task:'), findsOneWidget);
            expect(find.text('GO'), findsOneWidget);
          case PCWithdrawalStage.insufficient:
            expect(
              find.byKey(const ValueKey('pcCashPayout_100')),
              findsOneWidget,
            );
        }
        if (stage == PCWithdrawalStage.reviewing ||
            stage == PCWithdrawalStage.releasing ||
            stage == PCWithdrawalStage.lastStep) {
          final progress = find.byKey(
            ValueKey(switch (stage) {
              PCWithdrawalStage.reviewing => 'pcCashDiamondProgress',
              PCWithdrawalStage.releasing => 'pcCashGoldProgress',
              _ => 'pcCashTaskProgress',
            }),
          );
          final count = find.descendant(
            of: progress,
            matching: find.byType(PCStrokeText),
          );
          final label = tester.widget<PCStrokeText>(count);
          expect(label.color, const Color(0xFFFFDD1D));
          expect(label.skColor, const Color(0xFF704300));
          expect(label.skWidth, greaterThan(0));
          expect(label.align, TextAlign.right);
          expect(
            tester.getRect(count).right,
            closeTo(tester.getRect(progress).right, .1),
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('pcCashWithdraw_200')),
        );
        await tester.pump();
        expect(
          tester
              .getRect(find.byKey(const ValueKey('pcCashWithdraw_200')))
              .bottom,
          lessThanOrEqualTo(size.height - 34 + .01),
        );
        expect(tester.takeException(), isNull);
        await clean(tester, controller);
      }
    });
  }

  testWidgets('Cash Out和各档提现正确，切换渠道按界面顺序循环并持久化，Logo保留编辑入口', (tester) async {
    final controller = await create(PCWithdrawalStage.insufficient);
    await mount(tester, controller);
    await tap(tester, 'pcCashCurrentPrompt');
    expect(controller.next?.kind, PCWithdrawalPromptKind.insufficient);
    expect(controller.next?.withdrawalTarget, 100);
    await controller.dismiss(controller.next!);
    for (final amount in [100, 120, 150, 200]) {
      await tap(tester, 'pcCashWithdraw_$amount');
      expect(controller.next?.withdrawalTarget, amount);
      await controller.dismiss(controller.next!);
    }
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('pc_account_id');
    final backgrounds = <Color>{};
    final pageBackgrounds = <Color>{};
    final buttonSize = tester.getSize(
      find.byKey(const ValueKey('pcCashPaymentBackground')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pcCashChangePayment')),
        matching: find.byWidgetPredicate(
          (w) => w is PCImg && w.name == 'cs_time_icon',
        ),
      ),
      findsOneWidget,
    );
    final logoBounds = tester.getRect(
      find.byKey(const ValueKey('pcCashPayment')),
    );
    final switchBounds = tester.getRect(
      find.byKey(const ValueKey('pcCashChangePayment')),
    );
    expect(switchBounds.left, greaterThanOrEqualTo(logoBounds.right));
    expect(switchBounds.left - logoBounds.right, lessThan(16));
    expect(
      switchBounds.center.dx,
      lessThan(tester.view.physicalSize.width / 2),
    );
    expect(find.byKey(const ValueKey('pcCashPaymentDetails')), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is PCImg && w.name == 'cs_replece_icon'),
      findsNothing,
    );
    for (final (index, asset) in [
      (2, 'pc_act_2'),
      (1, 'pc_act_1'),
      (3, 'pc_act_3'),
      (0, 'pc_act_0'),
    ]) {
      await tap(tester, 'pcCashChangePayment');
      expect(find.byType(PCProcessAccountDialog), findsNothing);
      expect(PCLocalProvider.instance.pc_account_seled_index, 0);
      expect(prefs.getInt('pc_account_seled_index'), 0);
      expect(prefs.getInt(PCCash.viewPaymentKey), index);
      expect(prefs.getString('pc_account_id'), account);
      final background = find.byKey(const ValueKey('pcCashPaymentBackground'));
      expect(tester.getSize(background), buttonSize);
      backgrounds.add(
        (tester.widget<DecoratedBox>(background).decoration as BoxDecoration)
            .color!,
      );
      final pageBackground = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('pcCashPageBackground')),
      );
      pageBackgrounds.add(
        ((pageBackground.decoration as BoxDecoration).gradient
                as LinearGradient)
            .colors
            .first,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pcCashPayment')),
          matching: find.byWidgetPredicate(
            (w) => w is PCImg && w.name == asset,
          ),
        ),
        findsOneWidget,
      );
    }
    expect(backgrounds.length, 4);
    expect(pageBackgrounds.length, 4);
    await tap(tester, 'pcCashPayment');
    expect(find.byType(PCProcessAccountDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(PCProcessAccountDialog))).pop();
    await advance(tester);
    expect(tester.takeException(), isNull);
    await clean(tester, controller);
  });

  testWidgets('四个绑定渠道的六状态仅在所属渠道展示，切走显示全部档位且切回恢复', (tester) async {
    const order = [0, 2, 1, 3];
    for (final bound in order) {
      for (final stage in PCWithdrawalStage.values) {
        var ads = 0;
        final controller = await create(
          stage,
          boundPayment: bound,
          task: 'video',
          ad: (_) async {
            ads++;
            return true;
          },
        );
        await mount(tester, controller);
        final prefs = await SharedPreferences.getInstance();
        final beforeRank = controller.queueRank;
        final beforeTotal = controller.queueTotal;
        final beforeTask = controller.taskProgress;
        final beforeBalance = controller.balance;
        final beforeDiamonds = controller.diamonds;
        final beforeGold = controller.gold;
        final beforePending = controller.pending.map((p) => p.id).toList();

        void expectOwnState() {
          expect(
            find.byType(PCCashWithdrawalContent),
            stage == PCWithdrawalStage.insufficient
                ? findsNothing
                : findsOneWidget,
            reason: '绑定$bound的$stage必须保留本人状态',
          );
          expect(
            find.byKey(const ValueKey('pcCashPayout_100')),
            stage == PCWithdrawalStage.insufficient
                ? findsOneWidget
                : findsNothing,
          );
        }

        expectOwnState();
        for (var step = 1; step <= 4; step++) {
          await tap(tester, 'pcCashChangePayment');
          final viewed = order[(order.indexOf(bound) + step) % 4];
          expect(prefs.getInt(PCCash.viewPaymentKey), viewed);
          expect(prefs.getInt('pc_account_seled_index'), bound);
          expect(PCLocalProvider.instance.pc_account_seled_index, bound);
          expect(prefs.getString('pc_account_id'), 'p***.com');
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('pcCashPayment')),
              matching: find.byWidgetPredicate(
                (w) => w is PCImg && w.name == 'pc_act_$viewed',
              ),
            ),
            findsOneWidget,
          );
          if (viewed == bound) {
            expectOwnState();
          } else {
            expect(find.byType(PCCashWithdrawalContent), findsNothing);
            for (final amount in [100, 120, 150, 200]) {
              expect(
                find.byKey(ValueKey('pcCashPayout_$amount')),
                findsOneWidget,
              );
            }
            expect(find.text('Reviewing'), findsNothing);
            expect(find.text('Approved'), findsNothing);
            expect(find.text('Releasing'), findsNothing);
            expect(find.text('In Queue'), findsNothing);
            expect(find.text('Unlock Payout'), findsNothing);
          }
        }
        expect(ads, 0);
        expect(controller.queueRank, beforeRank);
        expect(controller.queueTotal, beforeTotal);
        expect(controller.taskProgress, beforeTask);
        expect(controller.balance, beforeBalance);
        expect(controller.diamonds, beforeDiamonds);
        expect(controller.gold, beforeGold);
        expect(controller.pending.map((p) => p.id), beforePending);
        expect(tester.takeException(), isNull);
        await clean(tester, controller);
      }
    }
  });

  testWidgets('非绑定渠道足额提现不拉原渠道任务，不足额仍提示当前档位且不请求广告', (tester) async {
    for (final stage in [PCWithdrawalStage.queue, PCWithdrawalStage.lastStep]) {
      var ads = 0;
      final controller = await create(
        stage,
        boundPayment: 2,
        viewedPayment: 1,
        task: 'video',
        ad: (_) async {
          ads++;
          return true;
        },
      );
      for (final pending in controller.pending.toList()) {
        await controller.dismiss(pending);
      }
      await mount(tester, controller);
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['pcCashCurrentPrompt', 'pcCashWithdraw_100']) {
        await tap(tester, key);
        expect(controller.hasPending, isFalse);
        expect(controller.queueRank, stage == PCWithdrawalStage.queue ? 5 : 1);
        expect(controller.taskProgress, 3);
        expect(ads, 0);
        await advance(tester, 2400);
      }
      for (final amount in [120, 150, 200]) {
        await tap(tester, 'pcCashWithdraw_$amount');
        expect(controller.next?.kind, PCWithdrawalPromptKind.insufficient);
        expect(controller.next?.withdrawalTarget, amount);
        await controller.dismiss(controller.next!);
      }
      expect(find.byType(PCCashWithdrawalContent), findsNothing);
      expect(prefs.getInt('pc_account_seled_index'), 2);
      expect(prefs.getInt(PCCash.viewPaymentKey), 1);
      expect(prefs.getString('pc_account_id'), 'p***.com');
      expect(ads, 0);
      expect(controller.taskProgress, 3);
      expect(controller.queueTotal, 20);
      expect(tester.takeException(), isNull);
      await clean(tester, controller);
    }
  });

  testWidgets('切换前旧任务回调不能在其它渠道请求广告或推进任务', (tester) async {
    for (final stage in [PCWithdrawalStage.queue, PCWithdrawalStage.lastStep]) {
      var ads = 0;
      final controller = await create(
        stage,
        task: 'video',
        ad: (_) async {
          ads++;
          return true;
        },
      );
      await mount(tester, controller);
      final oldContent = tester.widget<PCCashWithdrawalContent>(
        find.byType(PCCashWithdrawalContent),
      );
      final before = controller.pending.map((p) => p.id).toList();
      await tap(tester, 'pcCashChangePayment');
      expect(find.byType(PCCashWithdrawalContent), findsNothing);
      oldContent.onQueue();
      await advance(tester);
      oldContent.onTask();
      await advance(tester);
      expect(ads, 0);
      expect(controller.queueRank, stage == PCWithdrawalStage.queue ? 5 : 1);
      expect(controller.queueTotal, 20);
      expect(controller.taskProgress, 3);
      expect(controller.pending.map((p) => p.id), before);
      expect(PCDialogCoordinator.instance.holdCount, 0);
      expect(tester.takeException(), isNull);
      await clean(tester, controller);
    }
  });

  testWidgets('真实提交账号渠道变化后跟随新绑定，不沿用旧浏览缓存隐藏任务', (tester) async {
    final controller = await create(
      PCWithdrawalStage.reviewing,
      boundPayment: 2,
      viewedPayment: 3,
    );
    await mount(tester, controller);
    expect(find.byType(PCCashWithdrawalContent), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_account_seled_index', 1);
    await prefs.setString('pc_account_id', 'n***.com');
    await PCLocalProvider.instance.init();
    await advance(tester);
    expect(prefs.getInt(PCCash.viewPaymentKey), 1);
    expect(find.byKey(const ValueKey('pcCashStage_reviewing')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pcCashPayment')),
        matching: find.byWidgetPredicate(
          (w) => w is PCImg && w.name == 'pc_act_1',
        ),
      ),
      findsOneWidget,
    );
    expect(controller.diamonds, 5);
    expect(tester.takeException(), isNull);
    await clean(tester, controller);
  });

  testWidgets('无已提交账号时不展示提现任务，切换渠道也不把默认渠道当作绑定', (tester) async {
    final controller = await create(
      PCWithdrawalStage.queue,
      boundPayment: 0,
      account: '',
    );
    await mount(tester, controller);
    for (var i = 0; i < 4; i++) {
      expect(find.byType(PCCashWithdrawalContent), findsNothing);
      for (final amount in [100, 120, 150, 200]) {
        expect(find.byKey(ValueKey('pcCashPayout_$amount')), findsOneWidget);
      }
      await tap(tester, 'pcCashChangePayment');
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pc_account_id'), isEmpty);
    expect(prefs.getInt('pc_account_seled_index'), 0);
    expect(controller.queueRank, 5);
    expect(tester.takeException(), isNull);
    await clean(tester, controller);
  });

  testWidgets('冷重建保留浏览渠道，编辑仍是绑定账号，切回原渠道恢复任务', (tester) async {
    final controller = await create(
      PCWithdrawalStage.lastStep,
      boundPayment: 2,
      viewedPayment: 3,
      task: 'video',
    );
    await mount(tester, controller);
    expect(find.byType(PCCashWithdrawalContent), findsNothing);
    await tap(tester, 'pcCashPayment');
    final form = tester.widget<PCProcessAccountDialog>(
      find.byType(PCProcessAccountDialog),
    );
    expect(form.hasSavedAccount, isTrue);
    expect(form.initialPaymentIndex, 2);
    expect(form.initialAccount, 'p***.com');
    Navigator.of(tester.element(find.byType(PCProcessAccountDialog))).pop();
    await advance(tester);
    await clean(tester, controller);

    final cold = PCWithdrawalController(
      now: () => clock,
      requestAd: (_) async => false,
      scheduleMidnightTimer: false,
    );
    await cold.load();
    await PCLocalProvider.instance.init();
    await mount(tester, cold);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(PCCash.viewPaymentKey), 3);
    expect(prefs.getInt('pc_account_seled_index'), 2);
    expect(find.byType(PCCashWithdrawalContent), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pcCashPayment')),
        matching: find.byWidgetPredicate(
          (w) => w is PCImg && w.name == 'pc_act_3',
        ),
      ),
      findsOneWidget,
    );
    await tap(tester, 'pcCashChangePayment'); // PagBank -> PayPal
    await tap(tester, 'pcCashChangePayment'); // PayPal -> Cash App
    expect(prefs.getInt(PCCash.viewPaymentKey), 2);
    expect(find.byKey(const ValueKey('pcCashStage_lastStep')), findsOneWidget);
    expect(find.text('3/10'), findsNWidgets(2));
    expect(cold.taskProgress, 3);
    expect(tester.takeException(), isNull);
    await clean(tester, cold);
  });

  for (final stage in [
    PCWithdrawalStage.reviewing,
    PCWithdrawalStage.releasing,
  ]) {
    testWidgets('$stage收集按钮去答题且不修改收集数量', (tester) async {
      final controller = await create(stage);
      var quiz = 0;
      await mount(tester, controller, quiz: () => quiz++);
      final diamonds = controller.diamonds, gold = controller.gold;
      await tap(
        tester,
        stage == PCWithdrawalStage.reviewing
            ? 'pcCashCollectDiamonds'
            : 'pcCashCollectGold',
      );
      expect(quiz, 1);
      expect(controller.diamonds, diamonds);
      expect(controller.gold, gold);
      if (stage == PCWithdrawalStage.reviewing) {
        expect(
          controller.pending.where(
            (prompt) => prompt.kind == PCWithdrawalPromptKind.diamondCollect,
          ),
          isEmpty,
          reason: '收集按钮已去答题，不能再补弹刚才的收集提示',
        );
      }
      await clean(tester, controller);
    });
  }

  testWidgets('钻石未满20跨天保持收集，达标即时显示当晚倒计时且午夜切换金猪状态', (tester) async {
    final controller = await create(PCWithdrawalStage.reviewing);
    await mount(tester, controller);
    expect(find.text('5/20'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('pcCashCountdownPanel')), findsNothing);

    // 旧档的入钻日截止时间已过，未满20仍留在钻石收集状态。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2030, 1, 3, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await advance(tester);
    expect(controller.stage, PCWithdrawalStage.reviewing);
    expect(controller.diamondDeadline, isNull);
    expect(find.byKey(const ValueKey('pcCashCollectDiamonds')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcCashCountdownPanel')), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_diamonds', 19.99);
    await controller.refresh();
    await advance(tester);
    expect(find.text('19.99/20'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('pcCashCountdownPanel')), findsNothing);

    // 本次达标日期决定00:00截止时间，不能沿用两天前的旧日期。
    await prefs.setDouble('pc_quiz_diamonds', 20);
    await controller.refresh();
    await advance(tester);
    expect(controller.stage, PCWithdrawalStage.reviewApproved);
    expect(controller.diamondDeadline, DateTime(2030, 1, 4));
    expect(find.byKey(const ValueKey('pcCashCollectDiamonds')), findsNothing);
    expect(find.byKey(const ValueKey('pcCashRemindTomorrow')), findsOneWidget);
    expect(
      tester
          .widget<PCGradientStrokeText>(
            find.byKey(const ValueKey('pcCashCountdownNumber')),
          )
          .text,
      '15:00:00',
    );
    expect(controller.balance, 100);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2030, 1, 4);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await advance(tester);
    expect(controller.stage, PCWithdrawalStage.releasing);
    expect(find.byKey(const ValueKey('pcCashStage_releasing')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcCashCountdownPanel')), findsNothing);
    expect(controller.diamonds, 20);
    expect(controller.balance, 100);
    expect(tester.takeException(), isNull);
    await clean(tester, controller);
  });

  testWidgets('提醒仅点击才申请，已授权不重复申请，倒计时逐秒更新且跨午夜前台恢复', (tester) async {
    final controller = await create(PCWithdrawalStage.reviewApproved);
    var requested = 0;
    var enabled = false;
    await mount(
      tester,
      controller,
      permission: () async => enabled,
      requestPermission: () async {
        requested++;
        enabled = true;
        return true;
      },
    );
    expect(requested, 0);
    await tap(tester, 'pcCashRemindTomorrow');
    expect(requested, 1);
    expect(find.text('Open Tomorrow'), findsOneWidget);
    await tap(tester, 'pcCashRemindTomorrow');
    expect(requested, 1);
    expect(controller.next?.kind, PCWithdrawalPromptKind.diamondCountdown);
    await controller.dismiss(controller.next!);
    clock = clock.add(const Duration(seconds: 1));
    await advance(tester, 1000);
    expect(
      tester
          .widget<PCGradientStrokeText>(
            find.byKey(const ValueKey('pcCashCountdownNumber')),
          )
          .text,
      '11:59:59',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2030, 1, 2, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await advance(tester);
    expect(controller.stage, PCWithdrawalStage.releasing);
    expect(find.byKey(const ValueKey('pcCashStage_releasing')), findsOneWidget);
    await clean(tester, controller);
  });

  testWidgets('排队广告在途连点只请求一次，失败不变，成功按配置前进并保留稳定展示行', (tester) async {
    var ad = Completer<bool>();
    var requests = 0;
    var throwsAd = false;
    final dialogs = PCDialogCoordinator.instance;
    final controller = await create(
      PCWithdrawalStage.queue,
      ad: (_) {
        requests++;
        if (throwsAd) throw StateError('SDK unavailable');
        return ad.future;
      },
    );
    await mount(tester, controller);
    final queueTable = find.byType(PCWithdrawalQueueTable);
    expect(tester.widget<PCWithdrawalQueueTable>(queueTable).currentRank, 5);
    expect(tester.widget<PCWithdrawalQueueTable>(queueTable).queueCount, 20);
    expect(
      tester.widget<PCWithdrawalQueueTable>(queueTable).entries,
      hasLength(20),
    );
    await tester.ensureVisible(queueTable);
    await tester.pump();
    final queueViewport = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalQueueList')),
    );
    final currentRow = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow')),
    );
    expect(currentRow.top, greaterThanOrEqualTo(queueViewport.top - .01));
    expect(currentRow.bottom, lessThanOrEqualTo(queueViewport.bottom + .01));
    final before = pcCashQueueEntries(
      seed: controller.queueSeed,
      target: controller.target,
    ).map((r) => r.account).toList();
    await tap(tester, 'pcCashSkipQueue');
    await repeatDisabled(tester, 'pcCashSkipQueue');
    expect(requests, 1);
    expect(dialogs.holdCount, 1, reason: '请求SDK之前即持有全局展示权');
    ad.complete(false);
    await advance(tester);
    expect(controller.queueRank, 5);
    expect(controller.queueTotal, 20);
    expect(dialogs.holdCount, 0, reason: '广告失败立即释放展示权');
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    await tester.tap(find.byType(PCGreenDialogButton));
    await advance(tester);
    expect(requests, 1, reason: '失败提示按钮只关闭');
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    ad = Completer<bool>();
    await tap(tester, 'pcCashSkipQueue');
    expect(requests, 2);
    ad.complete(true);
    await tester.pump();
    await tester.pump();
    expect(controller.queueRank, 3);
    expect(controller.queueTotal, 19);
    expect(tester.widget<PCWithdrawalQueueTable>(queueTable).currentRank, 3);
    expect(tester.widget<PCWithdrawalQueueTable>(queueTable).queueCount, 19);
    expect(
      tester.widget<PCWithdrawalQueueTable>(queueTable).entries,
      hasLength(19),
    );
    expect(
      tester
          .widget<PCWithdrawalRankToast>(find.byType(PCWithdrawalRankToast))
          .rank,
      3,
    );
    expect(dialogs.holdCount, 1);
    await repeatDisabled(tester, 'pcCashSkipQueue');
    expect(requests, 2, reason: '排名反馈期间不能再次请求广告');
    var nextShown = false;
    final next = dialogs.enqueue<int>(
      key: Object(),
      present: () async {
        nextShown = true;
        return 1;
      },
    );
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(PCWithdrawalRankToast), findsOneWidget);
    expect(nextShown, isFalse);
    expect(dialogs.holdCount, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    expect(await next, 1);
    expect(dialogs.holdCount, 0);
    final updatedViewport = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalQueueList')),
    );
    final updatedRow = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow')),
    );
    expect(updatedRow.top, greaterThanOrEqualTo(updatedViewport.top - .01));
    expect(updatedRow.bottom, lessThanOrEqualTo(updatedViewport.bottom + .01));
    expect(
      pcCashQueueEntries(
        seed: controller.queueSeed,
        target: controller.target,
      ).map((r) => r.account),
      before,
    );

    throwsAd = true;
    await tap(tester, 'pcCashSkipQueue');
    expect(requests, 3);
    expect(controller.queueRank, 3);
    expect(dialogs.holdCount, 0, reason: 'SDK抛异常也不能锁住后续弹窗');
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    await tester.tap(find.byType(PCGreenDialogButton));
    await advance(tester);
    expect(requests, 3, reason: 'SDK异常提示关闭不会自动重试');
    throwsAd = false;
    ad = Completer<bool>();
    await tap(tester, 'pcCashSkipQueue');
    ad.complete(true);
    await tester.pump();
    await tester.pump();
    expect(controller.stage, PCWithdrawalStage.lastStep);
    expect(controller.next?.kind, PCWithdrawalPromptKind.lastStep);
    expect(
      tester
          .widget<PCWithdrawalRankToast>(find.byType(PCWithdrawalRankToast))
          .rank,
      1,
    );
    expect(dialogs.holdCount, 1, reason: '排名达到1后也必须先完整展示反馈再交给任务提示');
    await repeatDisabled(tester, 'pcCashTaskGo');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(PCWithdrawalRankToast), findsOneWidget);
    expect(dialogs.holdCount, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    expect(dialogs.isBusy, isFalse);
    await clean(tester, controller);

    final lateAd = Completer<bool>();
    final removed = await create(
      PCWithdrawalStage.queue,
      ad: (_) => lateAd.future,
    );
    await mount(tester, removed);
    await tap(tester, 'pcCashSkipQueue');
    expect(dialogs.holdCount, 1);
    await tester.pumpWidget(const SizedBox());
    await advance(tester);
    expect(dialogs.holdCount, 0, reason: '页面销毁时即使SDK仍在途也必须释放');
    lateAd.complete(true);
    await advance(tester);
    expect(find.byType(PCWithdrawalRankToast), findsNothing);
    expect(dialogs.isBusy, isFalse);
    removed.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final task in ['quiz', 'spin']) {
    testWidgets('最后一步$task的GO清除同一步待提示再导航，不伪造完成次数', (tester) async {
      final controller = await create(PCWithdrawalStage.lastStep, task: task);
      var quiz = 0, wheel = 0;
      await mount(tester, controller, quiz: () => quiz++, wheel: () => wheel++);
      final description = tester.widget<PCStrokeText>(
        find.byKey(const ValueKey('pcCashTaskDescription')),
      );
      expect(
        description.text,
        task == 'quiz' ? 'Answer 3/10 Question Right' : 'Spin 3/10 Times',
      );
      expect(description.color, const Color(0xFFFFDD1D));
      expect(description.skWidth, greaterThan(0));
      expect(controller.hasPending, isTrue);
      await tap(tester, 'pcCashTaskGo');
      expect(quiz, task == 'quiz' ? 1 : 0);
      expect(wheel, task == 'spin' ? 1 : 0);
      expect(controller.hasPending, isFalse);
      expect(controller.taskProgress, 3);
      await clean(tester, controller);
    });
  }

  testWidgets('最后一步video只真实广告成功计一次，失败与连点不能补次数', (tester) async {
    var ad = Completer<bool>();
    var requests = 0;
    final controller = await create(
      PCWithdrawalStage.lastStep,
      task: 'video',
      ad: (_) {
        requests++;
        return ad.future;
      },
    );
    await mount(tester, controller);
    expect(find.text('Watch 3/10 Videos'), findsNWidgets(2));
    expect(find.text('GO'), findsOneWidget);
    await tap(tester, 'pcCashTaskGo');
    await repeatDisabled(tester, 'pcCashTaskGo');
    expect(requests, 1);
    ad.complete(false);
    await advance(tester);
    expect(controller.taskProgress, 3);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    await tester.tap(find.byType(PCGreenDialogButton));
    await advance(tester);
    expect(requests, 1, reason: '失败提示按钮只关闭');
    expect(controller.taskProgress, 3);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    ad = Completer<bool>();
    await tap(tester, 'pcCashTaskGo');
    ad.complete(true);
    await advance(tester);
    expect(requests, 2);
    expect(controller.taskProgress, 4);
    expect(find.text('Watch 4/10 Videos'), findsNWidgets(2));
    expect(find.text('4/10'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await clean(tester, controller);
  });
}
