import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizContentPanel.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  final bank = PCQuizBank.fromQuestions(const [
    PCQuizQuestion(
      question: 'First question',
      a: 'Correct',
      b: 'Wrong',
      answer: 'a',
    ),
    PCQuizQuestion(
      question: 'Next question',
      a: 'Correct',
      b: 'Wrong',
      answer: 'a',
    ),
    PCQuizQuestion(
      question: 'Third question',
      a: 'Correct',
      b: 'Wrong',
      answer: 'a',
    ),
  ]);

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('UI frame failed: $error');
    }
  }

  Future<PCQuizController> prepare() async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_bg_music': false,
      'pc_pig_level': 0,
      'pc_dollar_number': 10.0,
      PCNumberHelpers.configKey: jsonEncode({
        'quiz_console': 10000,
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 0},
        ],
      }),
    });
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
    final flow = PCQuizController(random: Random(2));
    await flow.load();
    return flow;
  }

  Future<void> mount(
    WidgetTester tester,
    PCQuizController flow,
    ValueNotifier<bool> active,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    PigsTabController.currentIndex.value = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, value, _) =>
                  PCQuiz(controller: flow, bank: bank, active: value),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
  }

  void cleanup(
    WidgetTester tester,
    List<PCQuizController> controllers,
    ValueNotifier<bool> active,
  ) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      for (final flow in controllers) {
        flow.dispose();
      }
      active.dispose();
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      expect(PCDialogCoordinator.instance.isBusy, false);
    });
  }

  Future<String> answerForReward(
    WidgetTester tester,
    PCQuizController flow,
  ) async {
    expect(
      tester
          .widget<PCQuizContentPanel>(find.byType(PCQuizContentPanel))
          .enabled,
      true,
    );
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await frames(tester, 1500);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    return flow.pendingReward!.id;
  }

  Future<void> roundTrip(
    WidgetTester tester,
    ValueNotifier<bool> active,
  ) async {
    active.value = false;
    PigsTabController.currentIndex.value = 0;
    await frames(tester);
    active.value = true;
    PigsTabController.currentIndex.value = 1;
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(find.byKey(const ValueKey('pcQuizResumeReward')), findsNothing);
    expect(
      tester
          .widget<PCQuizContentPanel>(find.byType(PCQuizContentPanel))
          .enabled,
      true,
    );
  }

  testWidgets('答题关闭奖励即放弃，切Tab和冷启动不补弹且下一题可以作答', (tester) async {
    final flow = await prepare();
    final controllers = [flow];
    final active = ValueNotifier(true);
    cleanup(tester, controllers, active);
    await mount(tester, flow, active);
    final oldId = await answerForReward(tester, flow);
    await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
    await frames(tester);
    expect(flow.pendingReward, isNull);
    expect(flow.balance, 10.0);
    expect(flow.questionIndex, 1);
    expect(flow.correctCount, 1);
    await roundTrip(tester, active);

    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    final restored = PCQuizController(random: Random(3));
    controllers.add(restored);
    await mount(tester, restored, active);
    expect(restored.pendingReward, isNull);
    expect(restored.questionIndex, 1);
    expect(restored.correctCount, 1);
    expect(restored.balance, 10.0);
    expect(await restored.claim(expectedRewardId: oldId), isNull);
    expect(await answerForReward(tester, restored), isNot(oldId));
    expect(restored.questionIndex, 2);
    expect(restored.correctCount, 2);
    expect(restored.balance, 10.0);
  });

  for (final outcome in [PCAdOutcome.failed, PCAdOutcome.cancelled]) {
    testWidgets('答题激励${outcome.name}立即清缓存，取消不显示失败且切Tab后可答下一题', (tester) async {
      final flow = await prepare();
      final active = ValueNotifier(true);
      cleanup(tester, [flow], active);
      var ads = 0;
      PCRewardedAdService.instance.bindOutcomeHandler((_) async {
        ads++;
        return outcome;
      });
      await mount(tester, flow, active);
      final oldId = await answerForReward(tester, flow);
      await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
      await frames(tester);
      expect(
        find.byType(PCAdLoadingFailedDialog),
        outcome == PCAdOutcome.failed ? findsOneWidget : findsNothing,
      );
      expect(flow.pendingReward, isNull);
      expect(flow.balance, 10.0);
      expect(flow.questionIndex, 1);
      expect(ads, 1);

      final restored = PCQuizController();
      await restored.load();
      expect(restored.pendingReward, isNull);
      expect(restored.balance, 10.0);
      expect(restored.questionIndex, 1);
      restored.dispose();
      if (outcome == PCAdOutcome.failed) {
        await tester.tap(find.text('Try Again').last);
        await frames(tester);
      }
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(ads, 1);
      await roundTrip(tester, active);
      expect(await answerForReward(tester, flow), isNot(oldId));
      expect(flow.correctCount, 2);
      expect(flow.balance, 10.0);
      expect(ads, 1);
    });
  }

  testWidgets('外部Navigator关闭答题奖励同样放弃，Tab往返后下一题不被旧奖锁住', (tester) async {
    final flow = await prepare();
    final active = ValueNotifier(true);
    cleanup(tester, [flow], active);
    await mount(tester, flow, active);
    final oldId = await answerForReward(tester, flow);
    Navigator.of(tester.element(find.byType(PCAwardDialog))).pop();
    await frames(tester);
    expect(flow.pendingReward, isNull);
    expect(flow.questionIndex, 1);
    expect(flow.correctCount, 1);
    expect(flow.balance, 10.0);
    await roundTrip(tester, active);
    expect(await answerForReward(tester, flow), isNot(oldId));
    expect(flow.questionIndex, 2);
  });

  testWidgets('答题入页丢弃旧存档奖励，保留题号及正确次数，不发奖且可继续答题', (tester) async {
    final flow = await prepare();
    final old = (await flow.answer(correct: true))!;
    expect(flow.pendingReward, isNotNull);
    final active = ValueNotifier(true);
    cleanup(tester, [flow], active);
    await mount(tester, flow, active);
    expect(flow.pendingReward, isNull);
    expect(flow.questionIndex, 1);
    expect(flow.correctCount, 1);
    expect(flow.balance, 10.0);
    expect(await flow.claim(expectedRewardId: old.id), isNull);
    await roundTrip(tester, active);
    expect(await answerForReward(tester, flow), isNot(old.id));
    expect(flow.questionIndex, 2);
    expect(flow.correctCount, 2);
    expect(flow.balance, 10.0);
  });

  testWidgets('答题反馈未结束切离再快速切回，不弹旧奖且下一题立即可答', (tester) async {
    final flow = await prepare();
    final active = ValueNotifier(true);
    cleanup(tester, [flow], active);
    await mount(tester, flow, active);
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await frames(tester, 100);
    final oldId = flow.pendingReward!.id;
    expect(find.byType(PCAwardDialog), findsNothing);
    active.value = false;
    PigsTabController.currentIndex.value = 0;
    await frames(tester, 50);
    active.value = true;
    PigsTabController.currentIndex.value = 1;
    await frames(tester, 1500);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(flow.pendingReward, isNull);
    expect(flow.questionIndex, 1);
    expect(flow.correctCount, 1);
    expect(flow.balance, 10.0);
    expect(await flow.claim(expectedRewardId: oldId), isNull);
    expect(await answerForReward(tester, flow), isNot(oldId));
    expect(flow.questionIndex, 2);
    expect(flow.correctCount, 2);
    expect(flow.balance, 10.0);
  });
}
