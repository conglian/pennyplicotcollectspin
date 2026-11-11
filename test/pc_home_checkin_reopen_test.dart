import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCCheckInDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
  }

  Future<PCHomeRewardController> home(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_bg_music': false,
      'pc_dollar_number': 10.0,
      'pc_pig_level': 0,
      'pc_pig_upgrade_seen_level_v1': 2,
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 0},
        ],
      }),
    });
    PigsTabController.currentIndex.value = 0;
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
    PCRewardedAdService.instance.handler = (_) async => false;
    PCInterstitialAdService.instance.handler = (_) async => false;
    final rewards = PCHomeRewardController(random: Random(3));
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) =>
              MaterialApp(home: PChome(rewardController: rewards)),
        ),
      ),
    );
    await frames(tester, 2800);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
    });
    return rewards;
  }

  Finder signIn() => find.byKey(pcHomeCheckInTargetKey);
  Finder bubble(String key) => find.byKey(ValueKey(key));
  ParticleButton button(WidgetTester tester, Finder bubble) =>
      tester.widget<ParticleButton>(
        find.descendant(of: bubble, matching: find.byType(ParticleButton)),
      );
  Finder signInClose() => find.ancestor(
    of: find.descendant(
      of: find.byType(PCCheckInDialog),
      matching: find.byWidgetPredicate(
        (widget) => widget is PCImg && widget.name == 'pc_closes_btn',
      ),
    ),
    matching: find.byType(ParticleButton),
  );
  void expectAllBubblesEnabled(WidgetTester tester, {bool freeEnabled = true}) {
    expect(button(tester, signIn()).enabled, isTrue);
    for (final key in [
      'pcHomeBubble0',
      'pcHomeBubble4',
      'pcHomeBubble6',
      'pcHomeRewardBubble0',
      'pcHomeRewardBubble1',
      'pcHomeRewardBubble2',
    ]) {
      expect(
        button(tester, bubble(key)).enabled,
        key == 'pcHomeRewardBubble0' ? freeEnabled : isTrue,
        reason: key,
      );
    }
  }

  for (final exit in ['X', 'external', 'failed', 'cancelled', 'success']) {
    testWidgets('签到$exit关闭后释放遮罩和交互锁，可再次签到及点击首页其他气泡', (tester) async {
      final rewards = await home(tester);
      try {
        if (exit == 'success') {
          PCRewardedAdService.instance.handler = (_) async => true;
        } else if (exit == 'cancelled') {
          PCRewardedAdService.instance.bindOutcomeHandler(
            (_) async => PCAdOutcome.cancelled,
          );
        }
        final prize = PCNewUserGuideController.instance.checkInPrize;
        await tester.tap(signIn());
        await frames(tester);
        expect(find.byType(PCCheckInDialog), findsOneWidget);
        expect(PCDialogCoordinator.instance.isPresenting, isTrue);

        // 广告Activity回前台、缓存刷新等都会通知首页；在签到停留期间模拟同一重建。
        await PCLocalProvider.instance.init();
        await frames(tester);
        expectAllBubblesEnabled(tester);

        switch (exit) {
          case 'X':
            await tester.tap(signInClose());
          case 'external':
            Navigator.of(
              tester.element(find.byType(PCCheckInDialog)),
            ).pop(false);
          case 'failed':
            final claim = find
                .descendant(
                  of: find.byType(PCCheckInDialog),
                  matching: find.byType(ParticleButton),
                )
                .first;
            await tester.tap(claim);
            await frames(tester);
            expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
            await tester.tap(find.text('Try Again').last);
          case 'success':
          case 'cancelled':
            await tester.tap(
              find.text('CLAIM \$${prize.toStringAsFixed(2)} NOW'),
            );
        }
        await frames(tester);
        expect(find.byType(PCCheckInDialog), findsNothing);
        expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
        expect(PCDialogCoordinator.instance.isBusy, isFalse);
        expect(PCDialogCoordinator.instance.holdCount, 0);
        expectAllBubblesEnabled(tester);

        await tester.tap(signIn());
        await frames(tester);
        expect(find.byType(PCCheckInDialog), findsOneWidget);
        await tester.tap(signInClose());
        await frames(tester);

        await tester.tap(bubble('pcHomeRewardBubble0'));
        await frames(tester);
        expect(find.byType(PCAwardDialog), findsOneWidget);
        expectAllBubblesEnabled(tester, freeEnabled: false);
        await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
        await frames(tester);
        expect(find.byType(PCAwardDialog), findsNothing);
        expect(PCDialogCoordinator.instance.isBusy, isFalse);
        expectAllBubblesEnabled(tester, freeEnabled: false);

        await tester.tap(bubble('pcHomeBubble0'));
        expect(PigsTabController.currentIndex.value, 1);
        PigsTabController.currentIndex.value = 0;
        await frames(tester, 100);
        await tester.tap(bubble('pcHomeBubble4'));
        expect(PigsTabController.currentIndex.value, 2);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getDouble('pc_dollar_number'),
          exit == 'success' ? 10 + prize : 10,
        );
        expect(
          PCNewUserGuideController.instance.checkInDay,
          exit == 'success' ? 1 : 0,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await frames(tester, 400);
        rewards.dispose();
      }
    });
  }

  testWidgets('首页入口激励等待时其余气泡持续可点，切答题转盘不被共享忙碌状态拦截', (tester) async {
    final rewards = await home(tester);
    final ad = Completer<bool>();
    PCRewardedAdService.instance.handler = (_) => ad.future;
    try {
      await tester.tap(bubble('pcHomeRewardBubble1'));
      await frames(tester, 100);
      expectAllBubblesEnabled(tester);
      expect(find.byType(PCAwardDialog), findsNothing);
      await tester.tap(bubble('pcHomeBubble0'));
      expect(PigsTabController.currentIndex.value, 1);
      ad.complete(true);
      await frames(tester);
      expect(find.byType(PCAwardDialog), findsNothing);
      PigsTabController.currentIndex.value = 0;
      await frames(tester, 100);
      expectAllBubblesEnabled(tester);
      await tester.tap(bubble('pcHomeBubble4'));
      expect(PigsTabController.currentIndex.value, 2);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getDouble('pc_dollar_number'), 10);
    } finally {
      if (!ad.isCompleted) ad.complete(false);
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      rewards.dispose();
    }
  });
}
