import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardBubble.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

class _CountingRandom implements Random {
  int draws = 0;
  @override
  double nextDouble() => (++draws % 9) / 10;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  void seed(int level, double amount) =>
      SharedPreferences.setMockInitialValues({
        'pc_pig_level': level,
        'pc_dollar_number': level == 0 ? amount : 100.0,
        'pc_quiz_diamonds': level == 1
            ? amount
            : level == 2
            ? 20.0
            : 0.0,
        'pc_quiz_gold': level == 2 ? amount : 0.0,
      });

  test('美元三个气泡预生成，普通刷新和冷启动保留原数值；领取后全部重抽并拒绝旧代奖励', () async {
    seed(0, 30.0);
    final random = _CountingRandom();
    final flow = PCHomeRewardController(random: random);
    await flow.load();
    expect(flow.amounts.length, 3);
    expect(random.draws, 3);
    for (final value in flow.amounts) {
      expect(value, inInclusiveRange(10, 20));
    }
    final values = flow.amounts;
    final generation = flow.generation;
    final oldRewards = List.generate(3, (i) => flow.rewardAt(i)!);
    await flow.refresh();
    expect(flow.amounts, values);
    expect(random.draws, 3);
    final restored = PCHomeRewardController(random: Random(8));
    await restored.load();
    expect(restored.amounts, values);
    expect(restored.generation, generation);
    restored.dispose();
    final reward = await flow.claim(oldRewards[0]);
    expect(reward!.amount, values[0]);
    expect(flow.generation, generation + 1);
    expect(flow.amounts.length, 3);
    expect(random.draws, 6);
    expect(flow.collected, 30 + values[0]);
    for (final stale in oldRewards) {
      expect(await flow.claim(stale), isNull);
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('pc_dollar_number'), 30 + values[0]);
    flow.dispose();
  });

  for (final level in [1, 2]) {
    test('阶段$level按资源数量取配置，领取后跨到下一奖励档并刷新三个值，不增加美元', () async {
      seed(level, 4.9);
      final random = _CountingRandom();
      final flow = PCHomeRewardController(random: random);
      await flow.load();
      expect(flow.amounts, [.1, .1, .1]);
      final reward = flow.rewardAt(2)!;
      expect(reward.type.index, level);
      await flow.claim(reward);
      expect(flow.collected, 5);
      expect(random.draws, 6);
      for (final value in flow.amounts) {
        expect(
          value,
          level == 1 ? inInclusiveRange(1, 2) : inInclusiveRange(.5, .8),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('pc_dollar_number'), 100);
      expect(
        prefs.getDouble(level == 1 ? 'pc_quiz_diamonds' : 'pc_quiz_gold'),
        5,
      );
      flow.dispose();
    });
  }

  for (final entry in [(0, 99.99, 1), (2, 9.99, 2)]) {
    test('阶段${entry.$1}末档领取后气泡切换到阶段${entry.$3}配置，金砖集满继续发奖', () async {
      seed(entry.$1, entry.$2);
      final flow = PCHomeRewardController(random: Random(1));
      await flow.load();
      final reward = flow.rewardAt(1)!;
      expect(reward.amount, .01);
      await flow.claim(reward);
      expect(flow.level, entry.$3);
      if (entry.$1 == 2) {
        expect(flow.amounts.every((v) => v >= .01 && v <= .02), isTrue);
        expect(flow.rewardAt(0)!.type, PCQuizRewardType.gold);
        await flow.claim(flow.rewardAt(0)!);
        expect(flow.collected, greaterThan(10));
      } else {
        expect(flow.collected, 0);
        for (final value in flow.amounts) {
          expect(
            value,
            entry.$3 == 1 ? inInclusiveRange(2, 3) : inInclusiveRange(1, 2),
          );
        }
      }
      expect(await flow.claim(reward), isNull);
      flow.dispose();
    });
  }

  test('钻石气泡超过20仍按末档发钻石，午夜刷新才切金砖配置且保留实际数量', () async {
    seed(1, 19.99);
    final flow = PCHomeRewardController(random: _CountingRandom());
    await flow.load();
    final reward = flow.rewardAt(1)!;
    expect(reward.amount, .02);
    await flow.claim(reward);
    expect(flow.level, 1);
    expect(flow.collected, 20.01);
    expect(
      flow.amounts.every((amount) => amount >= .01 && amount <= .05),
      isTrue,
    );
    final next = flow.rewardAt(0)!;
    expect(next.type, PCQuizRewardType.diamond);
    await flow.claim(next);
    final actualDiamonds = flow.diamonds;
    expect(actualDiamonds, greaterThan(20.01));
    final prefs = await SharedPreferences.getInstance();
    await PCPigProgress.sync(prefs, now: PCPigProgress.diamondDeadline(prefs)!);
    await flow.refresh();
    expect(flow.level, 2);
    expect(flow.collected, 0);
    expect(flow.diamonds, actualDiamonds);
    expect(flow.amounts.every((amount) => amount >= 1 && amount <= 2), isTrue);
    expect(prefs.getDouble('pc_dollar_number'), 100);
    flow.dispose();
  });

  test('同时点击三个气泡只结算一次，实际领取金额等于展示金额', () async {
    seed(1, 7.25);
    final flow = PCHomeRewardController(random: Random(1));
    await flow.load();
    final rewards = List.generate(3, (i) => flow.rewardAt(i)!);
    final claims = await Future.wait(rewards.map(flow.claim));
    expect(claims.whereType<PCQuizReward>().length, 1);
    expect(
      flow.collected,
      closeTo(7.25 + claims.whereType<PCQuizReward>().single.amount, .00001),
    );
    expect(flow.generation, 2);
    flow.dispose();
  });

  test('其他入口改变余额后拒绝旧气泡，刷新按新配置取值；常驻答题也能读取新数量', () async {
    seed(1, 4.9);
    final quiz = PCQuizController(random: Random(1));
    await quiz.load();
    final flow = PCHomeRewardController(random: Random(1));
    await flow.load();
    final old = flow.rewardAt(0)!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_diamonds', 5.0);
    expect(await flow.claim(old), isNull);
    expect(flow.collected, 5.0);
    final reward = flow.rewardAt(0)!;
    expect(reward.amount, inInclusiveRange(1, 2));
    await flow.claim(reward);
    expect(quiz.diamonds, closeTo(5.0 + reward.amount, .00001));
    await prefs.setString(
      PCNumberHelpers.configKey,
      jsonEncode({
        'diamond_prize': [
          {
            'first_number': 0,
            'end_number': 20,
            'prize': [.25, .25],
          },
        ],
      }),
    );
    await flow.refresh();
    expect(flow.amounts, [.25, .25, .25]);
    flow.dispose();
    quiz.dispose();
  });

  test('领取日志在数量已写后恢复，不重复发奖，也不重新随机已生成的三个新气泡', () async {
    seed(1, 7.25);
    final flow = PCHomeRewardController(random: Random(1));
    await flow.load();
    final prefs = await SharedPreferences.getInstance();
    final snapshot =
        jsonDecode(prefs.getString(PCHomeRewardController.storageKey)!)
            as Map<String, dynamic>;
    final next = {
      ...snapshot,
      'generation': 2,
      'amount': 8.75,
      'prizes': [1.1, 1.2, 1.25],
    };
    await prefs.setString(
      PCHomeRewardController.journalKey,
      jsonEncode({
        'rewardId': flow.rewardAt(0)!.id,
        'diamondsAfter': 8.75,
        'goldAfter': 0.0,
        'snapshot': next,
      }),
    );
    await prefs.setDouble('pc_quiz_diamonds', 8.75);
    flow.dispose();
    for (var i = 0; i < 2; i++) {
      final restored = PCHomeRewardController(random: Random(i));
      await restored.load();
      expect(restored.collected, 8.75);
      expect(restored.generation, 2);
      expect(restored.amounts, [1.1, 1.2, 1.25]);
      expect(prefs.getDouble('pc_quiz_diamonds'), 8.75);
      expect(prefs.getString(PCHomeRewardController.journalKey), isNull);
      restored.dispose();
    }
  });

  for (final size in [50.0, 64.0]) {
    testWidgets('气泡在$size尺寸下各阶段均有一个未知值，并使用对应前缀和图标', (tester) async {
      for (final type in PCQuizRewardType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    PCHomeRewardBubble(
                      type: type,
                      amount: 1.23,
                      mystery: i == 1,
                      size: size,
                    ),
                ],
              ),
            ),
          ),
        );
        final bubbles = tester
            .widgetList<PCHomeRewardBubble>(find.byType(PCHomeRewardBubble))
            .toList();
        expect(
          bubbles.map((b) => b.caption),
          type == PCQuizRewardType.cash
              ? [r'$1.23', r'$???', r'$1.23']
              : ['×1.23', '×???', '×1.23'],
        );
        final names = tester
            .widgetList<PCImg>(find.byType(PCImg))
            .map((i) => i.name)
            .toList();
        expect(
          names.where((name) => name != 'pc_ad_icon'),
          List.filled(3, switch (type) {
            PCQuizRewardType.cash => 'pc_doaller_icon',
            PCQuizRewardType.diamond => 'pc_home_bubble_diamond',
            PCQuizRewardType.gold => 'pc_home_bubble_gold',
          }),
        );
        expect(names.where((name) => name == 'pc_ad_icon'), hasLength(3));
        expect(
          tester
              .widgetList<PCStrokeText>(find.byType(PCStrokeText))
              .every((caption) => caption.size == size * 18 / 64),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
