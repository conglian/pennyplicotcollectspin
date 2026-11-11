import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final now = DateTime(2026, 10, 30, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  Future<PCWithdrawalController> restore() async {
    final flow = PCWithdrawalController(
      now: () => now,
      scheduleMidnightTimer: false,
      requestAd: (_) async => true,
    );
    addTearDown(flow.dispose);
    await flow.load();
    return flow;
  }

  void seedCompletedEntry({
    required int level,
    double diamonds = 3.5,
    double gold = 0,
    int rank = 99,
    int taskIndex = 0,
    int taskCycle = 0,
    int taskProgress = 0,
  }) {
    SharedPreferences.setMockInitialValues({
      'pc_pig_level': level,
      'pc_dollar_number': level == 0 ? 55.0 : 100.0,
      'pc_quiz_diamonds': diamonds,
      'pc_quiz_gold': gold,
      'pc_pig_upgrade_seen_level_v1': level,
      PCPigProgress.diamondEnteredKey: DateTime(
        2026,
        10,
        30,
        9,
      ).toIso8601String(),
      PCPigProgress.diamondDeadlineKey: DateTime(
        2026,
        10,
        31,
      ).toIso8601String(),
      PCWithdrawalController.storageKey: jsonEncode({
        'version': 1,
        'observedLevel': level,
        'diamondStarted': level != 0,
        'diamondStep': 7,
        'giftClaimed': level != 0,
        'reviewBaseline': 40,
        'goldUpgradeAcknowledged': level == 2,
        'queueInitialized': level == 2 && gold >= 10,
        'queueRank': rank,
        'queueTotal': 388,
        'queueSeed': 123,
        'taskIndex': taskIndex,
        'taskCycle': taskCycle,
        'taskProgress': taskProgress,
        'quizCursor': 0,
        'pending': <Map<String, dynamic>>[],
      }),
    });
  }

  Future<void> dismissAndRefresh(
    PCWithdrawalController flow,
    PCWithdrawalPromptKind expected,
  ) async {
    expect(flow.pending, hasLength(1));
    expect(flow.next?.kind, expected);
    await flow.dismiss(flow.next!);
    // 切页、前后台恢复及Host暖重建都沿用同实例，只刷新，不再消费一次冷启。
    for (var i = 0; i < 3; i++) {
      await flow.refresh();
      expect(flow.pending, isEmpty);
    }
    await flow.load();
    expect(flow.pending, isEmpty);
  }

  for (final diamonds in [3.5, 21.25]) {
    test('钻石$diamonds冷启恢复收集或倒计时，关闭后同次不重弹', () async {
      seedCompletedEntry(level: 1, diamonds: diamonds);
      for (var coldStart = 0; coldStart < 3; coldStart++) {
        final flow = await restore();
        expect(flow.pigLevel, 1);
        expect(
          flow.stage,
          diamonds < 20
              ? PCWithdrawalStage.reviewing
              : PCWithdrawalStage.reviewApproved,
        );
        expect(flow.diamonds, diamonds);
        expect(flow.gold, 0);
        expect(flow.reviewBaseline, 40);
        expect(flow.giftClaimed, isTrue);
        await dismissAndRefresh(
          flow,
          diamonds < 20
              ? PCWithdrawalPromptKind.diamondCollect
              : PCWithdrawalPromptKind.diamondCountdown,
        );
      }
    });
  }

  test('已关闭金猪升级提示后，金砖不足10每次冷启恢复收集框，同次刷新不循环', () async {
    seedCompletedEntry(level: 2, gold: 6.25);
    for (var coldStart = 0; coldStart < 3; coldStart++) {
      final flow = await restore();
      expect(flow.stage, PCWithdrawalStage.releasing);
      expect(flow.gold, 6.25);
      await dismissAndRefresh(flow, PCWithdrawalPromptKind.goldUpgrade);
    }
  });

  test('排队冷启恢复当前名次和总人数，关闭后刷新不重弹也不重置队列', () async {
    seedCompletedEntry(level: 2, gold: 12.5, rank: 94);
    for (var coldStart = 0; coldStart < 3; coldStart++) {
      final flow = await restore();
      expect(flow.stage, PCWithdrawalStage.queue);
      expect(flow.queueRank, 94);
      expect(flow.queueTotal, 388);
      expect(flow.gold, 12.5);
      await dismissAndRefresh(flow, PCWithdrawalPromptKind.queue);
    }
  });

  test('最后任务每次冷启恢复同一轮次和已做进度，关闭或刷新不重置', () async {
    seedCompletedEntry(
      level: 2,
      gold: 10,
      rank: 1,
      taskIndex: 1,
      taskCycle: 2,
      taskProgress: 3,
    );
    for (var coldStart = 0; coldStart < 3; coldStart++) {
      final flow = await restore();
      expect(flow.stage, PCWithdrawalStage.lastStep);
      expect(flow.queueRank, 1);
      expect(flow.taskIndex, 1);
      expect(flow.taskCycle, 2);
      expect(flow.taskProgress, 3);
      expect(flow.currentTask.title, 'spin');
      expect(flow.next?.taskIndex, 1);
      expect(flow.next?.taskCycle, 2);
      await dismissAndRefresh(flow, PCWithdrawalPromptKind.lastStep);
    }
  });

  test('粉猪冷启不主动显示提现状态框', () async {
    seedCompletedEntry(level: 0, diamonds: 0);
    for (var coldStart = 0; coldStart < 2; coldStart++) {
      final flow = await restore();
      expect(flow.stage, PCWithdrawalStage.insufficient);
      expect(flow.pending, isEmpty);
    }
  });

  test('首次钻石七步按顺序恢复，不跳过审核且礼包重启后不重复加钻', () async {
    SharedPreferences.setMockInitialValues({
      'pc_pig_level': 1,
      'pc_dollar_number': 100.0,
      'pc_quiz_diamonds': 3.5,
      'pc_quiz_gold': 0.0,
      'pc_pig_upgrade_seen_level_v1': 0,
    });
    var flow = await restore();
    expect(flow.next?.kind, PCWithdrawalPromptKind.diamondUpgrade);
    await flow.acknowledge(flow.next!);
    expect(flow.next?.kind, PCWithdrawalPromptKind.reviewPending);
    await flow.acknowledge(flow.next!);
    expect(flow.reviewBaseline, 40);
    await dismissAndRefresh(flow, PCWithdrawalPromptKind.reviewVerification);

    flow = await restore();
    for (final step in [
      PCWithdrawalPromptKind.reviewVerification,
      PCWithdrawalPromptKind.channelActivated,
      PCWithdrawalPromptKind.priorityGift,
    ]) {
      expect(flow.pending, hasLength(1));
      expect(flow.next?.kind, step);
      await flow.acknowledge(flow.next!);
    }
    expect(flow.next?.kind, PCWithdrawalPromptKind.giftReward);
    final giftAmount = flow.diamondGiftAmount;
    expect(await flow.claimDiamondGift(), isTrue);
    expect(flow.diamonds, 3.5 + giftAmount);
    expect(flow.pending, isEmpty);
    expect(flow.diamondDeadline, isNull);
    await flow.refresh();
    expect(flow.pending, isEmpty);

    flow = await restore();
    expect(flow.next?.kind, PCWithdrawalPromptKind.diamondCollect);
    expect(flow.giftClaimed, isTrue);
    expect(await flow.claimDiamondGift(), isFalse);
    expect(flow.diamonds, 3.5 + giftAmount);
    await dismissAndRefresh(flow, PCWithdrawalPromptKind.diamondCollect);
  });
}
