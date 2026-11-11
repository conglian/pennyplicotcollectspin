import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCCheckInDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide1Page.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide2Page.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide3Page.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuideQuizDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCNewUserGuideFlow.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCPigShowDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWithdrawPage.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizContentPanel.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCRankData.dart';
import 'package:pennypilotcollectspin/PCTool/PCReturningUserController.dart';
import 'package:pennypilotcollectspin/PCTool/PCReturningUserHost.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final events = <(String, Map<String, dynamic>)>[];
  List<Map<String, dynamic>> emitted(String name) => events
      .where((event) => event.$1 == name)
      .map((event) => event.$2)
      .toList();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
    events.clear();
    PCAnalytics.reporter = (name, parameters) {
      events.add((name, Map<String, dynamic>.from(parameters)));
    };
    PigsTabController.switchTo(0);
  });
  tearDown(() => PCAnalytics.resetForTesting());

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
  }

  Widget app(Widget child) => ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) => MaterialApp(home: child),
  );

  testWidgets('前三步曝光不随重建重复，连点只记录一次且事件依顺序推进', (tester) async {
    final guide = PCNewUserGuideController();
    await tester.pumpWidget(
      app(PCNewUserGuideFlow(controller: guide, onCompleted: () {})),
    );
    await frames(tester);
    for (final (page, event) in [
      (PCGuide1Page, 'new_guide_one'),
      (PCGuide2Page, 'new_guide_two'),
      (PCGuide3Page, 'new_guide_three'),
    ]) {
      expect(find.byType(page), findsOneWidget);
      expect(emitted(event), hasLength(1));
      tester.element(find.byType(page)).markNeedsBuild();
      await frames(tester, 100);
      expect(emitted(event), hasLength(1));
      final button = tester.widget<ParticleButton>(find.byType(ParticleButton));
      button.onTap.call();
      button.onTap.call();
      await frames(tester);
      expect(emitted('${event}_c'), hasLength(1));
    }
    await tester.pumpWidget(const SizedBox());
    guide.dispose();
  });

  for (final isNewUser in [false, true]) {
    testWidgets('签到${isNewUser ? '新用户' : '普通用户'}点击防重，普通签到不误报新用户事件', (
      tester,
    ) async {
      final result = Completer<bool>();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: PCCheckInDialog(
              rewards: const [6, 1, 1, 1, 1, 1, 1],
              isNewUser: isNewUser,
              onClaim: () => result.future,
            ),
          ),
        ),
      );
      await frames(tester);
      final claim = find.text('CLAIM \$6.00 NOW');
      await tester.tap(claim);
      await tester.tap(claim);
      await frames(tester, 100);
      expect(emitted('new_sign_pop_c'), hasLength(isNewUser ? 1 : 0));
      result.complete(false);
      await frames(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('引导答对答错都打点击，反馈期间改答案不重复', (tester) async {
    await tester.pumpWidget(
      app(const Scaffold(body: PCGuideQuizDialog(index: 0))),
    );
    await frames(tester, 100);
    final panel = tester.widget<PCQuizContentPanel>(
      find.byType(PCQuizContentPanel),
    );
    panel.onAnswer!(false);
    panel.onAnswer!(true);
    await frames(tester, 100);
    expect(emitted('new_quiz_guide_c'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('收款页只首帧曝光，有效确认才记录且提交后连点无重复', (tester) async {
    var submitted = 0;
    await tester.pumpWidget(
      app(PCWithdrawPage(onSubmitted: (_) => submitted++)),
    );
    await frames(tester, 100);
    expect(emitted('input_account_page'), hasLength(1));
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await frames(tester, 100);
    expect(emitted('input_account_page_c'), isEmpty);
    await tester.enterText(find.byType(TextField), 'valid@example.com');
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await frames(tester, 100);
    expect(submitted, 1);
    expect(emitted('input_account_page'), hasLength(1));
    expect(emitted('input_account_page_c'), hasLength(1));
    await frames(tester, 2600);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('仅恢复为成功弹窗背景时不补报输入页曝光', (tester) async {
    await tester.pumpWidget(app(const PCWithdrawPage(trackExposure: false)));
    await frames(tester, 100);
    expect(emitted('input_account_page'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Show Pig入口、真正展示和Go Earn各记录一次', (tester) async {
    const user = PCUserData(
      id: 1,
      username: 'User ***123',
      totalEarning: 50,
      adsWatched: 10,
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => PCPigShowDialog.show(
                context,
                user: user,
                users: const [user],
              ),
              child: const Text('Show Pig'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show Pig'));
    await frames(tester);
    expect(emitted('home_list_showpig'), hasLength(1));
    expect(emitted('showpig_page'), hasLength(1));
    tester.element(find.byType(PCPigShowDialog)).markNeedsBuild();
    await frames(tester, 100);
    expect(emitted('showpig_page'), hasLength(1));
    await tester.tap(find.byKey(const ValueKey('pcPigShowGoEarn')));
    await frames(tester);
    expect(emitted('showpig_page_c'), hasLength(1));
    expect(PigsTabController.currentIndex.value, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('老用户Grow曝光和点击都带old', (tester) async {
    SharedPreferences.setMockInitialValues({'pc_day_date': '2026-10-24'});
    await PCLocalProvider.instance.init();
    final flow = PCReturningUserController(now: () => DateTime(2026, 10, 25));
    await flow.prepareLaunch(isExistingUser: true);
    await tester.pumpWidget(
      app(
        PCReturningUserHost(
          controller: flow,
          canPresent: () => true,
          onGoEarn: () {},
          child: const Scaffold(),
        ),
      ),
    );
    await frames(tester);
    expect(emitted('grow_bonus_pop'), [
      {'pop_from': 'old'},
    ]);
    await tester.tap(find.byKey(const ValueKey('pcGrowBonusAction')));
    await frames(tester);
    expect(emitted('grow_bonus_pop_c'), [
      {'pop_from': 'old'},
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('首页只在真实切回曝光，三奖励气泡点击事件不混用且冷却不重复点击', (tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_dollar_number': 10.0,
      'pc_pig_level': 0,
      'pc_pig_upgrade_seen_level_v1': 2,
    });
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
    final rewardAds = <String>[];
    PCRewardedAdService.instance.handler = (placement) async {
      rewardAds.add(placement);
      return false;
    };
    PCInterstitialAdService.instance.handler = (_) async => false;
    final rewards = PCHomeRewardController();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: app(PChome(rewardController: rewards)),
      ),
    );
    await frames(tester, 2800);
    expect(emitted('home_page'), hasLength(1));
    tester.element(find.byType(PChome)).markNeedsBuild();
    await frames(tester, 100);
    expect(emitted('home_page'), hasLength(1));
    await tester.tap(find.byKey(const ValueKey('pcHomeBubble0')));
    await frames(tester, 100);
    expect(emitted('home_float_quiz'), hasLength(1));
    expect(emitted('home_float_c'), isEmpty);
    PigsTabController.switchTo(0);
    await frames(tester, 100);
    expect(emitted('home_page'), hasLength(2));
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble1')));
    await frames(tester);
    expect(rewardAds, ['nkmdl_moneybub_getpop_rv']);
    expect(emitted('home_float_c'), hasLength(1));
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(emitted('home_page'), hasLength(2));
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble0')));
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    expect(emitted('home_float_c'), hasLength(2));
    await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble0')));
    await frames(tester, 100);
    expect(emitted('home_float_c'), hasLength(2));
    expect(find.byType(PCAwardDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 300);
    rewards.dispose();
  });
}
