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
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigMotion.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_GradientText.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> seed({
    int level = 2,
    double? collected,
    int probability = 0,
  }) async {
    final amount = collected ?? [40.0, 3.0, 4.0][level];
    final today = DateTime.now();
    List<Map<String, dynamic>> ranges(int type, double first, double second) =>
        [
          {
            'first_number': 0,
            'end_number': type == 0 ? 50 : 5,
            'type': type,
            'prize': [first, first],
          },
          {
            'first_number': type == 0 ? 50 : 5,
            'end_number': type == 0 ? 100 : 10000,
            'type': type,
            'prize': [second, second],
          },
        ];
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_bg_music': false,
      'pc_pig_level': level,
      'pc_dollar_number': level == 0 ? amount : 100.0,
      'pc_quiz_diamonds': level == 1 ? amount : 0.0,
      'pc_quiz_gold': level == 2 ? amount : 0.0,
      'pc_pig_level_index': amount,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_account_id': '2***5532',
      PCPigProgress.diamondEnteredKey: today.toIso8601String(),
      PCPigProgress.diamondDeadlineKey: today
          .add(const Duration(days: 1))
          .toIso8601String(),
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': probability},
        ],
        'money_prize': ranges(0, 10, 5),
        'diamond_prize': ranges(1, 2, 1),
        'gold_prize': ranges(2, 1, .5),
      }),
    });
    PigsTabController.currentIndex.value = 0;
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
  }

  /// 每一帧都检查两种奖励界面互斥，不能只检查最终截图。
  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('UI frame failed: $error');
      expect(
        find.byType(PCQuizRewardAnimation).evaluate().isNotEmpty &&
            find.byType(PCAwardDialog).evaluate().isNotEmpty,
        false,
        reason: '到账动画完整退出前不能叠加获得弹窗',
      );
    }
  }

  Future<PCHomeRewardController> show(
    WidgetTester tester, {
    Future<void> Function()? onSync,
    Size size = const Size(375, 812),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final flow = PCHomeRewardController(
      random: Random(42),
      onSync: onSync ?? PCLocalProvider.instance.init,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(home: PChome(rewardController: flow)),
        ),
      ),
    );
    await frames(tester, 2600);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      flow.dispose();
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
      expect(PCDialogCoordinator.instance.isBusy, false);
    });
    return flow;
  }

  Future<double> savedAmount(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getDouble(
          ['pc_dollar_number', 'pc_quiz_diamonds', 'pc_quiz_gold'][level],
        ) ??
        0;
  }

  for (final level in [0, 1, 2]) {
    for (final size in const [
      Size(320, 568),
      Size(430, 932),
      Size(768, 1024),
    ]) {
      testWidgets('阶段$level在$size主猪底座显示对应缓存数量并实时刷新', (tester) async {
        await seed(level: level, collected: 3.25);
        await show(tester, size: size);
        final plaque = find.byKey(const ValueKey('pcHomePigBalance'));
        final number = find.descendant(
          of: plaque,
          matching: find.byType(PCGradientText),
        );
        expect(
          tester.widget<PCGradientText>(number).text,
          level == 0 ? r'$3.25' : '3.25',
        );
        final icons = tester.widgetList<PCImg>(
          find.descendant(of: plaque, matching: find.byType(PCImg)),
        );
        expect(icons.map((image) => image.name), switch (level) {
          1 => ['pc_stage_collect_diamond'],
          2 => ['pc_stage_collect_gold'],
          _ => isEmpty,
        });
        expect(
          tester.widget<PCPigMotion>(find.byKey(pcHomePigTargetKey)).jumpHeight,
          6,
        );
        final bounds = tester.getRect(plaque);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(
          ['pc_dollar_number', 'pc_quiz_diamonds', 'pc_quiz_gold'][level],
          6.75,
        );
        await prefs.setDouble('pc_pig_level_index', 6.75);
        await PCLocalProvider.instance.init();
        await frames(tester, 200);
        expect(
          tester.widget<PCGradientText>(number).text,
          level == 0 ? r'$6.75' : '6.75',
        );
      });
    }
  }

  for (final level in [0, 1, 2]) {
    final initial = [40.0, 3.0, 4.0][level];
    final first = [10.0, 2.0, 1.0][level];
    final second = [5.0, 1.0, .5][level];
    final credited = level == 2 ? second * 2 : second;
    for (final claimSucceeded in [true, false]) {
      testWidgets(
        '阶段$level金苹果入口插屏静默到账，Claim激励${claimSucceeded ? '成功发第二笔并播放动画' : '失败保留首笔且退出失败面板'}',
        (tester) async {
          // 概率为0也必须展示入口插屏，不能套用关闭时的概率。
          await seed(level: level, probability: 0);
          final entry = Completer<bool>();
          final claim = Completer<bool>();
          final interstitials = <String>[];
          final rewarded = <String>[];
          PCInterstitialAdService.instance.handler = (placement) {
            interstitials.add(placement);
            return entry.future;
          };
          PCRewardedAdService.instance.handler = (placement) {
            rewarded.add(placement);
            return claim.future;
          };
          final flow = await show(tester);
          final generation = flow.generation;
          final firstRewardId = flow.rewardAt(2)!.id;
          final bubble = find.byKey(const ValueKey('pcHomeBubble6'));
          await tester.tap(bubble);
          await tester.tap(bubble);
          await frames(tester, 100);
          expect(interstitials, ['nkmdl_applebub_int']);
          expect(rewarded, isEmpty);
          expect(find.byType(PCAwardDialog), findsNothing);
          expect(await savedAmount(level), initial);

          entry.complete(true);
          await frames(tester);
          expect(find.byType(PCAwardDialog), findsOneWidget);
          expect(find.byType(PCQuizRewardAnimation), findsNothing);
          expect(await savedAmount(level), initial + first);
          expect(flow.generation, generation + 1);
          final dialog = tester.widget<PCAwardDialog>(
            find.byType(PCAwardDialog),
          );
          expect(dialog.claimAdPolicy, PCAwardClaimAdPolicy.rewarded);
          expect(dialog.showAdBadge, true);
          expect(dialog.reward!.amount, second);
          expect(dialog.reward!.type.index, level);
          expect(dialog.reward!.id, isNot(firstRewardId));
          expect(
            find.descendant(
              of: find.byType(PCAwardDialog),
              matching: find.byWidgetPredicate(
                (widget) => widget is PCImg && widget.name == 'pc_ad_icon',
              ),
            ),
            findsOneWidget,
          );
          final claimButton = find.byKey(const ValueKey('pcQuizClaimReward'));
          await tester.tap(claimButton);
          await tester.tap(claimButton, warnIfMissed: false);
          await tester.tap(
            find.byKey(
              ValueKey(level == 2 ? 'pcAwardSingleClaim' : 'pcQuizCloseReward'),
            ),
            warnIfMissed: false,
          );
          await frames(tester, 100);
          expect(rewarded, ['asd_rv']);
          expect(interstitials, ['nkmdl_applebub_int']);
          expect(await savedAmount(level), initial + first);
          claim.complete(claimSucceeded);
          await frames(tester);
          if (claimSucceeded) {
            expect(await savedAmount(level), initial + first + credited);
            expect(flow.generation, generation + 2);
            expect(find.byType(PCAwardDialog), findsNothing);
            expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
            final effect = tester.widget<PCQuizRewardAnimation>(
              find.byType(PCQuizRewardAnimation),
            );
            expect(effect.reward.type.index, level);
            expect(effect.reward.amount, credited);
          } else {
            expect(await savedAmount(level), initial + first);
            expect(flow.generation, generation + 1);
            expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
            await tester.tap(find.text('Try Again').last);
            await frames(tester);
          }
          await frames(tester, 2400);
          expect(find.byType(PCAwardDialog), findsNothing);
          expect(find.byType(PCQuizRewardAnimation), findsNothing);
          expect(rewarded, ['asd_rv']);
          expect(interstitials, ['nkmdl_applebub_int']);
          expect(
            await savedAmount(level),
            initial + first + (claimSucceeded ? credited : 0),
          );
        },
      );
    }
  }

  for (final probability in [0, 100]) {
    testWidgets('金苹果关闭仅按$probability%播放插屏，保留首笔不发第二笔且不播放Claim激励', (
      tester,
    ) async {
      await seed(level: 1, probability: probability);
      final interstitials = <String>[];
      final rewarded = <String>[];
      final closing = Completer<bool>();
      PCInterstitialAdService.instance.handler = (placement) async {
        interstitials.add(placement);
        return placement == 'nkmdl_applebub_int' ? true : closing.future;
      };
      PCRewardedAdService.instance.handler = (placement) async {
        rewarded.add(placement);
        return true;
      };
      final flow = await show(tester);
      final generation = flow.generation;
      await tester.tap(find.byKey(const ValueKey('pcHomeBubble6')));
      await frames(tester);
      expect(await savedAmount(1), 5);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
      await tester.tap(
        find.byKey(const ValueKey('pcQuizCloseReward')),
        warnIfMissed: false,
      );
      await frames(tester, 100);
      expect(interstitials, [
        'nkmdl_applebub_int',
        if (probability == 100) 'nkmdl_applebub_getpop_int',
      ]);
      if (probability == 100) closing.complete(false);
      await frames(tester);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(rewarded, isEmpty);
      expect(await savedAmount(1), 5);
      expect(flow.generation, generation + 1);
    });
  }

  testWidgets('金苹果入口插屏失败不发奖，关闭失败面板不重试，入口随后可再次点击', (tester) async {
    await seed(probability: 100);
    final interstitials = <String>[];
    PCInterstitialAdService.instance.handler = (placement) async {
      interstitials.add(placement);
      return false;
    };
    PCRewardedAdService.instance.handler = (_) async =>
        throw StateError('金苹果入口不能请求激励');
    final flow = await show(tester);
    final generation = flow.generation;
    final bubble = find.byKey(const ValueKey('pcHomeBubble6'));
    await tester.tap(bubble);
    await frames(tester);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(await savedAmount(2), 4);
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(interstitials, ['nkmdl_applebub_int']);
    expect(flow.generation, generation);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    await tester.tap(bubble);
    await frames(tester);
    expect(interstitials, ['nkmdl_applebub_int', 'nkmdl_applebub_int']);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(await savedAmount(2), 4);
  });

  testWidgets('金苹果首笔现金达到100后Claim领取新配置钻石，只有第二笔有动画', (tester) async {
    await seed(level: 0, collected: 99);
    final interstitials = <String>[];
    final rewarded = <String>[];
    PCInterstitialAdService.instance.handler = (placement) async {
      interstitials.add(placement);
      return true;
    };
    PCRewardedAdService.instance.handler = (placement) async {
      rewarded.add(placement);
      return true;
    };
    final flow = await show(tester);
    final generation = flow.generation;
    await tester.tap(find.byKey(const ValueKey('pcHomeBubble6')));
    await frames(tester);
    expect(await savedAmount(0), 100);
    expect(await savedAmount(1), 0);
    expect(flow.level, 1);
    expect(flow.generation, generation + 1);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    final dialog = tester.widget<PCAwardDialog>(find.byType(PCAwardDialog));
    expect(dialog.reward!.type, PCQuizRewardType.diamond);
    expect(dialog.reward!.amount, 2);
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester);
    expect(interstitials, ['nkmdl_applebub_int']);
    expect(rewarded, ['asd_rv']);
    expect(await savedAmount(0), 100);
    expect(await savedAmount(1), 2);
    expect(flow.generation, generation + 2);
    expect(find.byType(PCAwardDialog), findsNothing);
    final effect = tester.widget<PCQuizRewardAnimation>(
      find.byType(PCQuizRewardAnimation),
    );
    expect(effect.reward.type, PCQuizRewardType.diamond);
    expect(effect.reward.amount, 2);
    await frames(tester, 2400);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(await savedAmount(1), 2);
  });

  for (final level in [0, 1, 2]) {
    for (final slot in [1, 2]) {
      final initial = [40.0, 3.0, 4.0][level];
      final first = [10.0, 2.0, 1.0][level];
      final second = [5.0, 1.0, .5][level];
      final credited = level == 2 ? second * 2 : second;
      final probability = slot == 1 ? 0 : 100;
      testWidgets('阶段$level AD气泡$slot激励后静默到账直接开获得框，Claim再到账并播放动画', (
        tester,
      ) async {
        await seed(level: level, probability: probability);
        final entry = Completer<bool>();
        final claim = Completer<bool>();
        final rewarded = <String>[];
        final interstitials = <String>[];
        PCRewardedAdService.instance.handler = (placement) {
          rewarded.add(placement);
          return rewarded.length == 1 ? entry.future : claim.future;
        };
        PCInterstitialAdService.instance.handler = (placement) {
          interstitials.add(placement);
          return claim.future;
        };
        final flow = await show(tester);
        final generation = flow.generation;
        final firstRewardId = flow.rewardAt(slot)!.id;
        final bubble = find.byKey(ValueKey('pcHomeRewardBubble$slot'));
        await tester.tap(bubble);
        await tester.tap(bubble);
        await frames(tester, 100);
        expect(rewarded, ['nkmdl_moneybub_getpop_rv']);
        expect(await savedAmount(level), initial);
        expect(find.byType(PCAwardDialog), findsNothing);
        expect(find.byType(PCQuizRewardAnimation), findsNothing);

        entry.complete(true);
        await frames(tester, 100);
        expect(await savedAmount(level), initial + first);
        expect(flow.generation, generation + 1);
        expect(find.byType(PCQuizRewardAnimation), findsNothing);
        expect(find.byType(PCAwardDialog), findsOneWidget);
        final dialog = tester.widget<PCAwardDialog>(find.byType(PCAwardDialog));
        expect(dialog.reward!.amount, second);
        expect(dialog.reward!.type.index, level);
        expect(dialog.reward!.id, isNot(firstRewardId));
        expect(
          find.descendant(
            of: find.byType(PCAwardDialog),
            matching: find.byWidgetPredicate(
              (widget) => widget is PCImg && widget.name == 'pc_ad_icon',
            ),
          ),
          level == 0 ? findsNothing : findsOneWidget,
        );

        final claimButton = find.byKey(const ValueKey('pcQuizClaimReward'));
        await tester.tap(claimButton);
        await tester.tap(claimButton, warnIfMissed: false);
        await frames(tester, 100);
        expect(rewarded, [
          'nkmdl_moneybub_getpop_rv',
          if (level != 0) 'nkmdl_moneybub_getpop_rv',
        ]);
        if (level != 0) {
          expect(interstitials, isEmpty);
          expect(await savedAmount(level), initial + first);
          claim.complete(true);
          await frames(tester);
        } else if (probability == 100) {
          expect(interstitials, ['nkmdl_moneybub_getpop_int']);
          expect(await savedAmount(level), initial + first);
          await tester.tap(
            find.byKey(const ValueKey('pcQuizCloseReward')),
            warnIfMissed: false,
          );
          expect(interstitials, ['nkmdl_moneybub_getpop_int']);
          claim.complete(true);
          await frames(tester, 600);
        } else {
          expect(interstitials, isEmpty);
          await frames(tester, 500);
        }
        expect(await savedAmount(level), initial + first + credited);
        expect(flow.generation, generation + 2);
        expect(find.byType(PCAwardDialog), findsNothing);
        expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
        final secondEffect = tester.widget<PCQuizRewardAnimation>(
          find.byType(PCQuizRewardAnimation),
        );
        expect(secondEffect.reward.amount, credited);
        await frames(tester, 2400);
        expect(find.byType(PCAwardDialog), findsNothing);
        expect(find.byType(PCQuizRewardAnimation), findsNothing);
        expect(await savedAmount(level), initial + first + credited);
        expect(flow.generation, generation + 2);
      });
    }
  }

  testWidgets('首笔现金达到100后获得弹窗读取新钻石阶段，关闭只保留首笔现金', (tester) async {
    await seed(level: 0, collected: 99);
    PCRewardedAdService.instance.handler = (_) async => true;
    final flow = await show(tester);
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble1')));
    await frames(tester, 100);
    expect(await savedAmount(0), 100);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    final dialog = tester.widget<PCAwardDialog>(find.byType(PCAwardDialog));
    expect(flow.level, 1);
    expect(dialog.reward!.type, PCQuizRewardType.diamond);
    expect(dialog.reward!.amount, 2);
    expect(await savedAmount(1), 0);
    await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
    await frames(tester);
    expect(await savedAmount(0), 100);
    expect(await savedAmount(1), 0);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
  });

  for (final probability in [0, 100]) {
    testWidgets('获得弹窗关闭按$probability%插屏，保留首笔但不发第二笔或补弹', (tester) async {
      await seed(level: 1, probability: probability);
      PCRewardedAdService.instance.handler = (_) async => true;
      final interstitials = <String>[];
      final close = Completer<bool>();
      PCInterstitialAdService.instance.handler = (placement) {
        interstitials.add(placement);
        return close.future;
      };
      final flow = await show(tester);
      final generation = flow.generation;
      await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble2')));
      await frames(tester, 600);
      expect(await savedAmount(1), 5);
      expect(flow.generation, generation + 1);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(find.byType(PCAwardDialog), findsOneWidget);
      final closeButton = find.byKey(const ValueKey('pcQuizCloseReward'));
      await tester.tap(closeButton);
      await tester.tap(closeButton, warnIfMissed: false);
      await frames(tester, 100);
      if (probability == 100) {
        expect(interstitials, ['nkmdl_moneybub_getpop_int']);
        expect(await savedAmount(1), 5);
        close.complete(false);
      } else {
        expect(interstitials, isEmpty);
      }
      await frames(tester, 2600);
      expect(await savedAmount(1), 5);
      expect(flow.generation, generation + 1);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(find.byType(PCAwardDialog), findsNothing);
      PigsTabController.currentIndex.value = 1;
      await frames(tester, 100);
      PigsTabController.currentIndex.value = 0;
      await frames(tester, 1000);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
    });
  }

  for (final slot in [1, 2]) {
    testWidgets('AD气泡$slot入口失败不发任何奖励、不播放动画、不刷新气泡配置', (tester) async {
      await seed(probability: 100);
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
      final flow = await show(tester);
      final generation = flow.generation;
      final amounts = flow.amounts;
      await tester.tap(find.byKey(ValueKey('pcHomeRewardBubble$slot')));
      await frames(tester);
      expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(await savedAmount(2), 4);
      expect(flow.amounts, amounts);
      expect(flow.generation, generation);
      await tester.tap(find.text('Try Again').last);
      await frames(tester, 2600);
      expect(rewarded, 1);
      expect(interstitials, 0);
      expect(await savedAmount(2), 4);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
    });
  }

  for (final sameFrame in [false, true]) {
    testWidgets('首次到账同步期间${sameFrame ? '同帧切离再返回' : '切Tab后返回'}保留首笔且不补获得框', (
      tester,
    ) async {
      await seed();
      var rewarded = 0;
      PCRewardedAdService.instance.handler = (_) async {
        rewarded++;
        return true;
      };
      final sync = Completer<void>();
      addTearDown(() {
        if (!sync.isCompleted) sync.complete();
      });
      final flow = await show(
        tester,
        onSync: () async {
          await PCLocalProvider.instance.init();
          await sync.future;
        },
      );
      final generation = flow.generation;
      await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble1')));
      await frames(tester, 100);
      expect(await savedAmount(2), 5);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(find.byType(PCAwardDialog), findsNothing);
      PigsTabController.currentIndex.value = 1;
      if (!sameFrame) {
        await frames(tester, 200);
        expect(find.byType(PCQuizRewardAnimation), findsNothing);
        expect(find.byType(PCAwardDialog), findsNothing);
      }
      // 快速切页分支刻意不pump，不能仅凭回调时的currentIndex恢复旧流程。
      PigsTabController.currentIndex.value = 0;
      sync.complete();
      await frames(tester, 2600);
      expect(await savedAmount(2), 5);
      expect(flow.generation, generation + 1);
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(PCDialogCoordinator.instance.isBusy, false);
      expect(rewarded, 1);
    });
  }

  testWidgets('Claim概率插屏失败仍发已满足入口条件的第二笔奖励', (tester) async {
    await seed(probability: 100);
    PCRewardedAdService.instance.handler = (_) async => true;
    PCInterstitialAdService.instance.handler = (_) async => false;
    final flow = await show(tester);
    final generation = flow.generation;
    await tester.tap(find.byKey(const ValueKey('pcHomeRewardBubble1')));
    await frames(tester, 600);
    expect(await savedAmount(2), 5);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcAwardSingleClaim')));
    await frames(tester, 2600);
    expect(await savedAmount(2), 5.5);
    expect(flow.generation, generation + 2);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
  });
}
