import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCConfirmAccountDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessAccountDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessAccountConfirmedDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCQuizRankingDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCReviewProgressDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigUpgradeController.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessFlowController.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessFlowHost.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  Future<PCProcessFlowController> flow(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final result = PCProcessFlowController(random: Random(17));
    await result.refresh();
    addTearDown(result.dispose);
    return result;
  }

  test('未完成引导不生成流程；3题无账号只提醒一次且冷启动防重', () async {
    SharedPreferences.setMockInitialValues({'pc_quiz_num_index': 3});
    final first = PCProcessFlowController();
    await first.refresh(guideComplete: false);
    expect(first.hasPending, isFalse);
    await first.refresh();
    expect(first.next!.id, 'account:first');
    final restored = PCProcessFlowController();
    await restored.refresh();
    expect(restored.next!.id, 'account:first');
    await restored.begin(restored.next!);
    expect(restored.hasPending, isTrue);
    restored.finish();
    final cold = PCProcessFlowController();
    await cold.refresh();
    expect(cold.hasPending, isFalse);
    first.dispose();
    restored.dispose();
    cold.dispose();
  });

  test('已有账号进度严格超过首档80%，确认后不重复触发', () async {
    final f = await flow({
      'pc_account_id': 'a***@mail.com',
      'pc_dollar_number': 80.0,
    });
    expect(f.hasPending, isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_dollar_number', 80.01);
    await f.refresh();
    expect(f.next!.accountSaved, isTrue);
    await f.accountConfirmed();
    expect(f.hasPending, isFalse);
    await f.refresh();
    expect(f.hasPending, isFalse);
  });

  test('新用户已提交账号完成3题和80%两触发，旧待办清理且冷启动不重弹', () async {
    final f = await flow({'pc_quiz_num_index': 3, 'pc_dollar_number': 30.0});
    expect(f.next!.id, 'account:first');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      jsonEncode({'stage': 'complete', 'confirmedUser': 'p***.com'}),
    );
    await prefs.setInt('pc_account_seled_index', 2);
    await f.refresh();
    expect(f.savedAccount, 'p***.com');
    expect(prefs.getString('pc_account_id'), 'p***.com');
    expect(prefs.getInt('pc_account_seled_index'), 2);
    expect(
      f.pending.where((p) => p.kind == PCProcessPromptKind.confirmAccount),
      isEmpty,
    );
    final stored =
        jsonDecode(prefs.getString(PCProcessFlowController.storageKey)!) as Map;
    expect(stored['seen'], containsAll(['account:first', 'account:80']));
    await prefs.setDouble('pc_dollar_number', 85);
    await f.refresh();
    expect(f.hasPending, isFalse);
    final cold = PCProcessFlowController();
    await cold.refresh();
    expect(cold.hasPending, isFalse);
    expect(cold.savedAccount, 'p***.com');
    cold.dispose();
  });

  test('填写前已load的控制器会在同进程后续refresh识别新提交，排行仍正常', () async {
    SharedPreferences.setMockInitialValues({'pc_quiz_num_index': 3});
    final f = PCProcessFlowController();
    await f.refresh(guideComplete: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      jsonEncode({
        'stage': 'officialNotice',
        'confirmedUser': 'new@example.com',
      }),
    );
    await f.refresh(guideComplete: false);
    expect(f.savedAccount, isNot('new@example.com'));
    expect(f.savedAccount, contains('*'));
    expect(f.hasPending, isFalse);
    await prefs.setDouble('pc_dollar_number', 85);
    await f.refresh();
    expect(f.hasPending, isFalse);
    await prefs.setInt('pc_quiz_num_index', 8);
    await f.refresh();
    expect(f.next!.kind, PCProcessPromptKind.quizRanking);
    f.dispose();
  });

  test('3.7首次有效确认一并完成80%触发，已有公共账号优先于旧引导显示名', () async {
    final f = await flow({'pc_quiz_num_index': 3, 'pc_dollar_number': 30.0});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pc_account_id', 'n***7890');
    await f.accountConfirmed();
    await prefs.setDouble('pc_dollar_number', 85);
    await f.refresh();
    expect(f.hasPending, isFalse);
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      '{"stage":"complete","confirmedUser":"old***.com"}',
    );
    await f.refresh();
    expect(f.savedAccount, 'n***7890');
    final cold = PCProcessFlowController();
    await cold.refresh();
    expect(cold.hasPending, isFalse);
    cold.dispose();
  });

  test('未填写、空确认字段和损坏引导档均不当作已确认，仍按3题触发', () async {
    for (final raw in ['{}', '{"confirmedUser":"  "}', 'broken']) {
      SharedPreferences.setMockInitialValues({
        'pc_quiz_num_index': 3,
        PCNewUserGuideController.flowKey: raw,
      });
      final f = PCProcessFlowController();
      await f.refresh();
      expect(f.next!.id, 'account:first');
      expect(f.savedAccount, isEmpty);
      f.dispose();
    }
  });

  test('排行按全部答题数8/15/20，保留种子并显示等待期间最新次数', () async {
    final f = await flow({
      'pc_account_id': 'a***@mail.com',
      'pc_quiz_num_index': 7,
      'pc_quiz_all_num': 20,
    });
    expect(f.hasPending, isFalse, reason: '正确次数不是总答题数');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_quiz_num_index', 8);
    await f.refresh();
    final seed = f.next!.seed;
    await prefs.setInt('pc_quiz_num_index', 9);
    await f.refresh();
    expect(f.next!.answerCount, 9);
    expect(f.next!.seed, seed);
    await f.begin(f.next!);
    f.finish();
    await f.refresh();
    expect(f.hasPending, isFalse);
    await prefs.setInt('pc_quiz_num_index', 20);
    await f.refresh();
    expect(f.pending.map((p) => p.id), ['ranking:20']);
  });

  test('钻石审核30/50/80%边界严格大于，进度75→89→99持久化', () async {
    final f = await flow({'pc_pig_level': 1, 'pc_quiz_diamonds': 6.0});
    expect(f.hasPending, isFalse);
    final prefs = await SharedPreferences.getInstance();
    for (final pair in [(6.01, 75), (10.01, 89), (16.01, 99)]) {
      await prefs.setDouble('pc_quiz_diamonds', pair.$1);
      await f.refresh();
      expect(f.next!.toProgress, pair.$2);
      expect(f.next!.fromProgress, f.reviewProgress);
      await f.begin(f.next!);
      f.finish();
    }
    final cold = PCProcessFlowController();
    await cold.refresh();
    expect(cold.reviewProgress, 99);
    expect(cold.hasPending, isFalse);
    cold.dispose();
  });

  test('高进度只补最新审核，先审核后钻石提醒再官方通知且不改余额', () async {
    final f = await flow({
      'pc_pig_level': 1,
      'pc_quiz_diamonds': 19.99,
      'pc_dollar_number': 100.0,
    });
    expect(f.pending.map((p) => p.id), [
      'review:99',
      'diamond:90',
      'official:0.01',
    ]);
    expect(f.pending.last.remaining, .01);
    for (final p in f.pending) {
      await f.begin(p);
      f.finish();
    }
    await f.refresh();
    expect(f.hasPending, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('pc_quiz_diamonds'), 19.99);
    expect(prefs.getDouble('pc_dollar_number'), 100);
  });

  test('官方通知剩余1/0.1/0.01各一次，显示实时数量，金猪清理旧钻石提示', () async {
    final f = await flow({'pc_pig_level': 1, 'pc_pig_level_index': 19.0});
    final prefs = await SharedPreferences.getInstance();
    for (final quantity in [19.0, 19.9, 19.99]) {
      await prefs.setDouble('pc_pig_level_index', quantity);
      await f.refresh();
      final prompt = f.pending.singleWhere(
        (p) => p.kind == PCProcessPromptKind.officialNotice,
      );
      expect(prompt.remaining, closeTo(20 - quantity, .00001));
      await f.begin(prompt);
      f.finish();
    }
    await prefs.setInt('pc_pig_level', 2);
    await f.refresh();
    expect(f.hasPending, isFalse);
  });

  Future<void> advance(WidgetTester tester, Duration duration) async {
    var remaining = duration.inMilliseconds;
    while (remaining > 0) {
      final step = min(remaining, 50);
      await tester.pump(Duration(milliseconds: step));
      remaining -= step;
    }
    await tester.pump();
  }

  Future<void> host(
    WidgetTester tester,
    PCProcessFlowController f, {
    VoidCallback? onGoQuiz,
  }) async {
    await PCLocalProvider.instance.init();
    await PCPigUpgradeController.instance.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: PCProcessFlowHost(
          controller: f,
          canPresent: () => true,
          onGoQuiz: onGoQuiz ?? () {},
          child: const Scaffold(body: Text('Quiz body')),
        ),
      ),
    );
    await tester.pump();
    await advance(tester, const Duration(milliseconds: 300));
  }

  Future<void> clean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
    expect(PCPigUpgradeController.instance.isBlocked, isFalse);
  }

  testWidgets('待领奖优先，奖励解除后才出现排行，关闭后冷启动不再提示', (tester) async {
    final f = await flow({
      'pc_account_id': 'a***@mail.com',
      'pc_quiz_num_index': 8,
      PCQuizController.storageKey: jsonEncode({'pendingReward': {}}),
    });
    await host(tester, f);
    expect(find.byType(PCQuizRankingDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PCQuizController.storageKey);
    await PCLocalProvider.instance.init();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PCQuizRankingDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcQuizRankContinue')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(f.hasPending, isFalse);
    await clean(tester);
    final cold = PCProcessFlowController();
    await cold.refresh();
    expect(cold.hasPending, isFalse);
    cold.dispose();
  });

  testWidgets('到账动画持有期间不消费提示，释放后只显示一个', (tester) async {
    final f = await flow({
      'pc_pig_level': 1,
      'pc_pig_upgrade_seen_level_v1': 1,
      'pc_quiz_diamonds': 7.0,
    });
    final release = PCDialogCoordinator.instance.holdPresentation();
    await host(tester, f);
    expect(find.byType(PCReviewProgressDialog), findsNothing);
    expect(f.next!.id, 'review:75');
    release();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PCReviewProgressDialog), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(PCReviewProgressDialog), findsOneWidget);
    expect(PCDialogCoordinator.instance.isBusy, isTrue);
    expect(PCPigUpgradeController.instance.isBlocked, isTrue);
    await tester.tap(find.byKey(const ValueKey('pcProcessContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(f.hasPending, isFalse);
    await clean(tester);
  });

  testWidgets('无账号确认→四渠道填写→脱敏保存→成功横幅退场后继续答题', (tester) async {
    final f = await flow({'pc_quiz_num_index': 3, 'pc_dollar_number': 30.0});
    var navigated = 0;
    await host(tester, f, onGoQuiz: () => navigated++);
    expect(find.byType(PCConfirmAccountDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcConfirmAccountAction')));
    await advance(tester, const Duration(milliseconds: 650));
    expect(find.byType(PCConfirmAccountDialog), findsNothing);
    expect(find.byType(PCProcessAccountDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('pcProcessAccountInput')),
      'hello@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
    await advance(tester, const Duration(milliseconds: 850));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pc_account_id'), contains('*'));
    expect(prefs.getString('pc_account_id'), isNot('hello@example.com'));
    expect(find.byType(PCProcessAccountConfirmedDialog), findsOneWidget);
    expect(navigated, 0);
    await advance(tester, const Duration(milliseconds: 3200));
    expect(navigated, 1);
    expect(f.hasPending, isFalse);
    await clean(tester);
  });

  for (final channel in [(1, 2, 'pay***@mail.com'), (2, 1, '12***89012')]) {
    testWidgets('已有账号超过80%直开表单，缓存渠道${channel.$1}回填和保存不互换', (tester) async {
      final f = await flow({
        'pc_account_id': channel.$3,
        'pc_account_seled_index': channel.$1,
        'pc_dollar_number': 80.01,
      });
      var navigated = 0;
      await host(tester, f, onGoQuiz: () => navigated++);
      expect(find.byType(PCConfirmAccountDialog), findsNothing);
      expect(find.byType(PCProcessAccountDialog), findsOneWidget);
      final input = find.byKey(const ValueKey('pcProcessAccountInput'));
      expect(tester.widget<TextField>(input).controller!.text, channel.$3);
      for (final index in [0, 1, 2, 3]) {
        expect(
          find.byKey(ValueKey('pcProcessMethod$index')),
          index == channel.$2 ? findsOneWidget : findsNothing,
        );
      }
      await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
      await advance(tester, const Duration(milliseconds: 850));
      expect(find.byType(PCProcessAccountConfirmedDialog), findsOneWidget);
      expect(navigated, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('pc_account_seled_index'), channel.$1);
      expect(prefs.getString('pc_account_id'), channel.$3);
      await advance(tester, const Duration(milliseconds: 3200));
      expect(navigated, 1);
      expect(f.hasPending, false);
      await clean(tester);
    });
  }

  testWidgets('后台启动不显示或消费提示，回前台才展示并保存防重', (tester) async {
    final f = await flow({'pc_quiz_num_index': 3});
    final release = PCDialogCoordinator.instance.holdPresentation();
    await host(tester, f);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    release();
    await advance(tester, const Duration(seconds: 2));
    expect(find.byType(PCConfirmAccountDialog), findsNothing);
    expect(f.next?.id, 'account:first');
    expect(f.isPresenting, false);
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(PCProcessFlowController.storageKey)!) as Map;
    expect(stored['seen'], isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await advance(tester, const Duration(milliseconds: 350));
    expect(find.byType(PCConfirmAccountDialog), findsOneWidget);
    expect(f.next, isNull);
    await tester.tap(find.byKey(const ValueKey('pcConfirmAccountClose')));
    await advance(tester, const Duration(milliseconds: 350));
    expect(f.hasPending, false);
    await clean(tester);
  });
}
