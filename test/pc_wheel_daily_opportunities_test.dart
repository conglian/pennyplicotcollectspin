import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWheel.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelOpportunityStore.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  late DateTime clock;
  setUp(() {
    clock = DateTime(2026, 10, 27, 12);
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_new_guide_end': true,
      'pc_pig_level': 2,
      'pc_pig_upgrade_seen_level_v1': 2,
      'pc_dollar_number': 100.0,
      'pc_quiz_gold': 11.0,
      'pc_quiz_all_num': 1,
    });
  });

  PCWheelController wheel() => PCWheelController(now: () => clock);
  Map<String, dynamic> ledger(
    int balance, {
    String? day,
    int quiz = 1,
    String id = '',
  }) => {
    'balance': balance,
    'lastGrantDay': day ?? PCWheelOpportunityStore.dayKey(clock),
    'quizAwardThrough': quiz,
    'wheelAppliedId': id,
  };
  Future<void> saveLedger(Map<String, dynamic> value, {int? mirror}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCWheelOpportunityStore.storageKey,
      jsonEncode(value),
    );
    await prefs.setInt('pc_wheel_number', mirror ?? value['balance'] as int);
  }

  const turn = PCWheelTurn(
    segment: 3,
    spinsAfter: 1,
    reward: PCQuizReward(
      id: 'interrupted_spin',
      type: PCQuizRewardType.gold,
      amount: .02,
      questionIndex: -1,
    ),
  );

  test('首次补3次，同日并发加载、切页刷新和冷启动均不重复赠送', () async {
    final first = wheel(), second = wheel();
    await Future.wait([
      first.load(),
      second.load(),
      first.refreshDailyOpportunities(),
    ]);
    expect(first.spins, 3);
    expect(second.spins, 3);
    expect(await first.start(), PCWheelStartResult.started);
    expect(first.spins, 2);
    final reward = first.pending!.toJson();
    first.dispose();
    second.dispose();
    final restored = wheel();
    await restored.load();
    expect(restored.spins, 2);
    expect(restored.pending!.toJson(), reward);
    await restored.refreshDailyOpportunities();
    expect(restored.spins, 2);
    restored.dispose();
  });

  test('次日叠加3次保留已有机会，离线多日只领取本次打开当天，回拨不重领', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_wheel_number', 5);
    final flow = wheel();
    await flow.load();
    expect(flow.spins, 8);
    clock = DateTime(2026, 11, 1, 0, 0, 1);
    await flow.refreshDailyOpportunities();
    expect(flow.spins, 11);
    clock = DateTime(2026, 10, 31, 23);
    await flow.refreshDailyOpportunities();
    expect(flow.spins, 11);
    flow.dispose();
  });

  test('跨午夜每日赠送、答题额外次数和转盘扣次并发后保留全部增减', () async {
    await saveLedger(ledger(4));
    final flow = wheel();
    final quiz = PCQuizController();
    await Future.wait([flow.load(), quiz.load()]);
    clock = DateTime(2026, 10, 28);
    await Future.wait([
      flow.refreshDailyOpportunities(),
      quiz.answer(correct: true),
      flow.start(),
    ]);
    expect(flow.spins, 7, reason: '旧4 + 每日3 + 第2题1 - 转盘1');
    expect(quiz.spins, 7);
    final restored = wheel();
    await restored.load();
    expect(restored.spins, 7);
    expect(restored.pending!.reward.id, flow.pending!.reward.id);
    flow.dispose();
    quiz.dispose();
    restored.dispose();
  });

  test('两个转盘实例并发启动只产生一笔待奖并扣一次', () async {
    final first = wheel(), second = wheel();
    final results = await Future.wait([first.start(), second.start()]);
    expect(
      results,
      containsAll([PCWheelStartResult.started, PCWheelStartResult.pending]),
    );
    expect(first.spins, 2);
    expect(second.spins, 2);
    expect(first.pending!.reward.id, second.pending!.reward.id);
    first.dispose();
    second.dispose();
  });

  test('旧扣次日志先恢复再加3，旧答题目标不能补回已消耗的机会', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_wheel_number', 2);
    await prefs.setString(
      PCQuizController.storageKey,
      jsonEncode({'correctCount': 2, 'questionIndex': 2, 'spinTarget': 2}),
    );
    await prefs.setString(
      PCWheelController.journalKey,
      jsonEncode({'action': 'start', 'turn': turn.toJson()}),
    );
    final flow = wheel();
    final quiz = PCQuizController();
    await Future.wait([quiz.load(), flow.load()]);
    expect(flow.spins, 4, reason: '旧扣次后1 + 每日3，旧spinTarget不再补回2');
    expect(flow.pending!.reward.id, turn.reward.id);
    flow.dispose();
    quiz.dispose();
  });

  test('旧答题未完成加次目标先迁移，随后每日+3不吞掉里程碑机会', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_wheel_number', 0);
    await prefs.setString(
      PCQuizController.storageKey,
      jsonEncode({'correctCount': 2, 'questionIndex': 2, 'spinTarget': 1}),
    );
    final flow = wheel();
    await flow.load();
    final quiz = PCQuizController();
    await quiz.load();
    expect(flow.spins, 4);
    expect(quiz.spins, 4);
    flow.dispose();
    quiz.dispose();
  });

  test('账本已扣次但镜像和待奖未写完时恢复，只修复镜像且跨天不重复扣次', () async {
    await saveLedger(
      ledger(1, day: '2026-10-26', id: turn.reward.id),
      mirror: 2,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCWheelController.journalKey,
      jsonEncode({
        'action': 'start',
        'turn': turn.toJson(),
        'opportunityEvent': true,
      }),
    );
    final flow = wheel();
    await flow.load();
    expect(flow.spins, 4);
    expect(flow.pending!.toJson(), turn.toJson());
    flow.dispose();
    final restored = wheel();
    await restored.load();
    expect(restored.spins, 4);
    expect(await restored.start(), PCWheelStartResult.pending);
    expect(restored.spins, 4);
    restored.dispose();
  });

  for (final credited in [false, true]) {
    test('答题事件在账本${credited ? "已" : "未"}提交时恢复，不重复加次也不被每日赠送覆盖', () async {
      await saveLedger(
        ledger(credited ? 2 : 1, day: '2026-10-26', quiz: credited ? 2 : 1),
        mirror: 1,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PCQuizController.storageKey,
        jsonEncode({
          'correctCount': 2,
          'questionIndex': 2,
          'spinAward': {'correctCount': 2, 'amount': 1},
        }),
      );
      final flow = wheel();
      final quiz = PCQuizController();
      await Future.wait([flow.load(), quiz.load()]);
      expect(flow.spins, 5);
      expect(
        prefs.getString(PCQuizController.storageKey),
        isNot(contains('spinAward')),
      );
      quiz.dispose();
      flow.dispose();
      final restored = PCQuizController();
      await restored.load();
      expect(restored.spins, 5);
      restored.dispose();
    });
  }

  testWidgets('转盘常驻页本地午夜自动刷新次数，退后台跨天返回也自动刷新', (tester) async {
    clock = DateTime(2026, 10, 27, 23, 59, 59);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final flow = wheel();
    final provider = PCLocalProvider.instance;
    await provider.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) =>
              MaterialApp(home: PCWheel(controller: flow, active: false)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('×3'), findsNWidgets(2));
    clock = DateTime(2026, 10, 28, 0, 0, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('×6'), findsNWidgets(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = DateTime(2026, 10, 29, 12);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('×9'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    flow.dispose();
  });
}
