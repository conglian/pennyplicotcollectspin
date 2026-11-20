import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWheel.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  Future<bool> Function(String)? previousRewardedHandler;
  Future<bool> Function(String)? previousInterstitialHandler;
  final adPlacements = <String>[];
  final interstitialPlacements = <String>[];
  setUp(() {
    previousRewardedHandler = PCRewardedAdService.instance.handler;
    previousInterstitialHandler = PCInterstitialAdService.instance.handler;
    adPlacements.clear();
    interstitialPlacements.clear();
    PCRewardedAdService.instance.handler = (placement) async {
      adPlacements.add(placement);
      return true;
    };
    PCInterstitialAdService.instance.handler = (placement) async {
      interstitialPlacements.add(placement);
      return true;
    };
  });
  tearDown(() {
    PCRewardedAdService.instance.handler = previousRewardedHandler;
    PCInterstitialAdService.instance.handler = previousInterstitialHandler;
  });

  Future<void> seed(double gold) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_bg_music': false,
      'pc_pig_level': 2,
      'pc_dollar_number': 100.0,
      'pc_quiz_gold': gold,
      'pc_pig_level_index': gold,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_account_id': 'a***@mail.com',
      'pc_wheel_number': 2,
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 100},
        ],
      }),
    });
    PigsTabController.currentIndex.value = 0;
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
  }

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var n = 0; n < milliseconds; n += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final failure = tester.takeException();
      if (failure != null) throw StateError('UI frame failed: $failure');
    }
  }

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(home: page),
        ),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
    });
  }

  test('旧版满10的零气泡缓存自动重抽，超额数量和新奖励冷启动不回退', () async {
    await seed(10);
    final original = PCHomeRewardController(random: Random(7));
    await original.load();
    final prefs = await SharedPreferences.getInstance();
    final snapshot =
        jsonDecode(prefs.getString(PCHomeRewardController.storageKey)!) as Map;
    snapshot['prizes'] = [0, 0, 0];
    await prefs.setString(
      PCHomeRewardController.storageKey,
      jsonEncode(snapshot),
    );
    original.dispose();
    final restored = PCHomeRewardController(random: Random(7));
    await restored.load();
    expect(restored.amounts.every((v) => v >= .01 && v <= .02), isTrue);
    final reward = restored.rewardAt(0)!;
    await restored.claim(reward);
    expect(restored.gold, greaterThan(10));
    expect(await restored.claim(reward), isNull);
    final amount = restored.gold;
    restored.dispose();
    final progress = await PCPigProgress.sync(prefs);
    expect(progress.gold, amount);
    expect(progress.level, 2);
    expect(progress.balance, 100);
    expect(adPlacements, isEmpty);
  });

  for (final (source, singleClaim) in [
    ('home', true),
    ('home', false),
    ('quiz', true),
    ('quiz', false),
    ('wheel', true),
    ('wheel', false),
  ]) {
    testWidgets('金砖10后$source使用对应广告标记并结算${singleClaim ? '单倍' : '双倍'}', (
      tester,
    ) async {
      await seed(10.25);
      final home = PCHomeRewardController(
        random: Random(1),
        onSync: PCLocalProvider.instance.init,
      );
      final quiz = PCQuizController(
        random: Random(1),
        onSync: PCLocalProvider.instance.init,
      );
      final wheel = PCWheelController(
        random: Random(1),
        onSync: PCLocalProvider.instance.init,
      );
      var disposed = false;
      void disposeControllers() {
        if (disposed) return;
        disposed = true;
        home.dispose();
        quiz.dispose();
        wheel.dispose();
      }

      addTearDown(disposeControllers);
      final page = switch (source) {
        'home' => PChome(rewardController: home),
        'quiz' => PCQuiz(
          controller: quiz,
          active: true,
          bank: PCQuizBank.fromQuestions(const [
            PCQuizQuestion(
              question: 'Choose A',
              a: 'Correct',
              b: 'Wrong',
              answer: 'a',
            ),
          ]),
        ),
        _ => PCWheel(controller: wheel, active: true),
      };
      await show(tester, page);
      final key = switch (source) {
        'home' => 'pcHomeRewardBubble0',
        'quiz' => 'pcQuizAnswerA',
        _ => 'pcWheelGoButton',
      };
      await tester.tap(find.byKey(ValueKey(key)));
      await frames(tester, 1600);
      expect(find.byType(PCAwardDialog), findsOneWidget);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(adPlacements, isEmpty);
      final reward = tester
          .widget<PCAwardDialog>(find.byType(PCAwardDialog))
          .reward!;
      expect(reward.type, PCQuizRewardType.gold);
      expect(reward.amount, inInclusiveRange(.01, .02));
      final credited = singleClaim ? reward.amount : reward.amount * 2;
      await tester.tap(
        find.byKey(
          ValueKey(singleClaim ? 'pcAwardSingleClaim' : 'pcQuizClaimReward'),
        ),
      );
      await frames(tester);
      final effect = tester.widget<PCQuizRewardAnimation>(
        find.byType(PCQuizRewardAnimation),
      );
      expect(effect.reward.id, reward.id);
      expect(effect.reward.amount, closeTo(credited, .00001));
      final backdrop = find.byKey(const ValueKey('pcRewardCardBackground'));
      Color? cardColor() =>
          (tester.widget<DecoratedBox>(backdrop).decoration as BoxDecoration)
              .color;
      expect(cardColor(), const Color(0xDC000000));
      // 三个宿主都交由到账动画管理暗底，开始收缩时不能残留父页面的遮罩。
      for (
        var frame = 0;
        frame < 36 && cardColor() != Colors.transparent;
        frame++
      ) {
        await frames(tester, 50);
      }
      expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
      expect(cardColor(), Colors.transparent);
      expect(
        find.ancestor(
          of: find.byType(PCQuizRewardAnimation),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox && widget.color == pcDialogBackdrop,
          ),
        ),
        findsNothing,
      );
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .every((barrier) => barrier.color == null || barrier.color!.a == 0),
        isTrue,
      );
      expect(PCDialogCoordinator.instance.isBusy, isTrue);
      await frames(tester, 2400);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('pc_quiz_gold'), closeTo(10.25 + credited, .0001));
      expect(
        prefs.getDouble('pc_pig_level_index'),
        prefs.getDouble('pc_quiz_gold'),
      );
      expect(prefs.getDouble('pc_dollar_number'), 100);
      expect(find.byType(PCAwardDialog), findsNothing);
      final (rewarded, interstitial) = switch (source) {
        'quiz' => ('nkmdl_quizgetc_rv', 'nkmdl_quizgetinfor_int'),
        'wheel' => ('nkmdl_wheel_rv', 'nkmdl_wheel_int'),
        _ => ('nkmdl_moneybub_getpop_rv', 'nkmdl_moneybub_getpop_int'),
      };
      expect(adPlacements, [if (!singleClaim) rewarded]);
      expect(interstitialPlacements, [if (singleClaim) interstitial]);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(tester.takeException(), isNull);
      // 免费入口新增周期倒计时，须在WidgetTester检查定时器前退出页面并释放控制器。
      await tester.pumpWidget(const SizedBox());
      disposeControllers();
      await frames(tester, 400);
    });
  }
}
