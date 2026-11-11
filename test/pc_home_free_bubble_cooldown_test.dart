import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeRewardController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  late DateTime now;
  PCHomeRewardController controller() {
    final flow = PCHomeRewardController(random: Random(3), now: () => now);
    addTearDown(flow.dispose);
    return flow;
  }

  setUp(() {
    now = DateTime(2026, 10, 27, 12);
    SharedPreferences.setMockInitialValues({
      'pc_pig_level': 0,
      'pc_dollar_number': 30.0,
    });
  });

  test('首个明文气泡免费，仅查询奖励不开始冷却', () async {
    final flow = controller();
    await flow.load();
    expect(PCHomeRewardController.freeSlot, 0);
    expect(List.generate(3, flow.isFreeSlot), [true, false, false]);
    expect(List.generate(3, flow.canTapSlot), [true, true, true]);
    final reward = flow.rewardAt(0)!;
    await flow.refresh();
    expect(flow.rewardAt(0)!.id, reward.id);
    expect(flow.freeCooldownUntil, isNull);
    expect(flow.freeCooldownSeconds, 0);
    expect(flow.canTapSlot(-1), isFalse);
    expect(flow.canTapSlot(3), isFalse);
  });

  test('打开免费领奖先预留并冷却但不发奖，冷却中Claim可领取且截止时间不顺延', () async {
    final flow = controller();
    await flow.load();
    final generation = flow.generation;
    final amount = flow.amounts[0];
    final reserved = (await flow.reserveFreeReward())!;
    final until = flow.freeCooldownUntil;
    expect(flow.collected, 30);
    expect(flow.generation, generation);
    expect(reserved.amount, amount);
    expect(flow.freeCooldownSeconds, 60);
    expect(flow.canTapSlot(0), isFalse);
    expect(await flow.beginFreeReward(), isNull);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      prefs.getString(PCHomeRewardController.storageKey)!,
    );
    expect(saved['freeReservedRewardId'], reserved.id);
    expect(prefs.getDouble('pc_dollar_number'), 30);
    expect(prefs.getString(PCHomeRewardController.journalKey), isNull);
    now = now.add(const Duration(seconds: 17));
    expect(await flow.claim(reserved), same(reserved));
    expect(flow.collected, closeTo(30 + amount, .00001));
    expect(flow.generation, generation + 1);
    expect(flow.freeCooldownUntil, until);
    expect(flow.freeCooldownSeconds, 43);
    expect(await flow.claim(reserved), isNull);
    final claimed = jsonDecode(
      prefs.getString(PCHomeRewardController.storageKey)!,
    );
    expect(claimed['freeReservedRewardId'], isNull);
  });

  test('关闭未领的免费弹窗后冷启仍冷却，到期可重新预留但旧预留不能领奖', () async {
    final original = controller();
    await original.load();
    final first = (await original.beginFreeReward())!;
    final generation = original.generation;
    now = now.add(const Duration(seconds: 20));
    final restored = controller();
    await restored.load();
    expect(restored.freeCooldownSeconds, 40);
    expect(await restored.reserveFreeReward(), isNull);
    expect(restored.collected, 30);
    expect(restored.generation, generation);
    now = now.add(const Duration(seconds: 40));
    final second = (await restored.reserveFreeReward())!;
    expect(second.id, isNot(first.id));
    expect(second.amount, first.amount);
    expect(restored.generation, generation);
    // 老页面同代缓存仍有旧ID，claim也须重读最新的预留记录。
    expect(await original.claim(first), isNull);
    expect(await restored.claim(second), same(second));
    expect(restored.collected, closeTo(30 + second.amount, .00001));
  });

  test('广告气泡领取生成新一代后，免费弹窗旧预留失效但原冷却继续', () async {
    final flow = controller();
    await flow.load();
    final reserved = (await flow.reserveFreeReward())!;
    final until = flow.freeCooldownUntil;
    final adReward = flow.rewardAt(2)!;
    now = now.add(const Duration(seconds: 10));
    expect(await flow.claim(adReward), same(adReward));
    final balance = flow.collected;
    expect(await flow.claim(reserved), isNull);
    expect(flow.collected, balance);
    expect(flow.freeCooldownUntil, until);
    expect(flow.freeCooldownSeconds, 50);
  });

  test('弹窗停留时远程配置更新，Claim拒绝旧预留并保留冷却重新按配置取值', () async {
    final flow = controller();
    await flow.load();
    final reserved = (await flow.reserveFreeReward())!;
    final until = flow.freeCooldownUntil;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNumberHelpers.configKey,
      jsonEncode({
        'money_prize': [
          {
            'first_number': 0,
            'end_number': 100,
            'prize': [.25, .25],
          },
        ],
      }),
    );
    expect(await flow.claim(reserved), isNull);
    expect(flow.collected, 30);
    expect(flow.amounts, [.25, .25, .25]);
    expect(flow.freeCooldownUntil, until);
    expect(flow.freeCooldownSeconds, 60);
  });

  test('免费弹窗停留超过60秒仍可领同一预留，领取不额外开始一轮冷却', () async {
    final flow = controller();
    await flow.load();
    final reserved = (await flow.reserveFreeReward())!;
    final until = flow.freeCooldownUntil;
    now = now.add(const Duration(seconds: 65));
    expect(await flow.claim(reserved), same(reserved));
    expect(flow.freeCooldownUntil, until);
    expect(flow.freeCooldownSeconds, 0);
    expect(flow.canTapSlot(0), isTrue);
  });

  test('并发打开免费领奖仅一个预留成功，不增加金额、不改变三个预生成值', () async {
    final first = controller();
    final second = controller();
    await first.load();
    await second.load();
    final values = first.amounts;
    final reservations = await Future.wait([
      first.reserveFreeReward(),
      second.reserveFreeReward(),
    ]);
    expect(reservations.whereType<PCQuizReward>(), hasLength(1));
    await second.refresh();
    expect(second.amounts, values);
    expect(second.freeCooldownSeconds, 60);
    expect(second.collected, 30);
  });

  test('兼容直接claim免费奖励原子保存60秒冷却；期间拒绝再次领取且广告气泡可用', () async {
    final flow = controller();
    await flow.load();
    final reward = flow.rewardAt(0)!;
    final before = flow.generation;
    expect(await flow.claim(reward), same(reward));
    expect(flow.generation, before + 1);
    expect(flow.collected, 30 + reward.amount);
    expect(flow.freeCooldownUntil, now.add(const Duration(seconds: 60)));
    expect(flow.freeCooldownRemaining, const Duration(seconds: 60));
    expect(flow.freeCooldownSeconds, 60);
    expect(List.generate(3, flow.canTapSlot), [false, true, true]);
    expect(flow.rewardAt(0), isNull);
    expect(await flow.claim(reward), isNull);
    final forged = PCQuizReward(
      id: 'bubble_${flow.generation}_0',
      type: PCQuizRewardType.cash,
      amount: flow.amounts[0],
      questionIndex: -1,
    );
    expect(await flow.claim(forged), isNull);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      prefs.getString(PCHomeRewardController.storageKey)!,
    );
    expect(
      saved['freeCooldownUntil'],
      flow.freeCooldownUntil!.millisecondsSinceEpoch,
    );
    expect(prefs.getString(PCHomeRewardController.journalKey), isNull);
    expect(prefs.getDouble('pc_dollar_number'), 30 + reward.amount);
  });

  test('倒计时向上取整且精确到期恢复，下一次领取重新计60秒', () async {
    final flow = controller();
    await flow.load();
    await flow.claim(flow.rewardAt(0)!);
    now = now.add(const Duration(seconds: 59, milliseconds: 999));
    expect(flow.freeCooldownSeconds, 1);
    expect(flow.canTapSlot(0), isFalse);
    now = now.add(const Duration(milliseconds: 1));
    expect(flow.freeCooldownRemaining, Duration.zero);
    expect(flow.freeCooldownSeconds, 0);
    expect(flow.canTapSlot(0), isTrue);
    final generation = flow.generation;
    expect(await flow.claim(flow.rewardAt(0)!), isNotNull);
    expect(flow.generation, generation + 1);
    expect(flow.freeCooldownSeconds, 60);
  });

  test('切页刷新及冷启动按保存的截止时间恢复，不重置也不绕过冷却', () async {
    final flow = controller();
    await flow.load();
    await flow.claim(flow.rewardAt(0)!);
    final until = flow.freeCooldownUntil;
    final values = flow.amounts;
    now = now.add(const Duration(seconds: 19));
    await flow.refresh();
    expect(flow.freeCooldownUntil, until);
    final restored = controller();
    await restored.load();
    expect(restored.freeCooldownSeconds, 41);
    expect(restored.freeCooldownUntil, until);
    expect(restored.amounts, values);
    expect(restored.canTapSlot(0), isFalse);
    now = now.add(const Duration(seconds: 42));
    final afterDeadline = controller();
    await afterDeadline.load();
    expect(afterDeadline.freeCooldownSeconds, 0);
    expect(afterDeadline.canTapSlot(0), isTrue);
    expect(afterDeadline.amounts, values);
  });

  test('广告气泡领取刷新三个配置金额，保留免费气泡原冷却截止时间', () async {
    final flow = controller();
    await flow.load();
    await flow.claim(flow.rewardAt(0)!);
    final until = flow.freeCooldownUntil;
    final generation = flow.generation;
    now = now.add(const Duration(seconds: 10));
    final reward = flow.rewardAt(2)!;
    final before = flow.collected;
    expect(await flow.claim(reward), same(reward));
    expect(flow.collected, closeTo(before + reward.amount, .00001));
    expect(flow.generation, generation + 1);
    expect(flow.amounts, hasLength(3));
    expect(flow.freeCooldownUntil, until);
    expect(flow.freeCooldownSeconds, 50);
    expect(flow.rewardAt(0), isNull);
  });

  test('其他入口余额和远程配置变化重抽三个值时，也不取消免费冷却', () async {
    final flow = controller();
    await flow.load();
    await flow.claim(flow.rewardAt(0)!);
    final until = flow.freeCooldownUntil;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_dollar_number', 60);
    await prefs.setString(
      PCNumberHelpers.configKey,
      jsonEncode({
        'money_prize': [
          {
            'first_number': 0,
            'end_number': 100,
            'prize': [.25, .25],
          },
        ],
      }),
    );
    await flow.refresh();
    expect(flow.amounts, [.25, .25, .25]);
    expect(flow.freeCooldownUntil, until);
    expect(flow.canTapSlot(0), isFalse);
    expect(flow.canTapSlot(1), isTrue);
  });

  test('中断后的发奖日志恢复同一截止时间和绝对余额，不重发或重抽三个值', () async {
    final flow = controller();
    await flow.load();
    final reward = flow.rewardAt(0)!;
    final prefs = await SharedPreferences.getInstance();
    final current =
        jsonDecode(prefs.getString(PCHomeRewardController.storageKey)!)
            as Map<String, dynamic>;
    final until = now.add(const Duration(seconds: 60));
    final balance = 30 + reward.amount;
    final snapshot = {
      ...current,
      'generation': flow.generation + 1,
      'amount': balance,
      'prizes': [10.1, 10.2, 10.3],
      'freeCooldownUntil': until.millisecondsSinceEpoch,
    };
    await prefs.setString(
      PCHomeRewardController.journalKey,
      jsonEncode({
        'rewardId': reward.id,
        'balanceAfter': balance,
        'diamondsAfter': 0.0,
        'goldAfter': 0.0,
        'snapshot': snapshot,
      }),
    );
    await prefs.setDouble('pc_dollar_number', balance);
    now = now.add(const Duration(seconds: 15));
    final restored = controller();
    await restored.load();
    expect(restored.freeCooldownUntil, until);
    expect(restored.freeCooldownSeconds, 45);
    expect(restored.amounts, [10.1, 10.2, 10.3]);
    expect(prefs.getDouble('pc_dollar_number'), balance);
    expect(await restored.claim(reward), isNull);
    expect(prefs.getString(PCHomeRewardController.journalKey), isNull);
    await restored.refresh();
    expect(restored.freeCooldownSeconds, 45);
    expect(prefs.getDouble('pc_dollar_number'), balance);
  });

  test('多个页面控制器并发领取同一个免费气泡，只入账一次', () async {
    final first = controller();
    final second = controller();
    await first.load();
    await second.load();
    final reward = first.rewardAt(0)!;
    final results = await Future.wait([
      first.claim(reward),
      second.claim(reward),
    ]);
    expect(results.whereType<PCQuizReward>(), hasLength(1));
    await second.refresh();
    expect(second.freeCooldownSeconds, 60);
    expect(second.canTapSlot(0), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('pc_dollar_number'), 30 + reward.amount);
  });

  testWidgets('倒计时主动刷新监听并到期停止，释放控制器不遗留计时器', (tester) async {
    final flow = PCHomeRewardController(random: Random(3), now: () => now);
    await flow.load();
    await flow.claim(flow.rewardAt(0)!);
    var notifications = 0;
    flow.addListener(() => notifications++);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(notifications, 1);
    expect(flow.freeCooldownSeconds, 59);
    now = now.add(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));
    expect(notifications, 2);
    expect(flow.canTapSlot(0), isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(notifications, 2);
    flow.dispose();
  });
}
