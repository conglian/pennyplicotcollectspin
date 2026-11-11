import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeDebugController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelOpportunityStore.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  late SharedPreferences prefs;
  late PCWithdrawalController withdrawal;
  late PCHomeDebugController debug;
  late DateTime now;
  var synced = 0;

  Future<void> setup(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    now = DateTime.now();
    synced = 0;
    await PCNumberHelpers().pc_initNumberModel(preferences: prefs);
    withdrawal = PCWithdrawalController(
      preferences: prefs,
      now: () => now,
      scheduleMidnightTimer: false,
    );
    addTearDown(withdrawal.dispose);
    debug = PCHomeDebugController(
      preferences: prefs,
      withdrawal: withdrawal,
      now: () => now,
      onSync: () async => synced++,
    );
  }

  Map<String, Object> goldValues() => {
    'pc_dollar_number': 149.77,
    'pc_pig_level': 2,
    'pc_pig_level_index': 12.1,
    'pc_quiz_diamonds': 4.5,
    'pc_quiz_gold': 12.1,
    'pc_domand_number': 4,
    'pc_zhuan_number': 12,
    'pc_pig_upgrade_seen_level_v1': 2,
    'pc_wheel_number': 6,
    PCQuizController.storageKey: jsonEncode({
      'questionIndex': 7,
      'correctCount': 11,
      'diamonds': 4.5,
      'gold': 12.1,
      'openedMilestones': [1],
    }),
  };

  test('绝对值可增加和调低，所有阶段镜像及常驻答题页保持一致', () async {
    await setup(goldValues());
    final quiz = PCQuizController(random: Random(1));
    addTearDown(quiz.dispose);
    await quiz.load();
    var updates = 0;
    quiz.addListener(() => updates++);

    final changed = await debug.apply(
      cash: 3.456,
      diamonds: 1.234,
      gold: 2.346,
    );
    expect(changed.cash, 3.46);
    expect(changed.diamonds, 1.23);
    expect(changed.gold, 2.35);
    expect(changed.pigLevel, 2); // 已升级的猪不因调低余额降级。
    expect(quiz.balance, 3.46);
    expect(quiz.diamonds, 1.23);
    expect(quiz.gold, 2.35);
    expect(updates, greaterThan(0));
    expect(prefs.getDouble('pc_pig_level_index'), 2.35);
    expect(prefs.getInt('pc_domand_number'), 1);
    expect(prefs.getInt('pc_zhuan_number'), 2);
    expect(quiz.questionIndex, 7);
    expect(quiz.correctCount, 11);
    expect(quiz.openedMilestones, {1});
    expect(synced, 1);

    // 下一次常驻答题页同步、真实答题和冷启动均不能用旧max把数量恢复成12.1。
    await quiz.refreshBalance();
    expect(quiz.gold, 2.35);
    final reward = await quiz.answer(correct: true);
    expect(reward, isNotNull);
    await quiz.claim(expectedRewardId: reward!.id);
    expect(quiz.gold, closeTo(2.35 + reward.amount, .000001));
    final restoredQuiz = PCQuizController();
    addTearDown(restoredQuiz.dispose);
    await restoredQuiz.load();
    expect(restoredQuiz.gold, quiz.gold);
    expect(restoredQuiz.diamonds, 1.23);
    expect(restoredQuiz.balance, 3.46);
  });

  test('只填一项其余字段保持，零值可以精确清空，不改转盘机会', () async {
    await setup(goldValues());
    await debug.apply(diamonds: 0);
    expect(prefs.getDouble('pc_quiz_diamonds'), 0);
    expect(prefs.getDouble('pc_dollar_number'), 149.77);
    expect(prefs.getDouble('pc_quiz_gold'), 12.1);
    expect(prefs.getInt('pc_wheel_number'), 6);
    await debug.apply(gold: 0, cash: 0);
    final restored = await debug.read();
    expect(restored.gold, 0);
    expect(restored.cash, 0);
    expect(restored.diamonds, 0);
    expect(restored.pigLevel, 2);
    expect(prefs.getDouble('pc_pig_level_index'), 0);
  });

  test('常驻转盘从新数量取奖，奖励只累加到调整后的金砖，不复活旧数量', () async {
    await setup(goldValues());
    final wheel = PCWheelController(now: () => now, random: Random(3));
    addTearDown(wheel.dispose);
    await wheel.load();
    await debug.apply(gold: 1.5);
    expect(wheel.gold, 1.5);
    expect(await wheel.start(), PCWheelStartResult.started);
    final reward = wheel.pending!.reward;
    expect(reward.amount, inInclusiveRange(1, 2));
    await wheel.claim(expectedRewardId: reward.id);
    expect(wheel.gold, closeTo(1.5 + reward.amount, .000001));
    expect(prefs.getDouble('pc_dollar_number'), 149.77);
  });

  test('美元达到提现门槛按现有规则升级，钻石超过20当天不提前升级金猪', () async {
    await setup({'pc_dollar_number': 15.0});
    final diamond = await debug.apply(cash: 100);
    expect(diamond.pigLevel, 1);
    expect(withdrawal.next?.kind, PCWithdrawalPromptKind.diamondUpgrade);
    expect(PCPigProgress.diamondDeadline(prefs), isNull);
    final overTarget = await debug.apply(diamonds: 23.5);
    final deadline = PCPigProgress.diamondDeadline(prefs)!;
    expect(deadline.isAfter(now), isTrue);
    expect(overTarget.pigLevel, 1);
    expect(overTarget.diamonds, 23.5);
    expect(
      prefs.getString(PCPigProgress.diamondDeadlineKey),
      deadline.toIso8601String(),
    );
    now = deadline;
    await withdrawal.refresh();
    expect(withdrawal.pigLevel, 2);
  });

  test('真实排队名次和总人数同步，第一名转提现任务，重开继续该任务', () async {
    await setup(goldValues());
    await debug.read();
    await debug.apply(queueRank: 500);
    expect(withdrawal.queueRank, 500);
    expect(withdrawal.queueTotal, 500);
    expect(prefs.getInt('pc_current_ranking'), 500);
    expect(prefs.getInt('pc_all_ranking'), 500);
    expect(withdrawal.stage, PCWithdrawalStage.queue);

    final first = await debug.apply(queueRank: 1);
    expect(first.queueRank, 1);
    expect(withdrawal.stage, PCWithdrawalStage.lastStep);
    expect(
      withdrawal.pending.any((p) => p.kind == PCWithdrawalPromptKind.queue),
      isFalse,
    );
    expect(withdrawal.next?.kind, PCWithdrawalPromptKind.lastStep);
    final restored = PCWithdrawalController(
      preferences: prefs,
      now: () => now,
      scheduleMidnightTimer: false,
    );
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.queueRank, 1);
    expect(restored.stage, PCWithdrawalStage.lastStep);
    expect(restored.next?.kind, PCWithdrawalPromptKind.lastStep);
  });

  test('提前设置名次不改变猪阶段，后续正常进入队列时使用预设并保存任务进度', () async {
    await setup({'pc_dollar_number': 10.0});
    final before = await debug.apply(queueRank: 8);
    expect(before.pigLevel, 0);
    expect(withdrawal.stage, PCWithdrawalStage.insufficient);
    expect(withdrawal.pending, isEmpty);
    expect(prefs.getInt('pc_current_ranking'), 8);
    await debug.apply(gold: 10);
    expect(withdrawal.pigLevel, 2);
    expect(withdrawal.queueRank, 8);
    await debug.apply(queueRank: 1);
    final quiz = PCQuizController();
    addTearDown(quiz.dispose);
    await quiz.load();
    await quiz.answer(correct: true);
    await withdrawal.refresh();
    expect(withdrawal.taskProgress, 1);
    await debug.apply(gold: 11);
    expect(withdrawal.taskProgress, 1);
  });

  test('金砖调低后清除不适用的排队提示，重新达到门槛保留原排名', () async {
    await setup(goldValues());
    await debug.apply(queueRank: 25);
    expect(withdrawal.next?.kind, PCWithdrawalPromptKind.queue);
    await debug.apply(gold: 2);
    expect(withdrawal.stage, PCWithdrawalStage.releasing);
    expect(
      withdrawal.pending.any((p) => p.kind == PCWithdrawalPromptKind.queue),
      isFalse,
    );
    await debug.apply(gold: 10);
    expect(withdrawal.stage, PCWithdrawalStage.queue);
    expect(withdrawal.queueRank, 25);
    expect(withdrawal.next?.kind, PCWithdrawalPromptKind.queue);
  });

  test('调试次数以账本为准，可调高及清零，保留防重字段和待奖，同日不补发隔天加3', () async {
    await setup(goldValues());
    final wheel = PCWheelController(now: () => now);
    addTearDown(wheel.dispose);
    await wheel.load();
    await wheel.start();
    final rewardId = wheel.pending!.reward.id;
    final oldLedger =
        jsonDecode(prefs.getString(PCWheelOpportunityStore.storageKey)!) as Map;
    final oldPending = prefs.getString(PCWheelController.storageKey);

    final changed = await debug.apply(wheelChances: 20);
    expect(changed.wheelChances, 20);
    expect(wheel.spins, 20);
    final newLedger =
        jsonDecode(prefs.getString(PCWheelOpportunityStore.storageKey)!) as Map;
    expect(newLedger, {...oldLedger, 'balance': 20});
    expect(prefs.getString(PCWheelController.storageKey), oldPending);
    expect(wheel.pending?.reward.id, rewardId);
    await wheel.refreshDailyOpportunities();
    expect(wheel.spins, 20);

    await debug.apply(wheelChances: 0);
    expect(wheel.spins, 0);
    await debug.apply(cash: 135);
    expect(wheel.spins, 0); // 未填写次数保留0，不能被旧镜像补回。
    await wheel.discardPending(expectedRewardId: rewardId);
    expect(await wheel.start(), PCWheelStartResult.noSpins);
    final restoredWheel = PCWheelController(now: () => now);
    addTearDown(restoredWheel.dispose);
    await restoredWheel.load();
    expect(restoredWheel.spins, 0);

    now = DateTime(now.year, now.month, now.day + 1, 1);
    await restoredWheel.refreshDailyOpportunities();
    expect(restoredWheel.spins, 3);
    await wheel.refreshDailyOpportunities();
    expect(wheel.spins, 3);
  });

  test('快照读取真实机会账本，调低后答题新赠次数只加一次', () async {
    final values = goldValues();
    values[PCQuizController.storageKey] = jsonEncode({
      'questionIndex': 1,
      'correctCount': 1,
      'diamonds': 4.5,
      'gold': 12.1,
    });
    values[PCWheelOpportunityStore.storageKey] = jsonEncode({
      'balance': 21,
      'lastGrantDay': PCWheelOpportunityStore.dayKey(DateTime.now()),
      'quizAwardThrough': 1,
      'wheelAppliedId': 'old-spin',
    });
    values['pc_wheel_number'] = 4;
    await setup(values);
    expect((await debug.read()).wheelChances, 21);
    expect(prefs.getInt('pc_wheel_number'), 21);
    final quiz = PCQuizController();
    addTearDown(quiz.dispose);
    await quiz.load();
    await debug.apply(wheelChances: 2);
    expect(quiz.spins, 2);
    await quiz.answer(correct: true);
    expect(quiz.spins, 3);
    await quiz.refreshBalance();
    expect(quiz.spins, 3);
    expect((await debug.read()).wheelChances, 3);
  });

  test('未进入过转盘先调试设置7次，首次加载仍为7，隔天才再加3', () async {
    await setup({'pc_dollar_number': 10.0});
    final initial = await debug.read();
    expect(initial.wheelChances, 0);
    final unclaimed =
        jsonDecode(prefs.getString(PCWheelOpportunityStore.storageKey)!) as Map;
    expect(unclaimed['lastGrantDay'], '');

    final changed = await debug.apply(wheelChances: 7);
    expect(changed.wheelChances, 7);
    final claimed =
        jsonDecode(prefs.getString(PCWheelOpportunityStore.storageKey)!) as Map;
    expect(claimed['lastGrantDay'], PCWheelOpportunityStore.dayKey(now));
    final wheel = PCWheelController(now: () => now);
    addTearDown(wheel.dispose);
    await wheel.load();
    expect(wheel.spins, 7);
    await wheel.refreshDailyOpportunities();
    expect(wheel.spins, 7);
    now = DateTime(now.year, now.month, now.day + 1, 1);
    await wheel.refreshDailyOpportunities();
    expect(wheel.spins, 10);
  });

  test('输入先整体校验，空提交、负数、非有限及溢出不修改任何缓存', () async {
    await setup(goldValues());
    final original = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final invalidActions = <Future<Object?> Function()>[
      () => debug.apply(),
      () => debug.apply(cash: 20, diamonds: -1),
      () => debug.apply(cash: double.nan),
      () => debug.apply(diamonds: double.infinity),
      () => debug.apply(gold: 1e308),
      () => debug.apply(queueRank: 0),
      () => debug.apply(queueRank: -5),
      () => debug.apply(cash: 20, queueRank: 1000000001),
      () => debug.apply(wheelChances: -1),
      () => debug.apply(cash: 20, wheelChances: 1000000001),
    ];
    for (final action in invalidActions) {
      await expectLater(action(), throwsFormatException);
      expect({
        for (final key in prefs.getKeys()) key: prefs.get(key),
      }, original);
    }
    expect(synced, 0);
  });

  test('尚未完成的绝对奖励恢复日志不允许改数以免稍后复活旧值', () async {
    await setup(goldValues());
    final journal = jsonEncode({'balanceAfter': 200.0});
    await prefs.setString(PCQuizController.journalKey, journal);
    await expectLater(debug.apply(cash: 1), throwsStateError);
    expect(prefs.getDouble('pc_dollar_number'), 149.77);
    expect(prefs.getString(PCQuizController.journalKey), journal);
    expect(synced, 0);
  });
}
