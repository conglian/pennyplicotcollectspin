import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCAdOutcome.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/pc_number_test_assets.dart';

class _Clock {
  DateTime value = DateTime(2026, 10, 26, 12);
  DateTime now() => value;
}

class _HighRandom implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  double nextDouble() => .999;
  @override
  bool nextBool() => true;
}

class _FailStore extends InMemorySharedPreferencesStore {
  _FailStore(super.data, {required this.throwsWrite}) : super.withData();
  final bool throwsWrite;
  bool failing = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (failing && key == 'flutter.${PCWithdrawalController.storageKey}') {
      if (throwsWrite) throw StateError('storage unavailable');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  late _Clock clock;
  setUp(() async {
    clock = _Clock();
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  Future<PCWithdrawalController> create({
    Map<String, Object> values = const {},
    Future<bool> Function(String)? ad,
    Future<PCAdOutcome> Function(String)? adOutcome,
    Future<void> Function()? onSync,
    Random? random,
  }) async {
    SharedPreferences.setMockInitialValues(values);
    final flow = PCWithdrawalController(
      now: clock.now,
      random: random,
      requestAd: ad,
      requestAdOutcome: adOutcome,
      onSync: onSync,
      scheduleMidnightTimer: false,
    );
    addTearDown(flow.dispose);
    await flow.load();
    return flow;
  }

  Future<PCWithdrawalController> restore() async {
    final flow = PCWithdrawalController(
      now: clock.now,
      scheduleMidnightTimer: false,
    );
    addTearDown(flow.dispose);
    await flow.load();
    return flow;
  }

  Future<void> reach(
    PCWithdrawalController flow,
    PCWithdrawalPromptKind kind,
  ) async {
    for (var i = 0; i < 8 && flow.next?.kind != kind; i++) {
      expect(flow.next, isNotNull);
      await flow.acknowledge(flow.next!);
    }
    expect(flow.next?.kind, kind);
  }

  Map<String, Object> gold({
    double amount = 10,
    int rank = 9,
    int total = 20,
    List<Map<String, Object>>? tasks,
    List<int> allDelete = const [1, 3],
    List<int> currentDelete = const [5, 8],
  }) => {
    'pc_pig_level': 2,
    'pc_dollar_number': 100.0,
    'pc_quiz_diamonds': 3.5,
    'pc_quiz_gold': amount,
    'pc_pig_upgrade_seen_level_v1': 2,
    PCNumberHelpers.configKey: jsonEncode({
      'queue_number': [
        {
          'int_all': total,
          'int_current': rank,
          'int_all_delete': allDelete,
          'int_current_delete': currentDelete,
        },
      ],
      if (tasks != null) 'tixian_task': tasks,
    }),
  };

  for (final video in [false, true]) {
    for (final outcome in PCAdOutcome.values) {
      test('${video ? '视频任务' : '排队'}单次广告$outcome独立分流且只成功推进', () async {
        var requests = 0;
        final flow = await create(
          values: gold(
            rank: video ? 1 : 9,
            tasks: [
              {'title': 'video', 'data': 2},
            ],
          ),
          adOutcome: (_) async {
            requests++;
            return outcome;
          },
        );
        final result = video
            ? await flow.recordVideoWithAdOutcome()
            : await flow.advanceQueueWithAdOutcome();
        expect(result, switch (outcome) {
          PCAdOutcome.success => PCWithdrawalAdResult.applied,
          PCAdOutcome.cancelled => PCWithdrawalAdResult.cancelled,
          PCAdOutcome.failed => PCWithdrawalAdResult.failed,
        });
        expect(requests, 1);
        if (video) {
          expect(flow.taskProgress, outcome.isSuccess ? 1 : 0);
        } else if (outcome.isSuccess) {
          expect(flow.queueRank, lessThan(9));
          expect(flow.queueTotal, lessThan(20));
        } else {
          expect([flow.queueRank, flow.queueTotal], [9, 20]);
        }
        expect(flow.isBusy, isFalse);
      });
    }
  }

  test('提现广告在途和非当前任务返回notApplied，不伪报取消或广告失败', () async {
    final pending = Completer<PCAdOutcome>();
    var requests = 0;
    final flow = await create(
      values: gold(),
      adOutcome: (_) {
        requests++;
        return pending.future;
      },
    );
    expect(
      await flow.recordVideoWithAdOutcome(),
      PCWithdrawalAdResult.notApplied,
    );
    expect(requests, 0);
    final first = flow.advanceQueueWithAdOutcome();
    expect(
      await flow.advanceQueueWithAdOutcome(),
      PCWithdrawalAdResult.notApplied,
    );
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    pending.complete(PCAdOutcome.cancelled);
    expect(await first, PCWithdrawalAdResult.cancelled);
    expect([flow.queueRank, flow.queueTotal], [9, 20]);
  });

  test('广告已成功但阶段在播放期间变化时返回notApplied，不推进旧排队动作', () async {
    final pending = Completer<PCAdOutcome>();
    final requested = Completer<void>();
    final flow = await create(
      values: gold(),
      adOutcome: (_) {
        requested.complete();
        return pending.future;
      },
    );
    final action = flow.advanceQueueWithAdOutcome();
    await requested.future;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_gold', 2);
    pending.complete(PCAdOutcome.success);
    expect(await action, PCWithdrawalAdResult.notApplied);
    expect([flow.queueRank, flow.queueTotal], [9, 20]);
    expect(flow.isBusy, isFalse);
  });

  for (final throwsWrite in [false, true]) {
    test('广告真实成功后保存${throwsWrite ? '抛错' : '返回false'}传播保存异常，不冒充广告失败', () async {
      var requests = 0;
      final flow = await create(
        values: gold(),
        adOutcome: (_) async {
          requests++;
          return PCAdOutcome.success;
        },
      );
      final prefs = await SharedPreferences.getInstance();
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _FailStore({
        for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
      }, throwsWrite: throwsWrite);
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      await expectLater(
        flow.advanceQueueWithAdOutcome(),
        throwsA(isA<StateError>()),
      );
      expect(requests, 1, reason: '必须已收到真实成功后才测试本地落盘失败');
      expect(flow.isBusy, isFalse);
      store.failing = false;
      expect(
        await flow.advanceQueueWithAdOutcome(),
        PCWithdrawalAdResult.applied,
      );
    });
  }

  test('真实成功后同步UI抛错仍是保存同步异常且已提交进度不撤销', () async {
    var syncFails = true;
    final flow = await create(
      values: gold(),
      adOutcome: (_) async => PCAdOutcome.success,
      onSync: () async {
        if (syncFails) throw StateError('provider reload failed');
      },
    );
    await expectLater(
      flow.advanceQueueWithAdOutcome(),
      throwsA(isA<StateError>()),
    );
    expect(flow.queueRank, lessThan(9));
    expect(flow.isBusy, isFalse);
    syncFails = false;
    await flow.refresh();
    expect(flow.queueRank, lessThan(9));
  });

  test('钻石20是进度目标，当天超额不升级，下一本地午夜才升级', () async {
    final flow = await create(
      values: {'pc_dollar_number': 100.0, 'pc_quiz_diamonds': 21.25},
    );
    expect(flow.pigLevel, 1);
    expect(flow.stage, PCWithdrawalStage.reviewApproved);
    expect(flow.diamonds, 21.25);
    expect(flow.diamondEnteredAt, clock.value);
    expect(flow.diamondDeadline, DateTime(2026, 10, 27));
    clock.value = DateTime(2026, 10, 26, 23, 59, 59);
    await flow.refresh();
    expect(flow.pigLevel, 1);
    expect(flow.midnightRemaining, const Duration(seconds: 1));
    clock.value = DateTime(2026, 10, 27);
    await flow.refresh();
    expect(flow.pigLevel, 2);
    expect(flow.next?.kind, PCWithdrawalPromptKind.goldUpgrade);
    expect(flow.diamonds, 21.25);
  });

  test('不足20的3.5钻跨天仍收集中，不启动倒计时也不补成20', () async {
    final flow = await create(
      values: {
        'pc_pig_level': 1,
        'pc_dollar_number': 100.0,
        'pc_quiz_diamonds': 3.5,
      },
    );
    expect(flow.stage, PCWithdrawalStage.reviewing);
    clock.value = DateTime(2026, 10, 27, 7);
    await flow.refresh();
    await flow.refresh();
    final cold = await restore();
    expect(cold.stage, PCWithdrawalStage.reviewing);
    expect(cold.pigLevel, 1);
    expect(cold.diamonds, 3.5);
    expect(cold.diamondDeadline, isNull);
    final prefs = await SharedPreferences.getInstance();
    final progress = await PCPigProgress.sync(prefs, now: clock.value);
    expect(progress.diamonds, 3.5);
  });

  test('完成入场链后首次收满20立即显示倒计时，关闭不循环且冷启保留截止时间', () async {
    final flow = await create(
      values: {
        'pc_pig_level': 1,
        'pc_dollar_number': 100.0,
        'pc_quiz_diamonds': 19.5,
        PCWithdrawalController.storageKey: jsonEncode({
          'observedLevel': 1,
          'diamondStarted': true,
          'diamondStep': 7,
          'giftClaimed': true,
          'pending': [],
        }),
      },
    );
    expect(flow.next?.kind, PCWithdrawalPromptKind.diamondCollect);
    expect(flow.diamondDeadline, isNull);
    await flow.dismiss(flow.next!);
    clock.value = DateTime(2026, 10, 28, 22, 45);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_diamonds', 20);
    await flow.refresh();
    expect(flow.next?.kind, PCWithdrawalPromptKind.diamondCountdown);
    expect(flow.diamondDeadline, DateTime(2026, 10, 29));
    expect(flow.midnightRemaining, const Duration(hours: 1, minutes: 15));
    await flow.acknowledge(flow.next!);
    await flow.refresh();
    expect(flow.pending, isEmpty);
    clock.value = DateTime(2026, 10, 28, 23, 30);
    final cold = await restore();
    expect(cold.next?.kind, PCWithdrawalPromptKind.diamondCountdown);
    expect(cold.diamondDeadline, DateTime(2026, 10, 29));
    expect(cold.midnightRemaining, const Duration(minutes: 30));
    clock.value = DateTime(2026, 10, 29);
    await cold.refresh();
    expect(cold.pigLevel, 2);
    expect(cold.next?.kind, PCWithdrawalPromptKind.goldUpgrade);
  });

  test('旧档已满20但未开启新倒计时，忽略过期入钻deadline并从当前日期开始', () async {
    final flow = await create(
      values: {
        'pc_pig_level': 1,
        'pc_dollar_number': 100.0,
        'pc_quiz_diamonds': 24.75,
        PCPigProgress.diamondEnteredKey: DateTime(
          2026,
          10,
          20,
        ).toIso8601String(),
        PCPigProgress.diamondDeadlineKey: DateTime(
          2026,
          10,
          21,
        ).toIso8601String(),
        PCWithdrawalController.storageKey: jsonEncode({
          'observedLevel': 1,
          'diamondStarted': true,
          'diamondStep': 7,
          'giftClaimed': true,
          'pending': [],
        }),
      },
    );
    expect(flow.pigLevel, 1);
    expect(flow.diamonds, 24.75);
    expect(flow.diamondDeadline, DateTime(2026, 10, 27));
    expect(flow.next?.kind, PCWithdrawalPromptKind.diamondCountdown);
  });

  test('礼包正好补足20时才启动午夜倒计时，数量仍按缓存配置真实结算', () async {
    final flow = await create(
      values: {
        'pc_pig_level': 1,
        'pc_dollar_number': 100.0,
        'pc_quiz_diamonds': 19.75,
        PCNumberHelpers.configKey: jsonEncode({
          'diamond_prize': [
            {
              'first_number': 0,
              'end_number': 10000,
              'type': 1,
              'prize': [.5, .5],
            },
          ],
        }),
        PCWithdrawalController.storageKey: jsonEncode({
          'observedLevel': 1,
          'diamondStarted': true,
          'diamondStep': 5,
          'pending': [],
        }),
      },
    );
    expect(flow.diamondDeadline, isNull);
    expect(await flow.claimDiamondGift(), isTrue);
    expect(flow.diamonds, 20.25);
    expect(flow.diamondGiftAmount, .5);
    expect(flow.diamondDeadline, DateTime(2026, 10, 27));
    expect(flow.next?.kind, PCWithdrawalPromptKind.diamondCountdown);
  });

  test('旧金猪不降级，已有精确零钻不推断20，完全缺字段才兼容旧档', () async {
    final flow = await create(
      values: {
        'pc_pig_level': 2,
        'pc_dollar_number': 0.0,
        'pc_quiz_diamonds': 0.0,
        'pc_quiz_gold': .12,
      },
    );
    expect(flow.pigLevel, 2);
    expect(flow.gold, .12);
    expect(flow.diamonds, 0);
    SharedPreferences.setMockInitialValues({'pc_pig_level': 2});
    final prefs = await SharedPreferences.getInstance();
    expect((await PCPigProgress.sync(prefs, now: clock.value)).diamonds, 20);
  });

  test('旧钻石升级从reviewPending迁移，旧进入日期不能让不足20直接金猪', () async {
    final flow = await create(
      values: {
        'pc_pig_level': 1,
        'pc_dollar_number': 100.0,
        'pc_quiz_diamonds': 1.0,
        'pc_pig_upgrade_seen_level_v1': 1,
      },
    );
    expect(flow.next?.kind, PCWithdrawalPromptKind.reviewPending);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PCWithdrawalController.storageKey);
    await prefs.remove(PCPigProgress.diamondEnteredKey);
    await prefs.remove(PCPigProgress.diamondDeadlineKey);
    await prefs.setString(
      'pc_pig_upgrade_date_1',
      DateTime(2026, 10, 25).toIso8601String(),
    );
    final cold = await restore();
    expect(cold.pigLevel, 1);
    expect(cold.diamondDeadline, isNull);
    expect(cold.pending.map((p) => p.kind), [
      PCWithdrawalPromptKind.reviewPending,
    ]);
  });

  test('钻石和金砖超过目标继续取末档，只有现金100停止现金奖励', () {
    final numbers = PCNumberHelpers();
    expect(numbers.pc_prizeForLevel(1, 19.99, random: _HighRandom()), .05);
    expect(numbers.pc_prizeForLevel(1, 20, random: _HighRandom()), .05);
    expect(numbers.pc_prizeForLevel(1, 36.12, random: _HighRandom()), .05);
    expect(numbers.pc_prizeForLevel(0, 100), 0);
    expect(numbers.pc_prizeForLevel(2, 10, random: _HighRandom()), .02);
    expect(numbers.pc_prizeForLevel(2, 36.12, random: _HighRandom()), .02);
  });

  test('钻石七节点依次持久化，审核基线40，礼包配置奖励只领取一次且拒绝连点', () async {
    final flow = await create(values: {'pc_dollar_number': 100.0});
    final order = <PCWithdrawalPromptKind>[];
    while (flow.next?.kind != PCWithdrawalPromptKind.giftReward) {
      order.add(flow.next!.kind);
      await flow.acknowledge(flow.next!);
    }
    expect(order, [
      PCWithdrawalPromptKind.diamondUpgrade,
      PCWithdrawalPromptKind.reviewPending,
      PCWithdrawalPromptKind.reviewVerification,
      PCWithdrawalPromptKind.channelActivated,
      PCWithdrawalPromptKind.priorityGift,
    ]);
    expect(flow.reviewBaseline, 40);
    await flow.acknowledge(flow.next!);
    expect(flow.next?.kind, PCWithdrawalPromptKind.giftReward);
    final giftAmount = flow.diamondGiftAmount;
    expect(giftAmount, inInclusiveRange(2, 3));
    expect(
      await Future.wait([flow.claimDiamondGift(), flow.claimDiamondGift()]),
      [true, false],
    );
    expect(flow.balance, 100);
    expect(flow.diamonds, giftAmount);
    expect(flow.hasPending, isFalse);
    expect(flow.diamondDeadline, isNull);
    final cold = await restore();
    expect(cold.giftClaimed, isTrue);
    expect(await cold.claimDiamondGift(), isFalse);
    expect(cold.diamonds, giftAmount);
    expect(cold.next?.kind, PCWithdrawalPromptKind.diamondCollect);
    await cold.acknowledge(cold.next!);
    expect(cold.hasPending, isFalse);
  });

  test('关闭中奖不领钻、不消费步骤，普通refresh不连弹，冷启恢复待领奖', () async {
    final flow = await create(values: {'pc_dollar_number': 100.0});
    await reach(flow, PCWithdrawalPromptKind.giftReward);
    final giftAmount = flow.diamondGiftAmount;
    await flow.dismiss(flow.next!);
    await flow.refresh();
    expect(flow.hasPending, isFalse);
    expect(flow.diamonds, 0);
    final cold = await restore();
    expect(cold.next?.kind, PCWithdrawalPromptKind.giftReward);
    expect(await cold.claimDiamondGift(), isTrue);
    expect(cold.diamondGiftAmount, giftAmount);
    expect(cold.diamonds, giftAmount);
  });

  test('礼包按当前钻石配置档位生成，刷新配置和冷启均沿用已展示的同一笔数量', () async {
    final flow = await create(
      values: {
        'pc_dollar_number': 100.0,
        'pc_quiz_diamonds': 6.0,
        PCNumberHelpers.configKey: jsonEncode({
          'diamond_prize': [
            {
              'first_number': 0,
              'end_number': 5,
              'type': 1,
              'prize': [2.75, 2.75],
            },
            {
              'first_number': 5,
              'end_number': 10000,
              'type': 1,
              'prize': [.65, .65],
            },
          ],
        }),
      },
    );
    await reach(flow, PCWithdrawalPromptKind.giftReward);
    expect(flow.diamondGiftAmount, .65);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNumberHelpers.configKey,
      jsonEncode({
        'diamond_prize': [
          {
            'first_number': 0,
            'end_number': 10000,
            'type': 1,
            'prize': [4, 4],
          },
        ],
      }),
    );
    await flow.refresh();
    expect(flow.diamondGiftAmount, .65);
    final cold = await restore();
    expect(cold.diamondGiftAmount, .65);
    expect(await cold.claimDiamondGift(), isTrue);
    expect(cold.diamonds, 6.65);
    expect(cold.balance, 100);
    expect(await cold.claimDiamondGift(), isFalse);
    expect(cold.diamonds, 6.65);
  });

  for (final throwsWrite in [false, true]) {
    test('礼包写入${throwsWrite ? '异常' : 'false'}向外抛出，同实例与冷启重放不重复奖励', () async {
      final flow = await create(values: {'pc_dollar_number': 100.0});
      await reach(flow, PCWithdrawalPromptKind.giftReward);
      final giftAmount = flow.diamondGiftAmount;
      final prefs = await SharedPreferences.getInstance();
      final original = SharedPreferencesStorePlatform.instance;
      final store = _FailStore({
        for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
      }, throwsWrite: throwsWrite);
      SharedPreferencesStorePlatform.instance = store;
      try {
        await expectLater(flow.claimDiamondGift(), throwsA(isA<StateError>()));
        expect(flow.diamonds, giftAmount);
        expect(
          prefs.containsKey(PCWithdrawalController.giftJournalKey),
          isTrue,
        );
        store.failing = false;
        expect(await flow.claimDiamondGift(), isFalse);
        expect(flow.diamonds, giftAmount);
        final cold = await restore();
        expect(cold.diamonds, giftAmount);
        expect(cold.giftClaimed, isTrue);
        expect(
          prefs.containsKey(PCWithdrawalController.giftJournalKey),
          isFalse,
        );
      } finally {
        SharedPreferencesStorePlatform.instance = original;
      }
    });
  }

  for (final step in [0, 3, 5]) {
    test('午夜优先金猪升级，清理未结束的钻石链第$step步', () async {
      final flow = await create(
        values: {'pc_dollar_number': 100.0, 'pc_quiz_diamonds': 21.25},
      );
      for (var i = 0; i < step; i++) {
        await flow.acknowledge(flow.next!);
      }
      clock.value = DateTime(2026, 10, 27);
      await flow.refresh();
      expect(flow.pending.map((p) => p.kind), [
        PCWithdrawalPromptKind.goldUpgrade,
      ]);
      expect(flow.diamonds, 21.25);
      expect(await flow.claimDiamondGift(), isFalse);
    });
  }

  test('live金砖达到10立即出现queue，配置人数和稳定seed只初始化一次', () async {
    final flow = await create(values: gold(amount: 9.99, rank: 12, total: 40));
    expect(flow.stage, PCWithdrawalStage.releasing);
    expect(flow.next?.kind, PCWithdrawalPromptKind.goldUpgrade);
    await flow.acknowledge(flow.next!);
    expect(flow.hasPending, isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_gold', 10);
    await flow.refresh();
    expect(flow.stage, PCWithdrawalStage.queue);
    expect(flow.next?.kind, PCWithdrawalPromptKind.queue);
    expect([flow.queueRank, flow.queueTotal], [12, 40]);
    expect(prefs.getBool(PCWithdrawalController.gameplayEnabledKey), isTrue);
    final seed = flow.queueSeed;
    await flow.dismiss(flow.next!);
    await flow.refresh();
    expect(flow.hasPending, isFalse);
    final cold = await restore();
    expect(cold.next?.kind, PCWithdrawalPromptKind.queue);
    expect(cold.queueSeed, seed);
    expect([cold.queueRank, cold.queueTotal], [12, 40]);
  });

  for (final throwsAd in [false, true]) {
    test('排队广告${throwsAd ? '异常' : '未成功'}不减排名和人数', () async {
      final flow = await create(
        values: gold(),
        ad: (_) async {
          if (throwsAd) throw StateError('ad failed');
          return false;
        },
      );
      expect(await flow.advanceQueueWithAd(), isFalse);
      expect([flow.queueRank, flow.queueTotal], [9, 20]);
      expect(flow.isBusy, isFalse);
    });
  }

  test('真实激励按两个独立区间扣减，人数不少于排名且排名最低1，第一自动进task', () async {
    final flow = await create(
      values: gold(
        rank: 20,
        total: 30,
        allDelete: [2, 4],
        currentDelete: [5, 9],
      ),
      ad: (_) async => true,
      random: _HighRandom(),
    );
    expect(await flow.advanceQueueWithAd(), isTrue);
    expect([flow.queueRank, flow.queueTotal], [11, 26]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNumberHelpers.configKey,
      jsonEncode({
        'queue_number': [
          {
            'int_all': 100,
            'int_current': 50,
            'int_all_delete': [1000, 1000],
            'int_current_delete': [50, 50],
          },
        ],
      }),
    );
    await prefs.setInt('pc_quiz_all_num', 100);
    expect(await flow.advanceQueueWithAd(), isTrue);
    expect([flow.queueRank, flow.queueTotal], [1, 1]);
    expect(flow.stage, PCWithdrawalStage.lastStep);
    expect(flow.next?.kind, PCWithdrawalPromptKind.lastStep);
    expect(flow.taskProgress, 0);
    await flow.refresh();
    expect(flow.taskProgress, 0);
  });

  test('广告连点只发一次真实请求，迟到成功最多扣一次排名', () async {
    final completion = Completer<bool>();
    var calls = 0;
    final flow = await create(
      values: gold(
        rank: 30,
        total: 50,
        allDelete: [2, 2],
        currentDelete: [3, 3],
      ),
      ad: (_) {
        calls++;
        return completion.future;
      },
    );
    final first = flow.advanceQueueWithAd();
    expect(await flow.advanceQueueWithAd(), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    completion.complete(true);
    expect(await first, isTrue);
    expect([flow.queueRank, flow.queueTotal], [27, 48]);
  });

  test('quiz正确次数delta/spin唯一ID/video真实激励逐项计数，完成自动下一项并最后循环0', () async {
    var adSuccess = false;
    final flow = await create(
      values: {
        ...gold(
          rank: 1,
          tasks: [
            {'title': 'quiz', 'data': 2},
            {'title': 'spin', 'data': 2},
            {'title': 'video', 'data': 2},
          ],
        ),
        'pc_quiz_all_num': 100,
      },
      ad: (_) async => adSuccess,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(flow.stage, PCWithdrawalStage.lastStep);
    expect(flow.taskProgress, 0);
    await flow.dismiss(flow.next!);
    await prefs.setInt('pc_quiz_all_num', 101);
    await flow.refresh();
    expect(flow.taskProgress, 1);
    await flow.refresh();
    expect(flow.taskProgress, 1);
    expect(
      await flow.recordEvent(
        PCWithdrawalEventKind.spin,
        eventId: 'before-task',
      ),
      isFalse,
    );
    await prefs.setInt('pc_quiz_all_num', 102);
    await flow.refresh();
    expect([flow.taskIndex, flow.taskProgress, flow.taskCycle], [1, 0, 0]);
    expect(flow.next?.kind, PCWithdrawalPromptKind.lastStep);
    expect(
      await flow.recordEvent(
        PCWithdrawalEventKind.spin,
        eventId: 'before-task',
      ),
      isFalse,
    );
    expect(
      await flow.recordEvent(PCWithdrawalEventKind.spin, eventId: 'spin-a'),
      isTrue,
    );
    expect(
      await flow.recordEvent(PCWithdrawalEventKind.spin, eventId: 'spin-a'),
      isFalse,
    );
    expect(flow.taskProgress, 1);
    await flow.recordEvent(PCWithdrawalEventKind.spin, eventId: 'spin-b');
    expect([flow.taskIndex, flow.taskProgress], [2, 0]);
    expect(await flow.recordVideoWithAd(), isFalse);
    expect(flow.taskProgress, 0);
    adSuccess = true;
    expect(await flow.recordVideoWithAd(), isTrue);
    expect(flow.taskProgress, 1);
    expect(await flow.recordVideoWithAd(), isTrue);
    expect([flow.taskIndex, flow.taskProgress, flow.taskCycle], [0, 0, 1]);
    expect(flow.next?.id, 'task:1:0');
    final cold = await restore();
    expect([cold.taskIndex, cold.taskProgress, cold.taskCycle], [0, 0, 1]);
    await prefs.setInt('pc_quiz_all_num', 103);
    await cold.refresh();
    expect(cold.taskProgress, 1);
  });

  test('一批积累的答题delta最多完成当前任务，不跨轮消耗旧次数', () async {
    final flow = await create(
      values: {
        ...gold(
          rank: 1,
          tasks: [
            {'title': 'quiz', 'data': 2},
            {'title': 'quiz', 'data': 2},
          ],
        ),
        'pc_quiz_all_num': 100,
      },
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_quiz_all_num', 120);
    await flow.refresh();
    expect([flow.taskIndex, flow.taskProgress], [1, 0]);
    await flow.refresh();
    expect([flow.taskIndex, flow.taskProgress], [1, 0]);
    await prefs.setInt('pc_quiz_all_num', 121);
    await flow.refresh();
    expect(flow.taskProgress, 1);
  });

  test('提现quiz只计真实答对，答错及放弃奖励不计或回退，重复和冷启不重复计数', () async {
    final flow = await create(
      values: gold(
        rank: 1,
        tasks: [
          {'title': 'quiz', 'data': 3},
          {'title': 'spin', 'data': 2},
        ],
      ),
    );
    await flow.dismiss(flow.next!);
    final quiz = PCQuizController(onSync: flow.refresh);
    addTearDown(quiz.dispose);
    await quiz.load();

    await quiz.answer(correct: false, expectedQuestionIndex: 0);
    expect(quiz.questionIndex, 1);
    expect(quiz.correctCount, 0);
    expect(flow.taskProgress, 0);
    final first = (await quiz.answer(correct: true, expectedQuestionIndex: 1))!;
    expect(flow.taskProgress, 1);
    expect(await quiz.answer(correct: true, expectedQuestionIndex: 1), isNull);
    expect(
      await flow.recordEvent(PCWithdrawalEventKind.quiz, eventId: first.id),
      isFalse,
    );
    expect(flow.taskProgress, 1);
    await quiz.discardPendingReward(expectedRewardId: first.id);
    expect(flow.taskProgress, 1);
    await quiz.answer(correct: false, expectedQuestionIndex: 2);
    expect(flow.taskProgress, 1);
    final second = (await quiz.answer(
      correct: true,
      expectedQuestionIndex: 3,
    ))!;
    expect(flow.taskProgress, 2);

    // 即便兼容镜像错误，任务仍以已持久化的真实答对快照为准。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_quiz_all_num', 999);
    await flow.refresh();
    expect(flow.taskProgress, 2);
    final cold = await restore();
    expect(cold.taskProgress, 2);
    final restoredQuiz = PCQuizController(onSync: cold.refresh);
    addTearDown(restoredQuiz.dispose);
    await restoredQuiz.load();
    await restoredQuiz.discardPendingReward(expectedRewardId: second.id);
    await cold.refresh();
    expect(cold.taskProgress, 2);
    expect(restoredQuiz.correctCount, 2);
    await restoredQuiz.answer(correct: true, expectedQuestionIndex: 4);
    expect([cold.taskIndex, cold.taskProgress], [1, 0]);
    final nextCold = await restore();
    expect([nextCold.taskIndex, nextCold.taskProgress], [1, 0]);
  });

  test('旧全部答题游标迁移为正确次数基线，保留任务进度且不补算历史答错', () async {
    final flow = await create(
      values: {
        ...gold(rank: 1),
        'pc_quiz_num_index': 90,
        'pc_quiz_all_num': 5,
        PCWithdrawalController.storageKey: jsonEncode({
          'observedLevel': 2,
          'diamondStep': 7,
          'goldUpgradeAcknowledged': true,
          'queueInitialized': true,
          'queueRank': 1,
          'queueTotal': 20,
          'taskIndex': 0,
          'taskProgress': 1,
          'quizCursor': 90,
          'pending': [],
        }),
      },
    );
    expect(flow.taskProgress, 1);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      prefs.getString(PCWithdrawalController.storageKey)!,
    );
    expect(saved['quizCorrectCursor'], 5);
    expect(saved.containsKey('quizCursor'), isFalse);
    await prefs.setInt('pc_quiz_num_index', 91);
    await flow.refresh();
    expect(flow.taskProgress, 1);
    await prefs.setInt('pc_quiz_all_num', 6);
    await flow.refresh();
    expect(flow.taskProgress, 2);
    expect((await restore()).taskProgress, 2);
  });

  test('配置十项提现任务完成后无限循环，中途冷启保持下一任务与轮次', () async {
    final taskList = List.generate(
      10,
      (index) => <String, Object>{
        'title': ['quiz', 'spin', 'video'][index % 3],
        'data': 1,
      },
    );
    var flow = await create(
      values: gold(rank: 1, tasks: taskList),
      ad: (_) async => true,
    );
    final prefs = await SharedPreferences.getInstance();
    var correct = 0;
    for (var cycle = 0; cycle < 2; cycle++) {
      for (var index = 0; index < taskList.length; index++) {
        expect([flow.taskCycle, flow.taskIndex], [cycle, index]);
        switch (flow.currentTask.title) {
          case 'quiz':
            await prefs.setInt('pc_quiz_all_num', ++correct);
            await flow.refresh();
          case 'spin':
            expect(
              await flow.recordEvent(
                PCWithdrawalEventKind.spin,
                eventId: 'cycle:$cycle:$index',
              ),
              isTrue,
            );
          case 'video':
            expect(await flow.recordVideoWithAd(), isTrue);
        }
        expect(flow.taskProgress, 0);
        if (index == 4) {
          // 新控制器等同冷启，继承广告成功handler后继续真实任务。
          flow = PCWithdrawalController(
            now: clock.now,
            requestAd: (_) async => true,
            scheduleMidnightTimer: false,
          );
          addTearDown(flow.dispose);
          await flow.load();
          expect([flow.taskCycle, flow.taskIndex], [cycle, 5]);
        }
      }
      expect([flow.taskCycle, flow.taskIndex], [cycle + 1, 0]);
      expect(flow.next?.id, 'task:${cycle + 1}:0');
    }
    final cold = await restore();
    expect([cold.taskCycle, cold.taskIndex, cold.taskProgress], [2, 0, 0]);
  });

  test('不足档位提示保留点击金额且可关闭/重开，不改变余额', () async {
    final flow = await create(values: {'pc_dollar_number': 80.0});
    expect(flow.stage, PCWithdrawalStage.insufficient);
    expect(flow.hasPending, isFalse);
    await flow.requestCurrentPrompt(amount: 150);
    expect(flow.next?.kind, PCWithdrawalPromptKind.insufficient);
    expect(flow.next?.withdrawalTarget, 150);
    await flow.dismiss(flow.next!);
    await flow.refresh();
    expect(flow.hasPending, isFalse);
    await flow.requestCurrentPrompt();
    expect(flow.next?.withdrawalTarget, 100);
    expect(flow.balance, 80);
  });

  test('前台跨午夜单次Timer自动升级，不需要用户再次点击', () async {
    clock.value = DateTime(2026, 10, 26, 23, 59, 59, 980);
    SharedPreferences.setMockInitialValues({
      'pc_dollar_number': 100.0,
      'pc_quiz_diamonds': 21.25,
    });
    final flow = PCWithdrawalController(now: clock.now);
    addTearDown(flow.dispose);
    await flow.load();
    expect(flow.pigLevel, 1);
    final upgraded = Completer<void>();
    flow.addListener(() {
      if (flow.pigLevel == 2 && !upgraded.isCompleted) upgraded.complete();
    });
    clock.value = DateTime(2026, 10, 27);
    await upgraded.future.timeout(const Duration(seconds: 2));
    expect(flow.pigLevel, 2);
    expect(flow.next?.kind, PCWithdrawalPromptKind.goldUpgrade);
  });
}
