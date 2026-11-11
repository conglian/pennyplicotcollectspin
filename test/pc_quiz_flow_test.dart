import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'support/pc_number_test_assets.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizContentPanel.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWithdrawPage.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessFlowController.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelOpportunityStore.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/pc_shou_icon.dart';

void quizWidgets(String name, WidgetTesterCallback callback) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await callback(tester);
  });
}

Future<PCQuizController> controller() async {
  final result = PCQuizController(random: Random(7));
  await result.load();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  Future<bool> Function(String)? previousRewardedHandler;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previousRewardedHandler = PCRewardedAdService.instance.handler;
    PCRewardedAdService.instance.handler = (_) async => true;
  });
  tearDown(() {
    PCRewardedAdService.instance.handler = previousRewardedHandler;
  });

  Future<void> bannerAfterEachAnswer() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      PCNumberHelpers.configKey,
      jsonEncode({'quiz_console': 1}),
    );
  }

  // 通过真实答错、1秒对错反馈和1秒流程延迟触发横幅，不依赖无操作计时。
  Future<void> answerForBanner(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  test('错误只换题，正确才计数和保存待领奖励；领奖前不加余额', () async {
    final c = await controller();
    expect(await c.answer(correct: false), isNull);
    expect(c.questionIndex, 1);
    expect(c.correctCount, 0);
    final reward = await c.answer(correct: true);
    expect(reward, isNotNull);
    expect(c.correctCount, 1);
    expect(c.balance, 0);
    expect(c.pendingReward?.id, reward!.id);
    await c.answer(correct: true);
    expect(c.correctCount, 1);
    final results = await Future.wait([c.claim(), c.claim()]);
    expect(results.whereType<PCQuizReward>(), hasLength(1));
    expect(c.balance, reward.amount);
    expect(c.pendingReward, isNull);
    c.dispose();
  });
  test('2、5、8题产生机会，错误不加机会；转盘入口只处理一次', () async {
    final c = await controller();
    for (var n = 1; n <= 8; n++) {
      await c.answer(correct: true);
      await c.claim();
      expect(
        c.spins,
        n < 2
            ? 0
            : n < 5
            ? 1
            : n < 8
            ? 2
            : 3,
      );
      await c.answer(correct: false);
    }
    expect(await c.openMilestone(0), isTrue);
    expect(await c.openMilestone(0), isFalse);
    expect(await c.openMilestone(3), isFalse);
    expect(c.spins, 3);
    final prefs = await SharedPreferences.getInstance();
    await PCWheelOpportunityStore.transaction(prefs, (ledger) async {
      await ledger.consumeWheel('used_spin_1');
      await ledger.consumeWheel('used_spin_2');
    });
    await c.answer(correct: false);
    expect(c.spins, 1, reason: '已使用的机会不能被旧快照恢复');
    c.dispose();
  });
  test('题号防重：旧题答错后改点正确和已领奖旧题均不能再次发奖', () async {
    final c = await controller();
    await c.answer(correct: false, expectedQuestionIndex: 0);
    expect(await c.answer(correct: true, expectedQuestionIndex: 0), isNull);
    expect(c.correctCount, 0);
    expect(c.pendingReward, isNull);
    final results = await Future.wait([
      c.answer(correct: true, expectedQuestionIndex: 1),
      c.answer(correct: true, expectedQuestionIndex: 1),
    ]);
    expect(results.whereType<PCQuizReward>(), hasLength(1));
    expect(c.correctCount, 1);
    await c.claim();
    final balance = c.balance;
    expect(await c.answer(correct: true, expectedQuestionIndex: 1), isNull);
    expect(c.balance, balance);
    expect(c.correctCount, 1);
    c.dispose();
  });
  test('冷启动保留待领奖励和原奖额，不重新随机、不重复加钱', () async {
    var c = await controller();
    final r = await c.answer(correct: true);
    c.dispose();
    c = await controller();
    expect(c.pendingReward?.toJson(), r!.toJson());
    expect(c.questionIndex, 1);
    expect(c.balance, 0);
    await c.claim();
    final balance = c.balance;
    c.dispose();
    c = await controller();
    expect(c.pendingReward, isNull);
    expect(c.balance, balance);
    expect(await c.claim(), isNull);
    expect(c.balance, balance);
    c.dispose();
  });
  test('领取日志在余额已写、进度未写时恢复，只发一次', () async {
    var c = await controller();
    final r = (await c.answer(correct: true))!;
    c.dispose();
    final p = await SharedPreferences.getInstance();
    final flow =
        jsonDecode(p.getString(PCQuizController.storageKey)!)
            as Map<String, dynamic>;
    flow.remove('pendingReward');
    await p.setDouble('pc_dollar_number', r.amount);
    await p.setString(
      PCQuizController.journalKey,
      jsonEncode({'rewardId': r.id, 'balanceAfter': r.amount, 'flow': flow}),
    );
    c = await controller();
    expect(c.balance, r.amount);
    expect(c.pendingReward, isNull);
    expect(p.getString(PCQuizController.journalKey), isNull);
    c.dispose();
  });
  test('首次100转钻石、20钻当日不升级、隔夜转金砖；不折算纸钞', () async {
    SharedPreferences.setMockInitialValues({'pc_dollar_number': 99.99});
    var c = await controller();
    var r = (await c.answer(correct: true))!;
    expect(r.type, PCQuizRewardType.cash);
    expect(r.amount, .01);
    await c.claim();
    expect(c.balance, 100);
    expect(c.stage, PCQuizRewardType.diamond);
    c.dispose();
    final p = await SharedPreferences.getInstance();
    final flow =
        jsonDecode(p.getString(PCQuizController.storageKey)!)
            as Map<String, dynamic>;
    flow['diamonds'] = 19.99;
    await p.setString(PCQuizController.storageKey, jsonEncode(flow));
    c = await controller();
    r = (await c.answer(correct: true))!;
    expect(r.type, PCQuizRewardType.diamond);
    expect(r.amount, .01);
    await c.claim();
    expect(c.diamonds, 20);
    expect(c.stage, PCQuizRewardType.diamond);
    expect(c.balance, 100);
    final extra = await c.answer(correct: true);
    expect(extra!.type, PCQuizRewardType.diamond);
    expect(extra.amount, greaterThan(0));
    await c.claim();
    expect(c.diamonds, greaterThan(20));
    expect(c.stage, PCQuizRewardType.diamond);
    c.dispose();
    final today = DateTime.now();
    await p.setString(
      PCPigProgress.diamondDeadlineKey,
      DateTime(today.year, today.month, today.day).toIso8601String(),
    );
    flow['diamonds'] = 20;
    flow['gold'] = 9.99;
    await p.setString(PCQuizController.storageKey, jsonEncode(flow));
    c = await controller();
    r = (await c.answer(correct: true))!;
    expect(r.type, PCQuizRewardType.gold);
    expect(r.amount, .01);
    await c.claim();
    expect(c.gold, 10);
    expect(c.isComplete, isFalse);
    expect(c.balance, 100);
    final goldAfterTarget = (await c.answer(correct: true))!;
    expect(goldAfterTarget.type, PCQuizRewardType.gold);
    expect(goldAfterTarget.amount, inInclusiveRange(.01, .02));
    await c.claim();
    expect(c.gold, greaterThan(10));
    c.dispose();
  });
  test('远程区间生效且卡尾值，异常配置使用默认奖励', () {
    final config = PCQuizConfig.fromRaw(
      jsonEncode({
        'eq_range': [120],
        'money_prize': [
          {
            'end_number': 50,
            'prize': [20, 20],
          },
        ],
        'diamond_prize': [
          {
            'end_number': 5,
            'prize': [.25, .25],
          },
        ],
        'gold_prize': [
          {
            'end_number': 8,
            'prize': [.12, .12],
          },
        ],
      }),
    );
    expect(config.withdrawalTarget, 120);
    expect(config.prize(PCQuizRewardType.cash, 49.99, Random(1)), .01);
    expect(config.prize(PCQuizRewardType.diamond, 0, Random(1)), .25);
    expect(config.prize(PCQuizRewardType.gold, 0, Random(1)), .12);
    expect(
      PCQuizConfig.fromRaw('bad').prize(PCQuizRewardType.cash, 0, Random(1)),
      inInclusiveRange(10, 20),
    );
  });
  quizWidgets('确认 Cash App 后保存正确图标序号，领奖展示选中的收款渠道', (tester) async {
    final provider = PCLocalProvider.instance;
    await provider.init();
    PCWithdrawDetails? result;
    await tester.pumpWidget(
      MaterialApp(
        home: PCWithdrawPage(
          initialMethod: PCWithdrawMethod.cashApp,
          onSubmitted: (details) => result = details,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '2025550123');
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(result?.method, PCWithdrawMethod.cashApp);
    expect(provider.pc_account_seled_index, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(provider.pc_account_seled_indexName), 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PCAwardDialog(
            award: 1,
            balance: 100,
            paymentAsset: 'pc_act_${provider.pc_account_seled_index}',
            reward: const PCQuizReward(
              id: 'diamond',
              type: PCQuizRewardType.diamond,
              amount: 1,
              questionIndex: 0,
            ),
            remainingCollectible: 20,
          ),
        ),
      ),
    );
    expect(
      find.byWidgetPredicate((w) => w is PCImg && w.name == 'pc_act_2'),
      findsOneWidget,
    );
    expect(
      find.text('Only \$0 Left To Withdraw', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Diamonds Left'), findsNothing);
    expect(find.text('To Withdraw \$100'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is PCImg && w.name == 'pc_award_diamond'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is PCImg && w.name == 'pc_ad_icon'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    quizWidgets('普通答题在 $size 下对错显示1秒且每题仅首击有效、领奖动画和消息', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = PCLocalProvider.instance;
      await provider.init();
      final bank = PCQuizBank.fromQuestions(const [
        PCQuizQuestion(
          question: 'What color is a ripe banana?',
          a: 'Green',
          b: 'Yellow',
          answer: 'b',
        ),
        PCQuizQuestion(
          question: 'Which fruit is sweet?',
          a: 'Stone',
          b: 'Mango',
          answer: 'b',
        ),
        PCQuizQuestion(
          question: 'Which fruit is red?',
          a: 'Apple',
          b: 'Grass',
          answer: 'a',
        ),
      ]);
      final flow = PCQuizController(random: Random(2), onSync: provider.init);
      await flow.load();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (_, child) => MaterialApp(
              home: Scaffold(
                body: PCQuiz(controller: flow, bank: bank, active: true),
                bottomNavigationBar: const SizedBox(height: 81),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(PCShouIcon), findsNothing);
      await tester.pump(const Duration(milliseconds: 1979));
      expect(find.byType(PCShouIcon), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(PCShouIcon), findsOneWidget);
      final b = tester.getRect(find.byKey(const ValueKey('pcQuizAnswerB')));
      final hand = tester.getRect(find.byType(PCShouIcon));
      expect(hand.center.dy, greaterThan(b.top));
      final oldAnswer = tester
          .widget<PCQuizContentPanel>(find.byType(PCQuizContentPanel))
          .onAnswer!;
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerB')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pcQuizWrong')), findsOneWidget);
      expect(flow.correctCount, 0);
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byKey(const ValueKey('pcQuizWrong')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('pcQuizAnswerB')),
        warnIfMissed: false,
      );
      expect(flow.correctCount, 0);
      expect(flow.pendingReward, isNull);
      expect(find.byType(PCAwardDialog), findsNothing, reason: '答错不能触发奖励');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.byKey(const ValueKey('pcQuizWrong')), findsNothing);
      expect(flow.questionIndex, 1);
      oldAnswer(false);
      await tester.pump();
      expect(flow.correctCount, 0);
      expect(flow.pendingReward, isNull);
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerB')));
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerB')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pcQuizCorrect')), findsOneWidget);
      expect(find.byKey(const ValueKey('pcQuizResumeReward')), findsNothing);
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byType(PCAwardDialog), findsNothing, reason: '答对显示状态满1秒才弹奖');
      await tester.tap(
        find.byKey(const ValueKey('pcQuizAnswerA')),
        warnIfMissed: false,
      );
      expect(flow.correctCount, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PCAwardDialog), findsOneWidget);
      expect(flow.balance, 0);
      expect(
        find.byWidgetPredicate((w) => w is PCImg && w.name == 'pc_ad_icon'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(flow.pendingReward, isNull);
      expect(flow.balance, 0);
      expect(find.byKey(const ValueKey('pcQuizResumeHint')), findsNothing);
      expect(find.byKey(const ValueKey('pcQuizResumeReward')), findsNothing);
      expect(flow.questionIndex, 2);
      expect(flow.correctCount, 1);
      expect(find.text('Which fruit is red?'), findsOneWidget);
      oldAnswer(false);
      await tester.pump();
      expect(flow.pendingReward, isNull, reason: '旧题回调不能恢复已放弃奖励');
      expect(flow.correctCount, 1);
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PCAwardDialog), findsOneWidget);
      expect(flow.correctCount, 2);
      await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(flow.balance, greaterThan(0));
      expect(flow.pendingReward, isNull);
      expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1900));
      await tester.pump();
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(
        find.byKey(const ValueKey('pcQuizProcessBanner')),
        findsNothing,
        reason: '3.7横幅只按配置答题次数触发，不再每次领奖或无操作显示',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
    });
  }
  quizWidgets('答题Claim激励失败放弃原奖励，关闭失败后下一题可成功领取一次', (tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_bg_music': false,
    });
    final provider = PCLocalProvider.instance;
    await provider.init();
    final flow = PCQuizController(random: Random(2), onSync: provider.init);
    await flow.load();
    addTearDown(flow.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    });
    var adResult = Completer<bool>();
    final placements = <String>[];
    PCRewardedAdService.instance.handler = (placement) {
      placements.add(placement);
      return adResult.future;
    };
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: PCQuiz(
              controller: flow,
              active: true,
              bank: PCQuizBank.fromQuestions(const [
                PCQuizQuestion(
                  question: 'Choose the correct answer',
                  a: 'Correct',
                  b: 'Wrong',
                  answer: 'a',
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PCAwardDialog), findsOneWidget);
    final pending = flow.pendingReward!;
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await tester.pump();
    expect(placements, ['nkmdl_quizgetc_rv'], reason: '同一广告播放中不能重复请求');
    expect(flow.balance, 0);
    expect(flow.pendingReward?.toJson(), pending.toJson());
    adResult.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(flow.balance, 0);
    expect(flow.pendingReward, isNull);
    final restored = await controller();
    expect(restored.balance, 0);
    expect(restored.pendingReward, isNull);
    restored.dispose();
    await tester.tap(find.text('Try Again').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(placements, ['nkmdl_quizgetc_rv'], reason: '失败弹窗Try Again只关闭，不自动重播');
    expect(flow.pendingReward, isNull);
    expect(find.byKey(const ValueKey('pcQuizResumeReward')), findsNothing);
    expect(find.byType(PCAwardDialog), findsNothing);
    expect(flow.questionIndex, 1);
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final next = flow.pendingReward!;
    expect(next.id, isNot(pending.id));
    expect(
      tester.widget<PCAwardDialog>(find.byType(PCAwardDialog)).reward?.id,
      next.id,
    );
    adResult = Completer<bool>();
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await tester.pump();
    expect(flow.balance, 0);
    adResult.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(placements, ['nkmdl_quizgetc_rv', 'nkmdl_quizgetc_rv']);
    expect(flow.balance, next.amount);
    expect(flow.pendingReward, isNull);
    expect(await flow.claim(), isNull);
    expect(flow.balance, next.amount);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(PCDialogCoordinator.instance.isBusy, false);
    expect(tester.takeException(), isNull);
  });
  quizWidgets('直接进入普通答题可在2秒手势出现前立即答题', (tester) async {
    SharedPreferences.setMockInitialValues({'pc_new_guide_end': true});
    final provider = PCLocalProvider.instance;
    await provider.init();
    final flow = await controller();
    final bank = PCQuizBank.fromQuestions([
      const PCQuizQuestion(
        question: 'Correct is B?',
        a: 'Wrong',
        b: 'Correct',
        answer: 'b',
      ),
    ]);
    PigsTabController.switchTo(1);
    addTearDown(() => PigsTabController.switchTo(0));
    expect(PCNewUserGuideController.instance.isLoaded, false);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: PCQuiz(controller: flow, bank: bank),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(PCNewUserGuideController.instance.isComplete, true);
    expect(find.byType(PCShouIcon), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerB')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byType(PCAwardDialog), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is PCImg && w.name == 'pc_quiz_cash_reward',
      ),
      findsOneWidget,
    );
    expect(flow.correctCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    flow.dispose();
  });

  quizWidgets('答题达标横幅完全退出再显示排队弹窗，弹窗结束不再定时重弹', (tester) async {
    await bannerAfterEachAnswer();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = PCLocalProvider.instance;
    await provider.init();
    final flow = await controller();
    final bank = PCQuizBank.fromQuestions(const [
      PCQuizQuestion(
        question: 'Correct is B?',
        a: 'Wrong',
        b: 'Correct',
        answer: 'b',
      ),
    ]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) => MaterialApp(
            home: PCQuiz(controller: flow, bank: bank, active: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await answerForBanner(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 351));
    final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
    expect(banner, findsOneWidget);
    expect(tester.getTopLeft(banner).dx, closeTo(0, .01));
    expect(tester.getSize(banner).width, 375);
    expect(tester.getSize(banner).height, closeTo(375 * 332 / 360, .01));
    expect(find.byType(PCShouIcon), findsNothing, reason: '红色大横幅期间隐藏正确答案手势');
    final panel = tester.widget<PCQuizContentPanel>(
      find.byType(PCQuizContentPanel),
    );
    expect(panel.enabled, false);
    final before = flow.questionIndex;
    await tester.tap(
      find.byKey(const ValueKey('pcQuizAnswerB')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(flow.questionIndex, before, reason: '横幅遮罩期间不能答题');
    expect(flow.pendingReward, isNull);
    final quizContext = tester.element(find.byType(PCQuiz));
    final dialog = quizContext.tipShow2(
      const AlertDialog(content: Text('Queued process prompt')),
    );
    unawaited(dialog);
    await tester.pump();
    expect(PCDialogCoordinator.instance.pendingCount, 1);
    expect(find.text('Queued process prompt'), findsNothing);
    await tester.pump(const Duration(milliseconds: 175));
    expect(banner, findsOneWidget);
    expect(tester.getTopLeft(banner).dx, greaterThan(0));
    expect(find.text('Queued process prompt'), findsNothing);
    await tester.pump(const Duration(milliseconds: 176));
    await tester.pump();
    await tester.pump();
    expect(banner, findsNothing, reason: '横幅退场完成后内容已移除');
    expect(find.text('Queued process prompt'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 351));
    Navigator.of(quizContext).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await dialog;
    await tester.pump(const Duration(seconds: 30));
    expect(banner, findsNothing, reason: '弹窗关闭后无操作不能重新展示');
    await answerForBanner(tester);
    await tester.pump();
    expect(banner, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    flow.dispose();
    expect(PCDialogCoordinator.instance.isBusy, false);
  });

  quizWidgets('流程弹窗待处理时清旧奖，流程完成后可答新题且关闭奖励不恢复', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('pc_quiz_num_index', 3);
    final provider = PCLocalProvider.instance;
    await provider.init();
    final flow = await controller();
    final previous = (await flow.answer(
      correct: true,
      expectedQuestionIndex: 3,
    ))!;
    final process = PCProcessFlowController.instance;
    await process.refresh();
    expect(process.hasPending, true);
    final bank = PCQuizBank.fromQuestions(const [
      PCQuizQuestion(
        question: 'Correct is B?',
        a: 'Wrong',
        b: 'Correct',
        answer: 'b',
      ),
    ]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) => MaterialApp(
            home: PCQuiz(controller: flow, bank: bank, active: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PCAwardDialog), findsNothing, reason: '初始化清理旧待奖');
    expect(flow.pendingReward, isNull);
    expect(find.byKey(const ValueKey('pcQuizResumeReward')), findsNothing);
    expect(flow.questionIndex, 4);
    expect(flow.correctCount, 1);
    expect(process.hasPending, true);
    while (process.next != null) {
      await process.begin(process.next!);
      process.finish();
    }
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerB')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byType(PCAwardDialog),
      findsOneWidget,
      reason: '流程完成后正常答题，不被已清理的旧奖励互锁',
    );
    expect(flow.pendingReward?.id, isNot(previous.id));
    await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(flow.pendingReward, isNull);
    expect(find.byKey(const ValueKey('pcQuizResumeReward')), findsNothing);
    expect(flow.correctCount, 2);
    expect(flow.questionIndex, 5);
    expect(flow.balance, 0);
    expect(PCDialogCoordinator.instance.isBusy, false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    flow.dispose();
    while (process.next != null) {
      await process.begin(process.next!);
      process.finish();
    }
    expect(tester.takeException(), isNull);
    expect(PCDialogCoordinator.instance.isBusy, false);
  });

  quizWidgets('根Overlay横幅遮住底栏并拦截切页，退场和销毁均清理遮罩及展示权', (tester) async {
    await bannerAfterEachAnswer();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = PCLocalProvider.instance;
    await provider.init();
    final flow = await controller();
    final bank = PCQuizBank.fromQuestions(const [
      PCQuizQuestion(
        question: 'Correct is B?',
        a: 'Wrong',
        b: 'Correct',
        answer: 'b',
      ),
    ]);
    var selectedTab = 1;
    var footerTaps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) => MaterialApp(
            home: Scaffold(
              body: PCQuiz(controller: flow, bank: bank, active: true),
              bottomNavigationBar: GestureDetector(
                key: const ValueKey('pcQuizTestBottomNavigation'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  footerTaps++;
                  selectedTab = 2;
                },
                child: const SizedBox(
                  height: 81,
                  child: Center(child: Text('Wheel tab')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await answerForBanner(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 351));
    final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
    final barrier = find.byKey(const ValueKey('pcQuizProcessBarrier'));
    final footer = find.byKey(const ValueKey('pcQuizTestBottomNavigation'));
    expect(tester.getRect(barrier), const Rect.fromLTWH(0, 0, 375, 812));
    expect(tester.getCenter(banner), const Offset(187.5, 406));
    expect(tester.getRect(barrier).contains(tester.getCenter(footer)), true);
    await tester.tapAt(tester.getCenter(footer));
    await tester.pump();
    expect(footerTaps, 0);
    expect(selectedTab, 1, reason: '全屏横幅期间底部导航也不能切页');
    expect(find.byType(PCShouIcon), findsNothing);
    await tester.pump(const Duration(milliseconds: 2001));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pump();
    expect(banner, findsNothing);
    expect(barrier, findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, false);
    expect(find.byType(PCShouIcon), findsNothing, reason: '横幅完整退场后重新等待2秒手势');
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(PCShouIcon), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(PCShouIcon), findsOneWidget);
    await tester.tapAt(tester.getCenter(footer));
    expect(footerTaps, 1);
    expect(selectedTab, 2);
    await tester.pump(const Duration(seconds: 30));
    expect(banner, findsNothing, reason: '横幅结束后不能定时重弹');
    await answerForBanner(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 351));
    expect(banner, findsOneWidget);
    expect(PCDialogCoordinator.instance.isBusy, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(banner, findsNothing);
    expect(barrier, findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, false);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
    flow.dispose();
  });

  for (final alreadyShowing in [false, true]) {
    quizWidgets('打开其他页面取消横幅（已展示：$alreadyShowing），返回后不补弹旧提示', (tester) async {
      await bannerAfterEachAnswer();
      final provider = PCLocalProvider.instance;
      await provider.init();
      final flow = await controller();
      final bank = PCQuizBank.fromQuestions(const [
        PCQuizQuestion(
          question: 'Correct is B?',
          a: 'Wrong',
          b: 'Correct',
          answer: 'b',
        ),
      ]);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, child) => MaterialApp(
              home: PCQuiz(controller: flow, bank: bank, active: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
      if (alreadyShowing) {
        await answerForBanner(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 351));
        expect(banner, findsOneWidget);
        expect(PCDialogCoordinator.instance.isBusy, true);
      }
      final context = tester.element(find.byType(PCQuiz));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Other full page')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Other full page'), findsOneWidget);
      expect(banner, findsNothing);
      expect(PCDialogCoordinator.instance.isBusy, false);
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(banner, findsNothing);
      await answerForBanner(tester);
      await tester.pump();
      expect(banner, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      flow.dispose();
      expect(PCDialogCoordinator.instance.isBusy, false);
      expect(tester.takeException(), isNull);
    });
  }

  for (final interruption in ['tab', 'background', 'route']) {
    quizWidgets('达标后反馈期间$interruption离开，回来不会补弹，新的真实答题才可触发', (tester) async {
      await bannerAfterEachAnswer();
      final provider = PCLocalProvider.instance;
      await provider.init();
      final flow = await controller();
      final bank = PCQuizBank.fromQuestions(const [
        PCQuizQuestion(question: 'Correct?', a: 'No', b: 'Yes', answer: 'b'),
      ]);
      final active = ValueNotifier(true);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => MaterialApp(
              home: ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, selected, _) =>
                    PCQuiz(controller: flow, bank: bank, active: selected),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(flow.questionIndex, 1);
      final context = tester.element(find.byType(PCQuiz));
      if (interruption == 'tab') {
        active.value = false;
      } else if (interruption == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Other page')),
            ),
          ),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      if (interruption == 'tab') {
        active.value = true;
      } else if (interruption == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else {
        Navigator.of(context).pop();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
      expect(banner, findsNothing, reason: '返回不能补弹已取消的旧横幅');
      expect(PCDialogCoordinator.instance.isBusy, false);
      await answerForBanner(tester);
      await tester.pump();
      expect(banner, findsOneWidget, reason: '新提交的一题按配置重新触发');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      active.dispose();
      flow.dispose();
      expect(PCDialogCoordinator.instance.isBusy, false);
      expect(tester.takeException(), isNull);
    });
  }

  for (final cancellation in ['tab', 'background', 'queuedDialog']) {
    quizWidgets('横幅插入后首次绘制前被$cancellation取消，不遗留展示锁', (tester) async {
      SharedPreferences.setMockInitialValues({'pc_new_guide_end': true});
      await bannerAfterEachAnswer();
      final provider = PCLocalProvider.instance;
      await provider.init();
      final flow = await controller();
      final bank = PCQuizBank.fromQuestions(const [
        PCQuizQuestion(question: 'Correct?', a: 'No', b: 'Yes', answer: 'b'),
      ]);
      PigsTabController.switchTo(1);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, child) => MaterialApp(
              home: PCQuiz(controller: flow, bank: bank),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // 此帧末尾已insert Overlay，但横幅要到下一帧才首次build。
      await answerForBanner(tester);
      expect(PCDialogCoordinator.instance.holdCount, 1);
      expect(find.byKey(const ValueKey('pcQuizProcessBanner')), findsNothing);
      final context = tester.element(find.byType(PCQuiz));
      Future<dynamic>? queued;
      if (cancellation == 'tab') {
        PigsTabController.switchTo(0);
      } else if (cancellation == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        queued = context.tipShow2(
          const AlertDialog(content: Text('Next dialog')),
        );
      }
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(PCDialogCoordinator.instance.holdCount, 0);
      expect(find.byKey(const ValueKey('pcQuizProcessBarrier')), findsNothing);
      if (queued != null) {
        expect(find.text('Next dialog'), findsOneWidget);
        Navigator.of(context).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await queued;
      }
      expect(PCDialogCoordinator.instance.isBusy, false);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      if (cancellation == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      PigsTabController.switchTo(0);
      flow.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
