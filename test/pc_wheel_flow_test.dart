import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCWheelNoChanceDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCOtherDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWheel.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigWheelPage.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelOpportunityStore.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void wheelWidgets(String name, WidgetTesterCallback callback) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await callback(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  void seed(int level, double amount, {int spins = 1}) =>
      SharedPreferences.setMockInitialValues({
        'pc_new_guide_end': true,
        'pc_pig_upgrade_seen_level_v1': 2,
        'pc_pig_level': level,
        'pc_dollar_number': level == 0 ? amount : 100.0,
        'pc_quiz_diamonds': level == 1
            ? amount
            : level == 2
            ? 20.0
            : 0.0,
        'pc_quiz_gold': level == 2 ? amount : 0.0,
        'pc_wheel_number': spins,
        PCWheelOpportunityStore.storageKey: jsonEncode({
          'balance': max(0, spins),
          'lastGrantDay': PCWheelOpportunityStore.dayKey(DateTime.now()),
          'quizAwardThrough': 0,
          'wheelAppliedId': '',
        }),
      });

  for (final item in [
    (0, 10.0),
    (0, 55.0),
    (0, 92.0),
    (0, 99.99),
    (1, 4.9),
    (1, 6.0),
    (1, 11.0),
    (1, 17.0),
    (1, 19.99),
    (2, 4.9),
    (2, 5.2),
    (2, 9.99),
  ]) {
    test('阶段${item.$1}数量${item.$2}只落合法区域，奖励按当前缓存配置且钻石可越过20目标', () async {
      for (var i = 0; i < 5; i++) {
        seed(item.$1, item.$2);
        final wheel = PCWheelController(random: Random(i));
        expect(await wheel.start(), PCWheelStartResult.started);
        final turn = wheel.pending!;
        final config = PCNumberHelpers();
        final rows = item.$1 == 0
            ? config.model.moneyPrize
            : item.$1 == 1
            ? config.model.diamondPrize
            : config.model.goldPrize;
        final row = rows.firstWhere(
          (r) => item.$2 >= r.firstNumber && item.$2 < r.endNumber,
        );
        expect(
          turn.segment,
          isIn(
            item.$1 == 0
                ? PCWheelController.cashSegments
                : PCWheelController.bagSegments,
          ),
        );
        expect(turn.reward.type.index, item.$1);
        expect(turn.reward.amount, greaterThan(0));
        expect(turn.reward.amount, lessThanOrEqualTo(row.prize.last));
        if (item.$1 == 0 || row.endNumber < (item.$1 == 1 ? 20 : 10)) {
          expect(
            item.$2 + turn.reward.amount,
            lessThanOrEqualTo(row.endNumber + .00001),
          );
        }
        expect(wheel.spins, 0);
        await wheel.claim();
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getDouble(
            item.$1 == 0
                ? 'pc_dollar_number'
                : item.$1 == 1
                ? 'pc_quiz_diamonds'
                : 'pc_quiz_gold',
          ),
          closeTo(item.$2 + turn.reward.amount, .00001),
        );
        if (item.$1 != 0) expect(prefs.getDouble('pc_dollar_number'), 100.0);
        expect(await wheel.claim(), isNull);
        wheel.dispose();
      }
    });
  }

  test('连点只扣一次，待领奖励冷启动不重抽、不再扣次数，重复Claim只入账一次', () async {
    seed(1, 7.25, spins: 2);
    final first = PCWheelController(random: Random(1));
    final started = await Future.wait([first.start(), first.start()]);
    expect(
      started,
      containsAll([PCWheelStartResult.started, PCWheelStartResult.busy]),
    );
    final turn = first.pending!;
    expect(first.spins, 1);
    first.dispose();
    final restored = PCWheelController(random: Random(9));
    await restored.load();
    expect(restored.pending!.toJson(), turn.toJson());
    expect(await restored.start(), PCWheelStartResult.pending);
    expect(restored.spins, 1);
    final claims = await Future.wait([restored.claim(), restored.claim()]);
    expect(claims.whereType<PCQuizReward>().length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble('pc_quiz_diamonds'),
      closeTo(7.25 + turn.reward.amount, .00001),
    );
    expect(prefs.getString(PCWheelController.storageKey), isNull);
    restored.dispose();
  });

  test('金砖激励双倍结算复用原奖励 ID，到账数据与存储金额一致', () async {
    seed(2, 9.9);
    final wheel = PCWheelController(random: Random(1));
    addTearDown(wheel.dispose);
    expect(await wheel.start(), PCWheelStartResult.started);
    final pending = wheel.pending!.reward;
    expect(
      await wheel.claim(expectedRewardId: 'old', doubleGold: true),
      isNull,
    );
    final reward = await wheel.claim(
      expectedRewardId: pending.id,
      doubleGold: true,
    );
    expect(reward?.id, pending.id);
    expect(reward?.amount, closeTo(pending.amount * 2, .00001));
    expect(await wheel.claim(expectedRewardId: pending.id), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getDouble('pc_quiz_gold'),
      closeTo(9.9 + reward!.amount, .00001),
    );
    expect(prefs.getDouble('pc_dollar_number'), 100);
    expect(wheel.spins, 0);
  });

  test('无次数不转，金砖集满仍可正常扣次转盘领奖', () async {
    for (final count in [0, -1]) {
      seed(0, 25.0, spins: count);
      final wheel = PCWheelController();
      expect(await wheel.start(), PCWheelStartResult.noSpins);
      expect(wheel.spins, max(0, count));
      expect(wheel.pending, isNull);
      wheel.dispose();
    }
    seed(2, 10.0, spins: 3);
    final wheel = PCWheelController();
    expect(await wheel.start(), PCWheelStartResult.started);
    expect(wheel.spins, 2);
    expect(wheel.pending!.reward.amount, inInclusiveRange(.01, .02));
    await wheel.claim();
    expect(wheel.gold, greaterThan(10));
    wheel.dispose();
  });

  test('广告失败放弃待奖不发奖不退机会，切页及冷启动不能恢复', () async {
    seed(2, 10.0, spins: 3);
    final wheel = PCWheelController(random: Random(1));
    await wheel.start();
    final rewardId = wheel.pending!.reward.id;
    expect(wheel.spins, 2);
    expect(await wheel.discardPending(expectedRewardId: rewardId), true);
    expect(wheel.pending, isNull);
    expect(wheel.spins, 2);
    expect(wheel.gold, 10.0);
    await wheel.refreshDailyOpportunities();
    expect(wheel.pending, isNull);
    wheel.dispose();

    final restored = PCWheelController();
    await restored.load();
    final prefs = await SharedPreferences.getInstance();
    expect(restored.pending, isNull);
    expect(restored.spins, 2);
    expect(restored.gold, 10.0);
    expect(prefs.getString(PCWheelController.storageKey), isNull);
    expect(prefs.getString(PCWheelController.journalKey), isNull);
    expect(await restored.claim(expectedRewardId: rewardId), isNull);
    restored.dispose();
  });

  test('旧奖励的延迟失败或Claim不清除也不领取新转盘结果', () async {
    seed(1, 7.25, spins: 3);
    final wheel = PCWheelController(random: Random(1));
    await wheel.start();
    final oldId = wheel.pending!.reward.id;
    expect(await wheel.discardPending(expectedRewardId: 'old_dialog'), false);
    expect(wheel.pending!.reward.id, oldId);
    await wheel.discardPending(expectedRewardId: oldId);
    expect(await wheel.start(), PCWheelStartResult.started);
    final next = wheel.pending!;
    expect(next.reward.id, isNot(oldId));
    expect(await wheel.discardPending(expectedRewardId: oldId), false);
    expect(await wheel.claim(expectedRewardId: oldId), isNull);
    expect(wheel.pending!.toJson(), next.toJson());
    expect(wheel.diamonds, 7.25);
    expect(wheel.spins, 1);
    expect(
      (await wheel.claim(expectedRewardId: next.reward.id))?.toJson(),
      next.reward.toJson(),
    );
    expect(wheel.diamonds, closeTo(7.25 + next.reward.amount, .00001));
    wheel.dispose();
  });

  test('关闭与Tab刷新及新转动并发，旧奖励不能被恢复或误删新结果', () async {
    seed(2, 10.0, spins: 3);
    final wheel = PCWheelController(random: Random(1));
    final staleTab = PCWheelController();
    await wheel.start();
    await staleTab.load();
    final oldId = wheel.pending!.reward.id;

    final close = wheel.discardPending(expectedRewardId: oldId);
    final tabRefresh = staleTab.refreshDailyOpportunities();
    final nextSpin = wheel.start();
    expect(await close, true);
    await tabRefresh;
    expect(await nextSpin, PCWheelStartResult.started);
    final next = wheel.pending!;
    expect(next.reward.id, isNot(oldId));
    expect(wheel.spins, 1);
    expect(wheel.gold, 10.0);

    // 原路由稍后再结束，不能把它的旧结果写回，也不能放弃新一笔。
    expect(await staleTab.discardPending(expectedRewardId: oldId), false);
    expect(await staleTab.claim(expectedRewardId: oldId), isNull);
    await wheel.refreshDailyOpportunities();
    expect(wheel.pending!.toJson(), next.toJson());
    expect(wheel.spins, 1);
    expect(wheel.gold, 10.0);
    wheel.dispose();
    staleTab.dispose();

    final restored = PCWheelController();
    await restored.load();
    expect(restored.pending!.toJson(), next.toJson());
    expect(restored.spins, 1);
    restored.dispose();
  });

  test('关闭持久化尚未结束即销毁页面，冷启仍丢弃该奖励且不退机会', () async {
    seed(1, 7.25, spins: 2);
    final wheel = PCWheelController(random: Random(1));
    await wheel.start();
    final id = wheel.pending!.reward.id;
    final close = wheel.discardPending(expectedRewardId: id);
    wheel.dispose();
    expect(await close, true);

    final restored = PCWheelController();
    await restored.load();
    expect(restored.pending, isNull);
    expect(restored.spins, 1);
    expect(restored.diamonds, 7.25);
    expect(await restored.claim(expectedRewardId: id), isNull);
    restored.dispose();
  });

  test('关闭后跨午夜刷新只增加每日机会，不恢复或结算旧奖励', () async {
    seed(2, 10.0, spins: 2);
    var now = DateTime.now();
    final wheel = PCWheelController(random: Random(1), now: () => now);
    await wheel.start();
    final id = wheel.pending!.reward.id;
    await wheel.discardPending(expectedRewardId: id);
    now = DateTime(now.year, now.month, now.day + 1);
    await wheel.refreshDailyOpportunities();
    await wheel.refreshDailyOpportunities();
    expect(wheel.pending, isNull);
    expect(wheel.spins, 4);
    expect(wheel.gold, 10.0);
    wheel.dispose();

    final restored = PCWheelController(now: () => now);
    await restored.load();
    expect(restored.pending, isNull);
    expect(restored.spins, 4);
    expect(restored.gold, 10.0);
    expect(await restored.claim(expectedRewardId: id), isNull);
    restored.dispose();
  });

  test('放弃日志中断后重放仅删除原奖励，不恢复或重复退款', () async {
    seed(1, 7.25, spins: 2);
    final wheel = PCWheelController(random: Random(1));
    await wheel.start();
    final id = wheel.pending!.reward.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCWheelController.journalKey,
      jsonEncode({'action': 'discard', 'rewardId': id}),
    );
    wheel.dispose();
    for (var i = 0; i < 2; i++) {
      final restored = PCWheelController();
      await restored.load();
      expect(restored.pending, isNull);
      expect(restored.spins, 1);
      expect(restored.diamonds, 7.25);
      expect(prefs.getString(PCWheelController.journalKey), isNull);
      restored.dispose();
    }
  });

  test('旧放弃日志不能删除已存在的新奖励', () async {
    seed(1, 7.25, spins: 2);
    final wheel = PCWheelController(random: Random(1));
    await wheel.start();
    final next = wheel.pending!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCWheelController.journalKey,
      jsonEncode({'action': 'discard', 'rewardId': 'already_discarded'}),
    );
    wheel.dispose();
    final restored = PCWheelController();
    await restored.load();
    expect(restored.pending!.toJson(), next.toJson());
    expect(restored.spins, 1);
    expect(restored.diamonds, 7.25);
    expect(prefs.getString(PCWheelController.journalKey), isNull);
    restored.dispose();
  });

  test('放弃与其他控制器的延迟Claim共用事务，失败奖励不得入账', () async {
    seed(1, 7.25, spins: 2);
    final wheel = PCWheelController(random: Random(1));
    final stale = PCWheelController();
    await wheel.start();
    await stale.load();
    final id = wheel.pending!.reward.id;
    final results = await Future.wait<Object?>([
      wheel.discardPending(expectedRewardId: id),
      stale.claim(expectedRewardId: id),
    ]);
    expect(results, [true, null]);
    expect(wheel.diamonds, 7.25);
    expect(wheel.spins, 1);
    await stale.refreshDailyOpportunities();
    expect(stale.pending, isNull);
    wheel.dispose();
    stale.dispose();
  });

  test('恢复扣次和领奖日志采用目标值，重启不重复扣次或发钻石', () async {
    seed(1, 6.0, spins: 2);
    final prefs = await SharedPreferences.getInstance();
    const turn = PCWheelTurn(
      segment: 3,
      spinsAfter: 1,
      reward: PCQuizReward(
        id: 'wheel_interrupted',
        type: PCQuizRewardType.diamond,
        amount: 1.5,
        questionIndex: -1,
      ),
    );
    await prefs.setString(
      PCWheelController.journalKey,
      jsonEncode({'action': 'start', 'turn': turn.toJson()}),
    );
    final wheel = PCWheelController();
    await wheel.load();
    expect(wheel.spins, 1);
    expect(wheel.pending!.reward.id, 'wheel_interrupted');
    await prefs.setString(
      PCWheelController.journalKey,
      jsonEncode({
        'action': 'claim',
        'rewardId': 'wheel_interrupted',
        'diamondsAfter': 7.5,
        'goldAfter': 0.0,
      }),
    );
    wheel.dispose();
    for (var i = 0; i < 2; i++) {
      final restored = PCWheelController();
      await restored.load();
      expect(restored.pending, isNull);
      expect(restored.spins, 1);
      expect(prefs.getDouble('pc_quiz_diamonds'), 7.5);
      restored.dispose();
    }
  });

  test('常驻答题页在转盘领取后按新数量取档，旧题目快照不恢复已用转盘次数', () async {
    seed(1, 4.9);
    final quiz = PCQuizController(random: Random(1));
    await quiz.load();
    final wheel = PCWheelController(random: Random(1));
    await wheel.start();
    expect(wheel.pending!.reward.amount, .1);
    await wheel.claim();
    expect(quiz.diamonds, 5.0);
    final reward = await quiz.answer(correct: true);
    expect(reward!.amount, inInclusiveRange(1, 2));
    await quiz.refreshBalance();
    expect(wheel.spins, 0);
    quiz.dispose();
    wheel.dispose();
  });

  for (final size in const [Size(320, 568), Size(430, 932)]) {
    wheelWidgets('次数不足弹窗在$size内完整展示，Get By Quiz只关闭并切答题', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      seed(0, 45.0, spins: 0);
      final provider = PCLocalProvider.instance;
      await provider.init();
      final flow = PCWheelController();
      PigsTabController.switchTo(2);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, child) =>
                MaterialApp(home: PCWheel(controller: flow, active: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('pcWheelGoButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PCWheelNoChanceDialog), findsOneWidget);
      final button = find.byType(PCGreenDialogButton);
      expect(tester.getRect(button).bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PCWheelNoChanceDialog), findsNothing);
      expect(PigsTabController.currentIndex.value, 1);
      expect(flow.spins, 0);
      expect(flow.pending, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      flow.dispose();
    });
  }

  wheelWidgets('转盘动画结束前不弹奖励，GO连点不重复扣次，指针停在合法分区中心', (tester) async {
    seed(1, 7.25, spins: 2);
    final provider = PCLocalProvider.instance;
    await provider.init();
    final flow = PCWheelController(random: Random(1));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) =>
              MaterialApp(home: PCWheel(controller: flow, active: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final go = find.byKey(const ValueKey('pcWheelGoButton'));
    await tester.tap(go);
    await tester.pump();
    await tester.pump(); // 扣次数的异步写入结束后，从这一帧开始转盘计时。
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<ParticleButton>(go).enabled, false);
    expect(flow.spins, 1);
    expect(find.byType(PCAwardDialog), findsNothing);
    await tester.pump(const Duration(milliseconds: 799));
    expect(find.byType(PCAwardDialog), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PCAwardDialog), findsOneWidget);
    expect(flow.pending!.segment, isIn(PCWheelController.bagSegments));
    final rotation = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(PCPigWheelPage),
            matching: find.byType(Transform),
          ),
        )
        .first
        .transform;
    final actual = atan2(rotation.entry(1, 0), rotation.entry(0, 0));
    expect(cos(actual), closeTo(cos(-flow.pending!.segment * pi / 4), .00001));
    expect(sin(actual), closeTo(sin(-flow.pending!.segment * pi / 4), .00001));
    expect(provider.pc_pig_level_index, 7.25);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    flow.dispose();
  });
}
