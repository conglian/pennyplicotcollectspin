import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCCheckInDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelOpportunityStore.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_ad_manger.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final manager = PCPigAds();
  final originalEvent = manager.reportEvent;
  final originalRevenue = manager.reportRevenue;
  final events = <String>[];
  var revenueReports = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_new_guide_end': true,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_dollar_number': 10.0,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      PCWheelOpportunityStore.storageKey: jsonEncode({
        'balance': 2,
        'lastGrantDay': PCWheelOpportunityStore.dayKey(DateTime.now()),
        'quizAwardThrough': 0,
        'wheelAppliedId': '',
      }),
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 100},
        ],
      }),
    });
    await PCLocalProvider.instance.init();
    await PCNumberHelpers().pc_initNumberModel();
    events.clear();
    revenueReports = 0;
    manager.reportEvent = (name, _) => events.add(name);
    manager.reportRevenue = (_) => revenueReports++;
    manager.skipAdForTesting = true;
    // 使用应用初始化实际注册的 handler，不将服务替换为直接返回 true 的假实现。
    await manager.init(readySources: <String>{});
    expect(PCRewardedAdService.instance.handler, isNotNull);
  });

  tearDown(() {
    expect(manager.isAdBusy, isFalse);
    expect(revenueReports, 0, reason: '调试跳过可以结算业务奖励，但不能上报虚构广告收益');
    expect(
      events.where((event) => event == 'ad_impression'),
      isEmpty,
    );
    expect(PCLocalProvider.instance.pc_ad_show_number, 0);
    manager.stopForTesting();
    manager.skipAdForTesting = null;
    manager.reportEvent = originalEvent;
    manager.reportRevenue = originalRevenue;
  });

  Future<void> frames(WidgetTester tester, [int duration = 600]) async {
    for (var elapsed = 0; elapsed < duration; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
  }

  Future<BuildContext> host(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext context;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
    });
    return context;
  }

  for (final source in ['答题', '转盘']) {
    testWidgets('跳过广告：$source实际Claim成功并且仅到账一次，不误走放弃待奖', (tester) async {
      final context = await host(tester);
      final quiz = PCQuizController(random: Random(7));
      final wheel = PCWheelController(random: Random(7));
      addTearDown(quiz.dispose);
      addTearDown(wheel.dispose);
      final fromQuiz = source == '答题';
      if (fromQuiz) {
        await quiz.load();
        await quiz.answer(correct: true, expectedQuestionIndex: 0);
      } else {
        expect(await wheel.start(), PCWheelStartResult.started);
      }
      final reward = fromQuiz ? quiz.pendingReward! : wheel.pending!.reward;
      var claims = 0;
      var abandoned = 0;
      final result = context.tipShow2(
        PCAwardDialog(
          award: reward.amount,
          reward: reward,
          balance: 10,
          onClaim: () async {
            claims++;
            return (fromQuiz
                    ? await quiz.claim(expectedRewardId: reward.id)
                    : await wheel.claim(expectedRewardId: reward.id)) !=
                null;
          },
          onAbandon: () async {
            abandoned++;
            if (fromQuiz) {
              await quiz.discardPendingReward(expectedRewardId: reward.id);
            } else {
              await wheel.discardPending(expectedRewardId: reward.id);
            }
          },
        ),
      );
      await frames(tester);
      final claim = find.byKey(const ValueKey('pcQuizClaimReward'));
      await tester.tap(claim);
      await tester.tap(claim, warnIfMissed: false);
      await frames(tester);
      expect(await result, isTrue);
      expect(claims, 1);
      expect(abandoned, 0);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getDouble('pc_dollar_number'),
        closeTo(10 + reward.amount, .000001),
      );
      if (fromQuiz) {
        expect(quiz.pendingReward, isNull);
        expect(await quiz.claim(expectedRewardId: reward.id), isNull);
      } else {
        expect(wheel.pending, isNull);
        expect(wheel.spins, 1, reason: '正常领取仍保留本次转动的扣次');
        expect(await wheel.claim(expectedRewardId: reward.id), isNull);
      }
      expect(
        preferences.getDouble('pc_dollar_number'),
        closeTo(10 + reward.amount, .000001),
      );
    });
  }

  testWidgets('跳过广告：普通签到真实按钮成功到账且当日只记一次签到', (tester) async {
    final controller = PCNewUserGuideController();
    addTearDown(controller.dispose);
    await controller.load();
    final prize = controller.checkInPrize;
    final context = await host(tester);
    final result = context.tipShow2(
      PCCheckInDialog(
        rewards: controller.config.checkInRewards,
        day: controller.checkInDay,
        onClaim: controller.claimCheckIn,
      ),
    );
    await frames(tester);
    await tester.tap(find.text('CLAIM \$${prize.toStringAsFixed(2)} NOW'));
    await frames(tester);
    expect(await result, isTrue);
    expect(controller.balance, closeTo(10 + prize, .000001));
    expect(controller.checkInDay, 1);
    expect(controller.canCheckIn, isFalse);
    expect(await controller.claimCheckIn(), isFalse);
    expect(controller.balance, closeTo(10 + prize, .000001));
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
  });

  testWidgets('跳过广告：首页入口激励与Claim概率插屏均结束，奖励仅结算一次', (tester) async {
    final controller = PCHomeRewardController(random: Random(7));
    addTearDown(controller.dispose);
    await controller.load();
    final reward = controller.rewardAt(1)!;
    final context = await host(tester);
    expect(
      await PCRewardedAdService.instance.request('home_bubble_rv'),
      isTrue,
    );
    final result = context.tipShow2(
      PCAwardDialog(
        award: reward.amount,
        reward: reward,
        balance: 10,
        claimAdPolicy: PCAwardClaimAdPolicy.probabilityInterstitial,
        onClaim: () async => await controller.claim(reward) != null,
      ),
    );
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester);
    expect(await result, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble('pc_dollar_number'),
      closeTo(10 + reward.amount, .000001),
    );
    expect(await controller.claim(reward), isNull);
    expect(
      preferences.getDouble('pc_dollar_number'),
      closeTo(10 + reward.amount, .000001),
    );
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
  });
}
