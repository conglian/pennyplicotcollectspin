import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCCash/PCGoldPigUpgradeDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCOtherDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalDialogs.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCCash.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCAdOutcome.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalFlowHost.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  late DateTime clock;
  setUp(() {
    clock = DateTime.now();
  });
  Future<PCWithdrawalController> seed({
    bool diamond = false,
    bool video = false,
    int queueRank = 1,
    Future<PCAdOutcome> Function(String)? adOutcome,
    Future<void> Function()? onSync,
  }) async {
    SharedPreferences.setMockInitialValues({
      'pc_new_guide_end': true,
      'pc_account_id': 'a***@mail.com',
      'pc_pig_level': diamond ? 1 : 2,
      'pc_pig_upgrade_seen_level_v1': diamond ? 0 : 2,
      'pc_dollar_number': 100.0,
      'pc_quiz_diamonds': 3.5,
      'pc_quiz_gold': diamond ? 0.0 : 10.0,
      'pc_wheel_number': 2,
      'pc_quiz_all_num': 1,
      PCNumberHelpers.configKey: jsonEncode({
        'queue_number': [
          {
            'int_all': 20,
            'int_current': queueRank,
            'int_all_delete': [2, 2],
            'int_current_delete': [5, 5],
          },
        ],
        'tixian_task': video
            ? [
                {'title': 'video', 'data': 2},
                {'title': 'quiz', 'data': 1},
              ]
            : [
                {'title': 'quiz', 'data': 2},
                {'title': 'spin', 'data': 2},
                {'title': 'video', 'data': 1},
              ],
      }),
    });
    final flow = PCWithdrawalController(
      now: () => clock,
      scheduleMidnightTimer: false,
      requestAd: (_) async => true,
      requestAdOutcome: adOutcome,
      onSync: onSync,
    );
    await flow.load();
    return flow;
  }

  Future<void> frames(WidgetTester tester, [int n = 5]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> host(
    WidgetTester tester,
    PCWithdrawalController flow, {
    bool Function()? canPresent,
    Widget? child,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: PCWithdrawalFlowHost(
              controller: flow,
              canPresent: canPresent ?? () => true,
              notificationsEnabled: () async => false,
              requestNotifications: () async => false,
              onGoQuiz: () {},
              onGoWheel: () {},
              child:
                  child ??
                  const ColoredBox(
                    color: Colors.green,
                    child: SizedBox.expand(),
                  ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
  }

  Future<void> teardownHost(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
  }

  for (final video in [false, true]) {
    for (final outcome in [PCAdOutcome.cancelled, PCAdOutcome.failed]) {
      testWidgets('Host${video ? '视频任务' : '排队'}$outcome仅真实广告失败显示失败面板', (
        tester,
      ) async {
        var requests = 0;
        final flow = await seed(
          video: video,
          queueRank: video ? 1 : 9,
          adOutcome: (_) async {
            requests++;
            return outcome;
          },
        );
        addTearDown(flow.dispose);
        await host(tester, flow);
        final action = find.byKey(
          ValueKey(video ? 'pcWithdrawalTaskAction' : 'pcWithdrawalSkipWait'),
        );
        await tester.tap(action);
        await frames(tester);
        expect(requests, 1);
        expect(flow.taskProgress, 0);
        expect(flow.queueRank, video ? 1 : 9);
        expect(
          find.byType(PCAdLoadingFailedDialog),
          outcome == PCAdOutcome.failed ? findsOneWidget : findsNothing,
        );
        if (outcome == PCAdOutcome.failed) {
          await tester.tap(find.byType(PCGreenDialogButton));
          await frames(tester);
          expect(requests, 1, reason: 'Try Again不能重放广告或重新请求');
        } else {
          expect(action, findsOneWidget);
          await tester.tap(action);
          await frames(tester);
          expect(requests, 2);
        }
        expect(tester.takeException(), isNull);
        await teardownHost(tester);
      });
    }

    testWidgets('Host${video ? '视频任务' : '排队'}广告成功后同步异常显示保存提示不显示广告失败', (
      tester,
    ) async {
      final flow = await seed(
        video: video,
        queueRank: video ? 1 : 9,
        adOutcome: (_) async => PCAdOutcome.success,
        onSync: () async => throw StateError('provider unavailable'),
      );
      addTearDown(flow.dispose);
      await host(tester, flow);
      await tester.tap(
        find.byKey(
          ValueKey(video ? 'pcWithdrawalTaskAction' : 'pcWithdrawalSkipWait'),
        ),
      );
      await frames(tester);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(
        find.text('Unable to save progress. Please try again.'),
        findsOneWidget,
      );
      expect(video ? flow.taskProgress == 1 : flow.queueRank == 4, isTrue);
      expect(flow.isBusy, isFalse);
      await frames(tester, 30);
      expect(tester.takeException(), isNull);
      await teardownHost(tester);
    });
  }

  testWidgets('排队成功保留弹窗，只有到第一名才自动退场并显示提现任务', (tester) async {
    final flow = await seed(queueRank: 9);
    addTearDown(flow.dispose);
    await host(tester, flow);
    final action = find.byKey(const ValueKey('pcWithdrawalSkipWait'));
    await tester.tap(action);
    await frames(tester, 25);
    expect(flow.queueRank, 4);
    expect(find.byType(PCWithdrawalApprovalDialog), findsOneWidget);
    expect(find.byType(PCWithdrawalLastStepDialog), findsNothing);
    await tester.tap(action);
    await frames(tester);
    expect(flow.queueRank, 1);
    expect(flow.stage, PCWithdrawalStage.lastStep);
    expect(find.byType(PCWithdrawalApprovalDialog), findsOneWidget);
    expect(find.byType(PCWithdrawalLastStepDialog), findsNothing);
    await frames(tester, 25);
    expect(find.byType(PCWithdrawalApprovalDialog), findsNothing);
    expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardownHost(tester);
  });

  testWidgets('提现页排到第一名立即更新任务状态，排名反馈结束后主动显示任务框', (tester) async {
    final flow = await seed(queueRank: 4);
    addTearDown(flow.dispose);
    await flow.dismiss(flow.next!);
    await PCLocalProvider.instance.init();
    await host(
      tester,
      flow,
      child: PCCash(controller: flow, isNotificationEnabled: () async => false),
    );
    expect(find.byKey(const ValueKey('pcCashStage_queue')), findsOneWidget);
    final action = find.byKey(const ValueKey('pcCashSkipQueue'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await frames(tester);
    expect(flow.queueRank, 1);
    expect(find.byKey(const ValueKey('pcCashStage_queue')), findsNothing);
    expect(find.byKey(const ValueKey('pcCashStage_lastStep')), findsOneWidget);
    expect(find.byType(PCWithdrawalLastStepDialog), findsNothing);
    await frames(tester, 25);
    expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardownHost(tester);
  });

  test('金砖满10后答题与转盘继续计真实任务，继续获得金砖且不重置提现进度，任务循环', () async {
    final flow = await seed();
    final quiz = PCQuizController(onSync: flow.refresh);
    final wheel = PCWheelController(
      onWithdrawalSpin: (id) async {
        await flow.recordEvent(PCWithdrawalEventKind.spin, eventId: id);
      },
    );
    addTearDown(flow.dispose);
    addTearDown(quiz.dispose);
    addTearDown(wheel.dispose);
    expect(flow.currentTask.title, 'quiz');
    await flow.dismiss(flow.next!);
    await quiz.load();
    expect(quiz.isComplete, false);
    expect(await quiz.answer(correct: false, expectedQuestionIndex: 0), isNull);
    expect(flow.taskProgress, 0);
    final reward = await quiz.answer(correct: true, expectedQuestionIndex: 1);
    expect(reward!.amount, inInclusiveRange(.01, .02));
    expect(quiz.pendingReward, isNotNull);
    await quiz.claim();
    expect(flow.taskProgress, 1);
    expect(quiz.gold, greaterThan(10));
    expect(quiz.correctCount, 2);
    expect(quiz.spins, 3);
    final second = await quiz.answer(correct: true, expectedQuestionIndex: 2);
    expect(second, isNotNull);
    await quiz.claim();
    expect(quiz.correctCount, 3);
    expect(flow.currentTask.title, 'spin');
    expect(flow.taskProgress, 0);
    await flow.dismiss(flow.next!);
    expect(await wheel.start(), PCWheelStartResult.started);
    final id = wheel.pending!.reward.id;
    expect(wheel.pending!.reward.amount, inInclusiveRange(.01, .02));
    expect(flow.taskProgress, 1);
    await flow.recordEvent(PCWithdrawalEventKind.spin, eventId: id);
    expect(flow.taskProgress, 1);
    expect(await wheel.start(), PCWheelStartResult.pending);
    await wheel.claim();
    expect(await wheel.start(), PCWheelStartResult.started);
    expect(flow.currentTask.title, 'video');
    await wheel.claim();
    expect(await flow.recordVideoWithAd(), true);
    expect(flow.currentTask.title, 'quiz');
    expect(flow.taskCycle, 1);
    expect(flow.taskProgress, 0);
    expect(flow.balance, 100);
    expect(flow.gold, greaterThan(10));
  });

  testWidgets('礼盒到账后未满20不倒计时，收满20才显示倒计时并午夜金猪', (tester) async {
    final flow = await seed(diamond: true);
    addTearDown(flow.dispose);
    while (flow.next!.kind != PCWithdrawalPromptKind.giftReward) {
      await flow.acknowledge(flow.next!);
    }
    await host(tester, flow);
    expect(find.byType(PCWithdrawalGiftRewardDialog), findsOneWidget);
    final dialog = tester.widget<PCWithdrawalGiftRewardDialog>(
      find.byType(PCWithdrawalGiftRewardDialog),
    );
    final giftAmount = flow.diamondGiftAmount;
    expect(dialog.diamondAmount, giftAmount);
    expect(giftAmount, inInclusiveRange(1, 1.5));
    expect(
      find.byKey(const ValueKey('pcWithdrawalGiftRewardClose')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('pcWithdrawalGiftClaim')));
    await frames(tester, 10);
    expect(flow.diamonds, 3.5 + giftAmount);
    expect(flow.giftClaimed, true);
    expect(find.byType(PCWithdrawalGiftRewardDialog), findsNothing);
    expect(find.byType(PCWithdrawalDiamondCountdownDialog), findsNothing);
    expect(flow.diamondDeadline, isNull);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_diamonds', 20);
    await flow.refresh();
    await frames(tester, 10);
    expect(find.byType(PCWithdrawalDiamondCountdownDialog), findsOneWidget);
    clock = flow.diamondDeadline!;
    await flow.refresh();
    await frames(tester, 10);
    expect(find.byType(PCWithdrawalDiamondCountdownDialog), findsNothing);
    expect(find.byType(PCGoldPigUpgradeDialog), findsOneWidget);
    expect(flow.pigLevel, 2);
    expect(flow.diamonds, 20);
    expect(tester.takeException(), isNull);
    await teardownHost(tester);
  });

  testWidgets('暂不能展示时不消费节点，任务关闭本次不重复弹，冷启动恢复', (tester) async {
    final flow = await seed();
    addTearDown(flow.dispose);
    var ready = false;
    await host(tester, flow, canPresent: () => ready);
    expect(find.byType(PCWithdrawalLastStepDialog), findsNothing);
    expect(flow.hasPending, true);
    ready = true;
    await flow.requestCurrentPrompt();
    await frames(tester);
    expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
    // 返回手势与关闭按钮同样仅收起当前会话。
    final context = tester.element(find.byType(PCWithdrawalLastStepDialog));
    Navigator.of(context).pop(false);
    await frames(tester, 20);
    expect(find.byType(PCWithdrawalLastStepDialog), findsNothing);
    expect(flow.hasPending, false);
    expect(tester.takeException(), isNull);
    await teardownHost(tester);
    final cold = PCWithdrawalController(
      now: () => clock,
      scheduleMidnightTimer: false,
    );
    addTearDown(cold.dispose);
    await cold.load();
    expect(cold.next!.kind, PCWithdrawalPromptKind.lastStep);
    await host(tester, cold);
    expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
    await teardownHost(tester);
  });
  testWidgets('视频成功未满继续当前任务，满额自动展示下一个任务且不会重复计数', (tester) async {
    final flow = await seed(video: true);
    addTearDown(flow.dispose);
    await host(tester, flow);
    final action = find.byKey(const ValueKey('pcWithdrawalTaskAction'));
    expect(find.text('Watch 0/2 Videos'), findsOneWidget);
    await tester.tap(action);
    await frames(tester);
    expect(flow.taskProgress, 1);
    expect(find.text('Watch 1/2 Videos'), findsOneWidget);
    expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
    await tester.tap(action);
    await frames(tester, 10);
    expect(flow.currentTask.title, 'quiz');
    expect(flow.taskProgress, 0);
    expect(find.text('Answer 0/1 Question Right'), findsOneWidget);
    expect(find.byType(PCWithdrawalLastStepDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await teardownHost(tester);
  });
}
