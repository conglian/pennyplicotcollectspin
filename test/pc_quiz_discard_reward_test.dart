import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PCQuizController> loadController({
    Future<void> Function()? onSync,
  }) async {
    final controller = PCQuizController(random: Random(7), onSync: onSync);
    await controller.load();
    addTearDown(controller.dispose);
    return controller;
  }

  for (final reason in ['关闭奖励框', '激励失败或取消']) {
    test('$reason后不发奖，切页和冷启动均不恢复，下一题继续作答', () async {
      final controller = await loadController();
      final reward = (await controller.answer(
        correct: true,
        expectedQuestionIndex: 0,
      ))!;
      expect(
        await controller.discardPendingReward(expectedRewardId: reward.id),
        isTrue,
      );
      expect(controller.pendingReward, isNull);
      expect(controller.balance, 0);
      expect(controller.questionIndex, 1);
      expect(controller.correctCount, 1);
      expect(
        await controller.answer(correct: true, expectedQuestionIndex: 0),
        isNull,
        reason: '关闭后不能重答同一道题再次弹奖',
      );
      await controller.refreshBalance();
      expect(controller.pendingReward, isNull, reason: '切回Tab刷新也无旧奖');
      final restarted = await loadController();
      expect(restarted.pendingReward, isNull);
      expect(restarted.balance, 0);
      expect(restarted.questionIndex, 1);
      expect(restarted.correctCount, 1);
      final next = (await restarted.answer(
        correct: true,
        expectedQuestionIndex: 1,
      ))!;
      expect(next.id, isNot(reward.id));
      expect(restarted.correctCount, 2);
      expect(restarted.spins, 1, reason: '放弃现金奖励不撤销真实答题赠次');
    });
  }

  test('旧Claim和旧关闭回调不能领取或清除下一题奖励', () async {
    final controller = await loadController();
    final old = (await controller.answer(correct: true))!;
    await controller.discardPendingReward(expectedRewardId: old.id);
    final current = (await controller.answer(correct: true))!;
    expect(await controller.claim(expectedRewardId: old.id), isNull);
    expect(
      await controller.discardPendingReward(expectedRewardId: old.id),
      isFalse,
    );
    expect(controller.pendingReward?.id, current.id);
    expect(controller.balance, 0);
    expect(
      (await controller.claim(expectedRewardId: current.id))?.id,
      current.id,
    );
    expect(controller.balance, current.amount);
    expect(await controller.claim(expectedRewardId: current.id), isNull);
  });

  test('放弃在途时拒绝重复答题和Claim，重复关闭仅清除一次', () async {
    final controller = await loadController();
    final reward = (await controller.answer(correct: true))!;
    final discarded = controller.discardPendingReward(
      expectedRewardId: reward.id,
    );
    final claimed = controller.claim(expectedRewardId: reward.id);
    final answered = controller.answer(correct: true);
    final secondDiscard = controller.discardPendingReward(
      expectedRewardId: reward.id,
    );
    expect(await discarded, isTrue);
    expect(await claimed, isNull);
    expect(await answered, isNull);
    expect(await secondDiscard, isFalse);
    expect(controller.pendingReward, isNull);
    expect(controller.balance, 0);
    expect(controller.questionIndex, 1);
    expect(controller.correctCount, 1);
  });

  test('放弃等待在途答题完成，排队的余额刷新不能以旧快照恢复待奖', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var holdSync = false;
    final controller = await loadController(
      onSync: () async {
        if (!holdSync) return;
        holdSync = false;
        entered.complete();
        await release.future;
      },
    );
    holdSync = true;
    final answering = controller.answer(correct: true);
    await entered.future;
    final reward = controller.pendingReward!;
    final discard = controller.discardPendingReward(
      expectedRewardId: reward.id,
    );
    final refresh = controller.refreshBalance();
    release.complete();
    expect((await answering)?.id, reward.id);
    expect(await discard, isTrue);
    await refresh;
    final restarted = await loadController();
    expect(restarted.pendingReward, isNull);
    expect(restarted.balance, 0);
    expect(restarted.questionIndex, 1);
  });

  test('成功Claim先开始时关闭等待结算，不能清除后续或重复结算', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var holdSync = false;
    final controller = await loadController(
      onSync: () async {
        if (!holdSync) return;
        holdSync = false;
        entered.complete();
        await release.future;
      },
    );
    final reward = (await controller.answer(correct: true))!;
    holdSync = true;
    final claim = controller.claim(expectedRewardId: reward.id);
    await entered.future;
    final discard = controller.discardPendingReward(
      expectedRewardId: reward.id,
    );
    release.complete();
    expect((await claim)?.id, reward.id);
    expect(await discard, isFalse);
    expect(controller.balance, reward.amount);
    expect(controller.pendingReward, isNull);
  });

  for (final flowAlreadyWritten in [false, true]) {
    test('放弃日志中断恢复：flow已写=$flowAlreadyWritten，不发奖/不补赠次数', () async {
      final controller = await loadController();
      final first = (await controller.answer(correct: true))!;
      await controller.discardPendingReward(expectedRewardId: first.id);
      final second = (await controller.answer(correct: true))!;
      expect(controller.spins, 1);
      final prefs = await SharedPreferences.getInstance();
      final flow = Map<String, dynamic>.from(
        jsonDecode(prefs.getString(PCQuizController.storageKey)!) as Map,
      )..remove('pendingReward');
      await prefs.setString(
        PCQuizController.journalKey,
        jsonEncode({'action': 'discard', 'rewardId': second.id, 'flow': flow}),
      );
      if (flowAlreadyWritten) {
        await prefs.setString(PCQuizController.storageKey, jsonEncode(flow));
      }
      final restarted = await loadController();
      expect(restarted.pendingReward, isNull);
      expect(restarted.balance, 0);
      expect(restarted.correctCount, 2);
      expect(restarted.questionIndex, 2);
      expect(restarted.spins, 1);
      expect(prefs.getString(PCQuizController.journalKey), isNull);
      final restartedAgain = await loadController();
      expect(restartedAgain.pendingReward, isNull);
      expect(restartedAgain.spins, 1);
    });
  }

  test('放弃钻石与金砖奖励不改变任何已到账资产', () async {
    for (final level in [1, 2]) {
      SharedPreferences.setMockInitialValues({
        'pc_dollar_number': 100.0,
        'pc_pig_level': level,
        'pc_quiz_diamonds': 3.0,
        'pc_quiz_gold': level == 2 ? 2.0 : 0.0,
      });
      final controller = await loadController();
      final reward = (await controller.answer(correct: true))!;
      expect(reward.type, PCQuizRewardType.values[level]);
      await controller.discardPendingReward(expectedRewardId: reward.id);
      expect(controller.pendingReward, isNull);
      expect(controller.balance, 100);
      expect(controller.diamonds, 3);
      expect(controller.gold, level == 2 ? 2 : 0);
      final restarted = await loadController();
      expect(restarted.pendingReward, isNull);
      expect(restarted.diamonds, 3);
      expect(restarted.gold, level == 2 ? 2 : 0);
    }
  });
}
