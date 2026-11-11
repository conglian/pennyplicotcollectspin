import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuideQuizDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide1Dialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizContentPanel.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_fake_audio.dart';
import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  late PCFakeAudio fake;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_bg_music': false,
      'pc_dollar_number': 10.0,
      PCNumberHelpers.configKey: '{"quiz_console":10000}',
    });
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
    fake = PCFakeAudio();
    PCAudioUtils.overrideForTesting(fake.audio);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  Future<void> frames(WidgetTester tester, [int time = 300]) async {
    for (var i = 0; i < time; i += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
  }

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
        ),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 1200);
      await fake.audio.dispose();
      PCAudioUtils.overrideForTesting(null);
    });
  }

  for (final type in PCQuizRewardType.values) {
    testWidgets('领取前获得${type.name}弹窗及重建不播放加钱音效', (tester) async {
      late StateSetter rebuild;
      await mount(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return PCAwardDialog(
              award: 1,
              reward: PCQuizReward(
                id: 'reward',
                type: type,
                amount: 1,
                questionIndex: 0,
              ),
              adsEnabled: false,
            );
          },
        ),
      );
      expect(fake.count(PCAudioUtils.rewardAsset), 0);
      rebuild(() {});
      await frames(tester);
      expect(fake.count(PCAudioUtils.rewardAsset), 0);
    });

    testWidgets('实际到账${type.name}奖励弹窗播放一次，重建不重复播放', (tester) async {
      late StateSetter rebuild;
      await mount(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return PCQuizRewardAnimation(
              reward: PCQuizReward(
                id: 'credited-${type.name}',
                type: type,
                amount: 1,
                questionIndex: 0,
              ),
              balance: 20,
              onFinished: () {},
            );
          },
        ),
      );
      expect(fake.count(PCAudioUtils.rewardAsset), 1);
      rebuild(() {});
      await frames(tester);
      expect(fake.count(PCAudioUtils.rewardAsset), 1);
    });
  }

  testWidgets('关闭特效后实际到账奖励弹窗也不播放加钱音效', (tester) async {
    await fake.audio.setSoundEffectsEnabled(false);
    await mount(
      tester,
      PCQuizRewardAnimation(
        reward: const PCQuizReward(
          id: 'muted-credit',
          type: PCQuizRewardType.cash,
          amount: 1,
          questionIndex: 0,
        ),
        balance: 20,
        onFinished: () {},
      ),
    );
    expect(fake.count(PCAudioUtils.rewardAsset), 0);
    expect(fake.effects, isEmpty);
  });

  testWidgets('新用户签到到账弹窗出现时播放一次，重建不重播', (tester) async {
    late StateSetter rebuild;
    await mount(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          rebuild = setState;
          return const PCGuide1Dialog(depositAmount: 6);
        },
      ),
    );
    expect(fake.count(PCAudioUtils.rewardAsset), 1);
    rebuild(() {});
    await frames(tester);
    expect(fake.count(PCAudioUtils.rewardAsset), 1);
  });

  for (final correct in [true, false]) {
    testWidgets('新用户答题${correct ? '答对' : '答错'}第一次点击即播，重复点击无音效', (tester) async {
      await mount(tester, const PCGuideQuizDialog(index: 0));
      final panel = tester.widget<PCQuizContentPanel>(
        find.byType(PCQuizContentPanel),
      );
      panel.onAnswer!(correct);
      panel.onAnswer!(!correct);
      await frames(tester, 100);
      expect(fake.count(PCAudioUtils.quizOptionAsset), 1);
    });

    testWidgets('普通答题${correct ? '答对' : '答错'}第一次有效点击立即播，当前题不重复播', (
      tester,
    ) async {
      PigsTabController.currentIndex.value = 1;
      final flow = PCQuizController();
      await flow.load();
      final bank = PCQuizBank.fromQuestions(const [
        PCQuizQuestion(
          question: 'Question',
          a: 'Right',
          b: 'Wrong',
          answer: 'a',
        ),
      ]);
      await mount(tester, PCQuiz(controller: flow, bank: bank, active: true));
      final panel = tester.widget<PCQuizContentPanel>(
        find.byType(PCQuizContentPanel),
      );
      expect(panel.enabled, isTrue);
      panel.onAnswer!(correct);
      panel.onAnswer!(!correct);
      await frames(tester, 100);
      expect(fake.count(PCAudioUtils.quizOptionAsset), 1);
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 1200);
      flow.dispose();
    });
  }
}
