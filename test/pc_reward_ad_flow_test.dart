import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardBubble.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
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

  Future<void> seed({int probability = 0}) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_bg_music': false,
      'pc_pig_level': 2,
      'pc_dollar_number': 106.0,
      'pc_quiz_gold': 10.25,
      'pc_pig_level_index': 10.25,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_account_id': '2***5532',
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': probability},
        ],
      }),
    });
    PigsTabController.currentIndex.value = 0;
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
  }

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('UI frame failed: $error');
    }
  }

  Future<BuildContext> show(
    WidgetTester tester, {
    Widget? page,
    Size size = const Size(375, 812),
    int initialFrames = 2600,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return page ?? const Scaffold();
              },
            ),
          ),
        ),
      ),
    );
    await frames(tester, initialFrames);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
    });
    return context;
  }

  testWidgets('首页AD气泡激励成功静默到账直接开获得框，Claim概率插屏后到账动画防重', (tester) async {
    await seed(probability: 100);
    final firstAd = Completer<bool>();
    final claimAd = Completer<bool>();
    final placements = <String>[];
    final interstitials = <String>[];
    PCRewardedAdService.instance.handler = (placement) {
      placements.add(placement);
      return firstAd.future;
    };
    PCInterstitialAdService.instance.handler = (placement) {
      interstitials.add(placement);
      return claimAd.future;
    };
    final rewards = PCHomeRewardController(
      random: Random(1),
      onSync: PCLocalProvider.instance.init,
    );
    addTearDown(rewards.dispose);
    await show(tester, page: PChome(rewardController: rewards));
    final oldGeneration = rewards.generation;
    final reward = rewards.rewardAt(1)!;
    final bubble = find.byKey(const ValueKey('pcHomeRewardBubble1'));
    await tester.tap(bubble);
    await tester.tap(bubble);
    await frames(tester, 100);
    expect(placements, ['nkmdl_moneybub_getpop_rv']);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(rewards.gold, 10.25);
    firstAd.complete(true);
    await frames(tester, 100);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    expect(rewards.gold, closeTo(10.25 + reward.amount, .00001));
    expect(rewards.generation, oldGeneration + 1);
    final nextReward = tester
        .widget<PCAwardDialog>(find.byType(PCAwardDialog))
        .reward!;
    expect(nextReward.id, isNot(reward.id));
    expect(
      find.descendant(
        of: find.byType(PCAwardDialog),
        matching: find.byWidgetPredicate(
          (widget) => widget is PCImg && widget.name == 'pc_ad_icon',
        ),
      ),
      findsOneWidget,
    );
    expect(rewards.gold, closeTo(10.25 + reward.amount, .00001));
    await tester.tap(find.byKey(const ValueKey('pcAwardSingleClaim')));
    await tester.tap(
      find.byKey(const ValueKey('pcAwardSingleClaim')),
      warnIfMissed: false,
    );
    await frames(tester, 100);
    expect(placements, ['nkmdl_moneybub_getpop_rv']);
    expect(interstitials, ['nkmdl_moneybub_getpop_int']);
    await tester.tap(
      find.byKey(const ValueKey('pcQuizClaimReward')),
      warnIfMissed: false,
    );
    expect(interstitials, ['nkmdl_moneybub_getpop_int']);
    expect(rewards.gold, closeTo(10.25 + reward.amount, .00001));
    claimAd.complete(true);
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    final effect = tester.widget<PCQuizRewardAnimation>(
      find.byType(PCQuizRewardAnimation),
    );
    expect(effect.reward.id, nextReward.id);
    await frames(tester, 2400);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(
      rewards.gold,
      closeTo(10.25 + reward.amount + nextReward.amount, .00001),
    );
    expect(rewards.generation, oldGeneration + 2);
    expect(rewards.amounts.length, 3);
    expect(placements, ['nkmdl_moneybub_getpop_rv']);
    expect(interstitials, ['nkmdl_moneybub_getpop_int']);
  });

  testWidgets('首页前置激励失败只显示失败面板，Try Again仅关闭且不重抽奖励', (tester) async {
    await seed();
    var requests = 0;
    PCRewardedAdService.instance.handler = (_) async {
      requests++;
      return false;
    };
    final rewards = PCHomeRewardController(random: Random(2));
    addTearDown(rewards.dispose);
    await show(tester, page: PChome(rewardController: rewards));
    final values = rewards.amounts;
    final generation = rewards.generation;
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble1')));
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(rewards.gold, 10.25);
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(requests, 1);
    expect(rewards.generation, generation);
    expect(rewards.amounts, values);
  });

  testWidgets('首页等待前置激励时切页，回调不能在其他Tab打开奖励弹窗', (tester) async {
    await seed();
    final ad = Completer<bool>();
    PCRewardedAdService.instance.handler = (_) => ad.future;
    final rewards = PCHomeRewardController(random: Random(3));
    addTearDown(rewards.dispose);
    await show(tester, page: PChome(rewardController: rewards));
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble1')));
    await frames(tester, 100);
    PigsTabController.currentIndex.value = 1;
    ad.complete(true);
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(rewards.gold, 10.25);
    expect(PCDialogCoordinator.instance.isBusy, false);
  });

  testWidgets('免费气泡无需激励，领取后置灰倒计时60秒且冷却时不能再次打开', (tester) async {
    await seed();
    var now = DateTime(2026, 10, 27, 12);
    var rewarded = 0;
    var interstitials = 0;
    PCRewardedAdService.instance.handler = (_) async {
      rewarded++;
      return false;
    };
    PCInterstitialAdService.instance.handler = (_) async {
      interstitials++;
      return true;
    };
    final rewards = PCHomeRewardController(
      random: Random(4),
      now: () => now,
      onSync: PCLocalProvider.instance.init,
    );
    addTearDown(rewards.dispose);
    await show(tester, page: PChome(rewardController: rewards));
    final free = find.byKey(const ValueKey('pcHomeRewardBubble0'));
    PCHomeRewardBubble freeContent() => tester.widget<PCHomeRewardBubble>(
      find.descendant(of: free, matching: find.byType(PCHomeRewardBubble)),
    );
    expect(freeContent().showAdBadge, false);
    final adBubbles = <PCHomeRewardBubble>[];
    for (final slot in [1, 2]) {
      adBubbles.add(
        tester.widget<PCHomeRewardBubble>(
          find.descendant(
            of: find.byKey(ValueKey('pcHomeRewardBubble$slot')),
            matching: find.byType(PCHomeRewardBubble),
          ),
        ),
      );
    }
    expect(adBubbles.every((bubble) => bubble.showAdBadge), true);
    expect(adBubbles[0].caption, '×???');
    expect(adBubbles[1].caption, startsWith('×'));
    expect(adBubbles[1].caption, isNot(contains('?')));
    await tester.tap(free);
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    final reward = tester
        .widget<PCAwardDialog>(find.byType(PCAwardDialog))
        .reward!;
    expect(rewarded, 0);
    await tester.tap(find.byKey(const ValueKey('pcAwardSingleClaim')));
    await frames(tester, 2600);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(rewards.gold, closeTo(10.25 + reward.amount, .00001));
    expect(rewards.freeCooldownSeconds, 60);
    expect(freeContent().cooldownSeconds, 60);
    expect(freeContent().caption, '00:01:00');
    await tester.tap(free, warnIfMissed: false);
    await frames(tester, 100);
    expect(find.byType(PCAwardDialog), findsNothing);
    now = now.add(const Duration(seconds: 59));
    await frames(tester, 1000);
    expect(freeContent().cooldownSeconds, 1);
    await tester.tap(free, warnIfMissed: false);
    await frames(tester, 100);
    expect(find.byType(PCAwardDialog), findsNothing);
    now = now.add(const Duration(seconds: 1));
    await frames(tester, 1000);
    expect(freeContent().cooldownSeconds, 0);
    await tester.tap(free);
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(rewards.freeCooldownSeconds, 60);
    expect(freeContent().cooldownSeconds, 60);
    expect(rewards.gold, closeTo(10.25 + reward.amount, .00001));
    expect(rewarded, 0);
    expect(interstitials, 0);
    // 第二次打开后直接关闭也冷却；推进测试时钟让倒计时退出后再检查定时器。
    now = now.add(const Duration(seconds: 60));
    await frames(tester, 1000);
  });

  testWidgets('金苹果入口插屏成功静默到账直接开获得框，Claim带AD激励后再播到账动画', (tester) async {
    await seed(probability: 100);
    final entryAd = Completer<bool>();
    final rewarded = <String>[];
    final interstitials = <String>[];
    PCRewardedAdService.instance.handler = (placement) async {
      rewarded.add(placement);
      return true;
    };
    PCInterstitialAdService.instance.handler = (placement) {
      interstitials.add(placement);
      return entryAd.future;
    };
    final rewards = PCHomeRewardController(
      random: Random(5),
      onSync: PCLocalProvider.instance.init,
    );
    addTearDown(rewards.dispose);
    await show(tester, page: PChome(rewardController: rewards));
    final entryReward = rewards.rewardAt(2)!;
    final oldGeneration = rewards.generation;
    final apple = find.byKey(const ValueKey('pcHomeBubble6'));
    expect(
      find.descendant(
        of: apple,
        matching: find.byWidgetPredicate(
          (widget) => widget is PCImg && widget.name == 'pc_ad_icon',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(apple);
    await tester.tap(apple, warnIfMissed: false);
    await frames(tester, 100);
    expect(rewarded, isEmpty);
    expect(interstitials, ['nkmdl_applebub_int']);
    expect(find.byType(PCAwardDialog), findsNothing);
    entryAd.complete(true);
    await frames(tester);
    final reward = tester
        .widget<PCAwardDialog>(find.byType(PCAwardDialog))
        .reward!;
    expect(rewards.gold, closeTo(10.25 + entryReward.amount, .00001));
    expect(rewards.generation, oldGeneration + 1);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(reward.id, isNot(entryReward.id));
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester);
    expect(rewarded, ['asd_rv']);
    expect(interstitials, ['nkmdl_applebub_int']);
    expect(
      rewards.gold,
      closeTo(10.25 + entryReward.amount + reward.amount * 2, .00001),
    );
    expect(rewards.generation, oldGeneration + 2);
    final effect = tester.widget<PCQuizRewardAnimation>(
      find.byType(PCQuizRewardAnimation),
    );
    expect(effect.reward.id, reward.id);
    await frames(tester, 2400);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(rewards.freeCooldownSeconds, 0);
    expect(find.byType(PCAwardDialog), findsNothing);
  });

  testWidgets('首页真实挂载冷启动提示2秒，切离隐藏并在切回后重计2秒', (tester) async {
    await seed();
    final rewards = PCHomeRewardController(random: Random(6));
    addTearDown(rewards.dispose);
    await show(
      tester,
      page: PChome(rewardController: rewards),
      initialFrames: 100,
    );
    final tip = find.text(
      'Activated: +3% bonus tomorrow,\n'
      "don't forget to come back!",
      findRichText: true,
    );
    expect(tip, findsOneWidget);
    await frames(tester, 1800);
    expect(tip, findsOneWidget);
    await frames(tester, 100);
    expect(tip, findsNothing);
    PigsTabController.currentIndex.value = 1;
    await tester.pump();
    expect(tip, findsNothing);
    PigsTabController.currentIndex.value = 0;
    await tester.pump();
    await tester.pump();
    expect(tip, findsOneWidget);
    await frames(tester, 1000);
    PigsTabController.currentIndex.value = 2;
    await tester.pump();
    expect(tip, findsNothing);
    PigsTabController.currentIndex.value = 0;
    await tester.pump();
    await tester.pump();
    await frames(tester, 1950);
    expect(tip, findsOneWidget);
    await frames(tester, 50);
    expect(tip, findsNothing);
  });

  testWidgets('320宽短屏七个入口在页面范围内，免费气泡仍可点击', (tester) async {
    await seed();
    var now = DateTime(2026, 10, 27, 12);
    final rewards = PCHomeRewardController(random: Random(7), now: () => now);
    addTearDown(rewards.dispose);
    await show(
      tester,
      page: PChome(rewardController: rewards),
      size: const Size(320, 568),
    );
    final bounds = tester.getRect(find.byType(PChome));
    for (final key in [
      const ValueKey('pcHomeBubble0'),
      const ValueKey('pcHomeBubble4'),
      const ValueKey('pcHomeBubble6'),
      const ValueKey('pcHomeRewardBubble0'),
      const ValueKey('pcHomeRewardBubble1'),
      const ValueKey('pcHomeRewardBubble2'),
      pcHomeCheckInTargetKey,
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(
        bounds.contains(rect.topLeft),
        true,
        reason: '$key starts in bounds',
      );
      expect(
        bounds.contains(rect.bottomRight),
        true,
        reason: '$key ends in bounds',
      );
      expect(rect.width, greaterThan(40));
    }
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble0')));
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await frames(tester);
    now = now.add(const Duration(seconds: 60));
    await frames(tester, 1000);
  });

  for (final type in PCQuizRewardType.values) {
    testWidgets('${type.name}奖励Claim激励失败不执行发奖，失败面板退出不出插屏', (tester) async {
      await seed(probability: 100);
      var claims = 0;
      var rewarded = 0;
      var interstitials = 0;
      PCRewardedAdService.instance.handler = (_) async {
        rewarded++;
        return false;
      };
      PCInterstitialAdService.instance.handler = (_) async {
        interstitials++;
        return true;
      };
      final context = await show(tester);
      final closed = context.tipShow2(
        PCAwardDialog(
          award: .02,
          reward: PCQuizReward(
            id: 'failure-${type.name}',
            type: type,
            amount: .02,
            questionIndex: 0,
          ),
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
      await frames(tester);
      expect(claims, 0);
      expect(rewarded, 1);
      expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
      await tester.tap(find.text('Try Again').last);
      await frames(tester);
      expect(await closed, false);
      expect(rewarded, 1);
      expect(interstitials, 0);
      expect(claims, 0);
    });
  }

  for (final probability in [0, 100]) {
    testWidgets('关闭按配置$probability%决定插屏，不发奖且重复点击只处理一次', (tester) async {
      await seed(probability: probability);
      final ad = Completer<bool>();
      final placements = <String>[];
      var claims = 0;
      PCRewardedAdService.instance.handler = (_) async =>
          throw StateError('Close must not request rewarded');
      PCInterstitialAdService.instance.handler = (placement) {
        placements.add(placement);
        return ad.future;
      };
      final context = await show(tester);
      final closed = context.tipShow2(
        PCAwardDialog(
          award: .02,
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      final close = find.byKey(const ValueKey('pcQuizCloseReward'));
      await tester.tap(close);
      await tester.tap(close, warnIfMissed: false);
      await frames(tester);
      if (probability == 100) {
        expect(placements, ['int']);
        expect(PCDialogCoordinator.instance.isPresenting, true);
        ad.complete(false);
        await frames(tester);
      } else {
        expect(placements, isEmpty);
      }
      expect(await closed, false);
      expect(claims, 0);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(PCDialogCoordinator.instance.isBusy, false);
    });
  }

  for (final claim in [true, false]) {
    testWidgets('${claim ? '领取激励' : '关闭插屏'}迟到回调不能退出后来打开的页面', (tester) async {
      await seed(probability: 100);
      final ad = Completer<bool>();
      var claims = 0;
      PCRewardedAdService.instance.handler = (_) => ad.future;
      PCInterstitialAdService.instance.handler = (_) => ad.future;
      final context = await show(tester);
      final navigator = Navigator.of(context);
      final closed = context.tipShow2(
        PCAwardDialog(
          award: 1,
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      await tester.tap(
        find.byKey(ValueKey(claim ? 'pcQuizClaimReward' : 'pcQuizCloseReward')),
      );
      await frames(tester, 100);
      navigator.pop(false);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('New page stays open')),
        ),
      );
      ad.complete(true);
      await frames(tester);
      expect(find.text('New page stays open'), findsOneWidget);
      expect(claims, 0);
      expect(await closed, false);
    });
  }

  testWidgets('奖励存储等待时打开其他页，成功回调只关闭原奖励路由', (tester) async {
    await seed();
    final saved = Completer<bool>();
    PCRewardedAdService.instance.handler = (_) async => true;
    final context = await show(tester);
    final navigator = Navigator.of(context);
    final closed = context.tipShow2(
      PCAwardDialog(award: 1, onClaim: () => saved.future),
    );
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester, 100);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New page stays open')),
      ),
    );
    saved.complete(true);
    await frames(tester);
    expect(find.text('New page stays open'), findsOneWidget);
    expect(await closed, true);
    expect(PCDialogCoordinator.instance.isBusy, false);
  });

  testWidgets('新用户答题奖励无AD角标，Claim和关闭都不调用广告', (tester) async {
    await seed(probability: 100);
    var rewarded = 0;
    var interstitials = 0;
    var claims = 0;
    PCRewardedAdService.instance.handler = (_) async {
      rewarded++;
      return false;
    };
    PCInterstitialAdService.instance.handler = (_) async {
      interstitials++;
      return true;
    };
    final context = await show(tester);
    for (final claim in [true, false]) {
      final closed = context.tipShow2(
        PCAwardDialog(
          award: 5,
          adsEnabled: false,
          showAdBadge: false,
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is PCImg && widget.name == 'pc_ad_icon',
        ),
        findsNothing,
      );
      await tester.tap(
        find.byKey(ValueKey(claim ? 'pcQuizClaimReward' : 'pcQuizCloseReward')),
      );
      await frames(tester);
      expect(await closed, claim);
    }
    expect(claims, 1);
    expect(rewarded, 0);
    expect(interstitials, 0);
  });

  for (final outcome in PCAdOutcome.values) {
    testWidgets('领奖激励${outcome.name}仅真实失败提示，取消不发奖也不补关闭插屏', (tester) async {
      await seed(probability: 100);
      var requests = 0, claims = 0, abandoned = 0, failures = 0, closeAds = 0;
      PCRewardedAdService.instance.bindOutcomeHandler((_) async {
        requests++;
        return outcome;
      });
      PCInterstitialAdService.instance.bindOutcomeHandler((_) async {
        closeAds++;
        return PCAdOutcome.success;
      });
      final context = await show(tester);
      final closed = context.tipShow2(
        PCAwardDialog(
          award: 1,
          onClaim: () async {
            claims++;
            return true;
          },
          onAbandon: () async => abandoned++,
          onClaimAdFailed: () async => failures++,
        ),
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
      await frames(tester);
      expect(requests, 1);
      expect(claims, outcome.isSuccess ? 1 : 0);
      expect(abandoned, outcome.isSuccess ? 0 : 1);
      expect(failures, outcome == PCAdOutcome.failed ? 1 : 0);
      if (outcome == PCAdOutcome.failed) {
        expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
        await tester.tap(find.text('Try Again').last);
        await frames(tester);
      }
      expect(await closed, outcome.isSuccess);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(closeAds, 0);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
    });
  }

  for (final throwsSave in [false, true]) {
    testWidgets('领奖广告成功后保存${throwsSave ? '异常' : '未完成'}不误报广告失败', (tester) async {
      await seed();
      var requests = 0, failures = 0;
      PCRewardedAdService.instance.bindOutcomeHandler((_) async {
        requests++;
        return PCAdOutcome.success;
      });
      final context = await show(tester);
      final closed = context.tipShow2(
        PCAwardDialog(
          award: 1,
          onClaim: () async {
            if (throwsSave) throw StateError('save unavailable');
            return false;
          },
          onClaimAdFailed: () async => failures++,
        ),
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
      await frames(tester);
      expect(find.byType(PCAwardDialog), findsOneWidget);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(requests, 1);
      expect(failures, 0);
      if (throwsSave) {
        expect(
          find.text('Unable to save progress. Please try again.'),
          findsOneWidget,
        );
        await frames(tester, 2600);
      }
      await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
      await frames(tester);
      expect(await closed, false);
      expect(requests, 1);
    });
  }

  testWidgets('金苹果入口已成功，Claim激励取消仅保留首笔，不弹失败或补关闭插屏', (tester) async {
    await seed(probability: 100);
    final interstitials = <String>[];
    final rewarded = <String>[];
    PCInterstitialAdService.instance.bindOutcomeHandler((placement) async {
      interstitials.add(placement);
      return PCAdOutcome.success;
    });
    PCRewardedAdService.instance.bindOutcomeHandler((placement) async {
      rewarded.add(placement);
      return PCAdOutcome.cancelled;
    });
    final rewards = PCHomeRewardController(random: Random(2));
    addTearDown(rewards.dispose);
    await show(tester, page: PChome(rewardController: rewards));
    final first = rewards.rewardAt(2)!;
    await tester.tap(find.byKey(const ValueKey('pcHomeBubble6')));
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    expect(rewards.gold, closeTo(10.25 + first.amount, .00001));
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(rewards.gold, closeTo(10.25 + first.amount, .00001));
    expect(interstitials, ['nkmdl_applebub_int']);
    expect(rewarded, ['asd_rv']);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('首页概率Claim插屏正常取消仍结算已满足入口条件的奖励', (tester) async {
    await seed(probability: 100);
    var requests = 0, claims = 0;
    PCInterstitialAdService.instance.bindOutcomeHandler((_) async {
      requests++;
      return PCAdOutcome.cancelled;
    });
    final context = await show(tester);
    final closed = context.tipShow2(
      PCAwardDialog(
        award: 1,
        claimAdPolicy: PCAwardClaimAdPolicy.probabilityInterstitial,
        onClaim: () async {
          claims++;
          return true;
        },
      ),
    );
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester);
    expect(await closed, true);
    expect(requests, 1);
    expect(claims, 1);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
  });

  for (final slot in [1, 2, -1]) {
    testWidgets('首页${slot < 0 ? '金苹果' : 'AD气泡$slot'}入口正常取消不发奖、不显示失败且释放入口', (
      tester,
    ) async {
      await seed();
      var requests = 0;
      Future<PCAdOutcome> cancel(String placement) async {
        requests++;
        expect(
          placement,
          slot < 0 ? 'nkmdl_applebub_int' : 'nkmdl_moneybub_getpop_rv',
        );
        return PCAdOutcome.cancelled;
      }

      PCRewardedAdService.instance.bindOutcomeHandler(cancel);
      PCInterstitialAdService.instance.bindOutcomeHandler(cancel);
      final rewards = PCHomeRewardController(random: Random(2));
      addTearDown(rewards.dispose);
      await show(tester, page: PChome(rewardController: rewards));
      final generation = rewards.generation;
      final values = rewards.amounts;
      final bubble = find.byKey(
        ValueKey(slot < 0 ? 'pcHomeBubble6' : 'pcHomeRewardBubble$slot'),
      );
      await tester.tap(bubble);
      await frames(tester);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(rewards.gold, 10.25);
      expect(rewards.amounts, values);
      expect(rewards.generation, generation);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
      await tester.tap(bubble);
      await frames(tester);
      expect(requests, 2, reason: '取消后可再次由用户点击原入口，后台不自动重试');
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    });
  }
}
