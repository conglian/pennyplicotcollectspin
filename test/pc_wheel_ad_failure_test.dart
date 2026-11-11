import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWheel.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelOpportunityStore.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('UI frame failed: $error');
    }
  }

  Future<PCWheelController> prepareWheel() async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_bg_music': false,
      'pc_pig_level': 2,
      'pc_dollar_number': 100.0,
      'pc_quiz_diamonds': 20.0,
      'pc_quiz_gold': 10.0,
      'pc_pig_level_index': 10.0,
      'pc_wheel_number': 3,
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 0},
        ],
      }),
      PCWheelOpportunityStore.storageKey: jsonEncode({
        'balance': 3,
        'lastGrantDay': PCWheelOpportunityStore.dayKey(DateTime.now()),
        'quizAwardThrough': 0,
        'wheelAppliedId': '',
      }),
    });
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
    final flow = PCWheelController(random: Random(2));
    await flow.load();
    expect(flow.spins, 3);
    return flow;
  }

  Future<void> mount(
    WidgetTester tester,
    PCWheelController flow,
    ValueNotifier<bool> active,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    PigsTabController.currentIndex.value = 2;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, value, _) =>
                  PCWheel(controller: flow, active: value),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
  }

  Future<String> spinForReward(
    WidgetTester tester,
    PCWheelController flow,
  ) async {
    await tester.tap(find.byKey(const ValueKey('pcWheelGoButton')));
    await frames(tester, 1800);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    return flow.pending!.reward.id;
  }

  void cleanup(
    WidgetTester tester,
    PCWheelController flow,
    ValueNotifier<bool> active,
  ) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      flow.dispose();
      active.dispose();
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      expect(PCDialogCoordinator.instance.isBusy, false);
    });
  }

  for (final outcome in [PCAdOutcome.failed, PCAdOutcome.cancelled]) {
    testWidgets('转盘激励${outcome.name}放弃奖励，正常取消不显示失败且切Tab返回不补弹', (tester) async {
      final flow = await prepareWheel();
      final active = ValueNotifier(true);
      cleanup(tester, flow, active);
      var ads = 0;
      PCRewardedAdService.instance.bindOutcomeHandler((_) async {
        ads++;
        return outcome;
      });
      await mount(tester, flow, active);
      final oldId = await spinForReward(tester, flow);
      await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
      await frames(tester);
      expect(
        find.byType(PCAdLoadingFailedDialog),
        outcome == PCAdOutcome.failed ? findsOneWidget : findsNothing,
      );
      expect(flow.pending, isNull);
      expect(flow.gold, 10.0);
      expect(flow.spins, 2);
      if (outcome == PCAdOutcome.failed) {
        await tester.tap(find.text('Try Again').last);
        await frames(tester);
      }
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(ads, 1);
      active.value = false;
      PigsTabController.currentIndex.value = 0;
      await frames(tester);
      active.value = true;
      PigsTabController.currentIndex.value = 2;
      await frames(tester);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(flow.pending, isNull);
      // 新一轮仍需真实消耗一次机会；旧失败奖励不会复活。
      await spinForReward(tester, flow);
      expect(flow.pending!.reward.id, isNot(oldId));
      expect(flow.spins, 1);
      expect(flow.gold, 10.0);
      expect(ads, 1);
    });
  }

  testWidgets('普通关闭转盘领奖框立即放弃，Tab往返及冷启动不补弹不返还机会', (tester) async {
    final flow = await prepareWheel();
    final active = ValueNotifier(true);
    cleanup(tester, flow, active);
    var rewarded = 0;
    PCRewardedAdService.instance.handler = (_) async {
      rewarded++;
      return true;
    };
    await mount(tester, flow, active);
    final oldId = await spinForReward(tester, flow);
    await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(flow.pending, isNull);
    active.value = false;
    PigsTabController.currentIndex.value = 0;
    await frames(tester);
    active.value = true;
    PigsTabController.currentIndex.value = 2;
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(flow.pending, isNull);
    expect(flow.spins, 2);
    expect(flow.gold, 10.0);
    expect(rewarded, 0);

    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    final restored = PCWheelController(random: Random(3));
    addTearDown(restored.dispose);
    await mount(tester, restored, active);
    expect(restored.pending, isNull);
    expect(restored.spins, 2);
    expect(restored.gold, 10.0);
    expect(await restored.claim(expectedRewardId: oldId), isNull);
    final newId = await spinForReward(tester, restored);
    expect(newId, isNot(oldId));
    expect(restored.spins, 1);
    expect(restored.gold, 10.0);
  });

  testWidgets('外部关闭转盘奖励路由同样放弃，返回Tab不恢复且可继续转动', (tester) async {
    final flow = await prepareWheel();
    final active = ValueNotifier(true);
    cleanup(tester, flow, active);
    await mount(tester, flow, active);
    final oldId = await spinForReward(tester, flow);
    Navigator.of(tester.element(find.byType(PCAwardDialog))).pop();
    await frames(tester);
    expect(flow.pending, isNull);
    expect(flow.spins, 2);
    expect(flow.gold, 10.0);
    active.value = false;
    await frames(tester);
    active.value = true;
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(await spinForReward(tester, flow), isNot(oldId));
    expect(flow.spins, 1);
  });

  testWidgets('转盘入页清理旧版本遗留待奖，不发奖不退机会也不自动补弹', (tester) async {
    final flow = await prepareWheel();
    expect(await flow.start(), PCWheelStartResult.started);
    final oldId = flow.pending!.reward.id;
    final active = ValueNotifier(true);
    cleanup(tester, flow, active);
    await mount(tester, flow, active);
    expect(flow.pending, isNull);
    expect(flow.spins, 2);
    expect(flow.gold, 10.0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PCWheelController.storageKey), isNull);
    expect(await flow.claim(expectedRewardId: oldId), isNull);
    active.value = false;
    await frames(tester);
    active.value = true;
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(await spinForReward(tester, flow), isNot(oldId));
    expect(flow.spins, 1);
  });

  testWidgets('转盘动画未结束切离再快速切回，不弹旧奖且可重新转动', (tester) async {
    final flow = await prepareWheel();
    final active = ValueNotifier(true);
    cleanup(tester, flow, active);
    await mount(tester, flow, active);
    await tester.tap(find.byKey(const ValueKey('pcWheelGoButton')));
    await frames(tester, 100);
    final oldId = flow.pending!.reward.id;
    expect(find.byType(PCAwardDialog), findsNothing);
    active.value = false;
    PigsTabController.currentIndex.value = 0;
    await frames(tester, 50);
    active.value = true;
    PigsTabController.currentIndex.value = 2;
    await frames(tester, 1800);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(flow.pending, isNull);
    expect(flow.spins, 2);
    expect(flow.gold, 10.0);
    expect(await flow.claim(expectedRewardId: oldId), isNull);
    expect(await spinForReward(tester, flow), isNot(oldId));
    expect(flow.spins, 1);
    expect(flow.gold, 10.0);
  });
}
