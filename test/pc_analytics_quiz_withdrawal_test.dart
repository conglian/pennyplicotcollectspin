import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCConfirmAccountDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalDialogs.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalFlowHost.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final events = <(String, Map<String, dynamic>)>[];
  List<Map<String, dynamic>> reported(String name) => events
      .where((event) => event.$1 == name)
      .map((event) => event.$2)
      .toList();

  setUp(() {
    events.clear();
    PCAnalytics.reporter = (name, parameters) => events.add((name, parameters));
  });
  tearDown(() {
    PCAnalytics.resetForTesting();
    PCRewardedAdService.instance.handler = null;
  });

  Future<void> frames(WidgetTester tester, [int milliseconds = 600]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('Analytics UI frame failed: $error');
    }
  }

  Future<void> seed({
    int level = 0,
    int rank = 9,
    String task = 'quiz',
    bool account = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_pig_upgrade_seen_level_v1': level,
      'pc_bg_music': false,
      'pc_pig_level': level,
      'pc_dollar_number': level == 0 ? 10.0 : 100.0,
      'pc_quiz_diamonds': level == 0 ? 0.0 : (level == 1 ? 3.5 : 20.0),
      'pc_quiz_gold': level == 2 ? 10.0 : 0.0,
      if (account) 'pc_account_id': 'a***@mail.com',
      PCNumberHelpers.configKey: jsonEncode({
        'quiz_console': 10000,
        'queue_number': [
          {
            'int_all': 20,
            'int_current': rank,
            'int_all_delete': [2, 2],
            'int_current_delete': [5, 5],
          },
        ],
        'tixian_task': [
          {'title': task, 'data': 2},
        ],
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 0},
        ],
      }),
    });
    await PCNumberHelpers().pc_initNumberModel();
    await PCLocalProvider.instance.init();
    await PCNewUserGuideController.instance.load();
  }

  Future<BuildContext> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return Scaffold(body: child);
              },
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    return context;
  }

  final bank = PCQuizBank.fromQuestions(const [
    PCQuizQuestion(question: 'First', a: 'Correct', b: 'Wrong', answer: 'a'),
    PCQuizQuestion(question: 'Second', a: 'Correct', b: 'Wrong', answer: 'a'),
    PCQuizQuestion(question: 'Third', a: 'Correct', b: 'Wrong', answer: 'a'),
  ]);

  testWidgets('Quiz只统计首次有效答题点击，奖励带quiz来源及正式广告位', (tester) async {
    await seed();
    final flow = PCQuizController(random: Random(2));
    addTearDown(flow.dispose);
    PigsTabController.currentIndex.value = 1;
    await mount(tester, PCQuiz(controller: flow, bank: bank, active: true));
    expect(
      reported('quiz_page'),
      hasLength(1),
      reason: 'quiz_page events=$events loaded=${flow.isLoaded}',
    );
    final wrong = find.byKey(const ValueKey('pcQuizAnswerB'));
    await tester.tap(wrong);
    await tester.tap(wrong, warnIfMissed: false);
    await frames(tester, 1200);
    expect(
      reported('answer_wrong_c'),
      hasLength(1),
      reason: 'wrong events=$events index=${flow.questionIndex}',
    );
    final correct = find.byKey(const ValueKey('pcQuizAnswerA'));
    await tester.tap(correct);
    await tester.tap(correct, warnIfMissed: false);
    await frames(tester, 1500);
    expect(
      reported('answer_true_c'),
      hasLength(1),
      reason: 'true events=$events index=${flow.questionIndex}',
    );
    expect(reported('double_pop'), [
      {'pop_from': 'quiz'},
    ]);
    final placements = <String>[];
    final ad = Completer<bool>();
    PCRewardedAdService.instance.handler = (placement) {
      placements.add(placement);
      return ad.future;
    };
    final claim = find.byKey(const ValueKey('pcQuizClaimReward'));
    await tester.tap(claim);
    await tester.tap(claim, warnIfMissed: false);
    await frames(tester, 100);
    expect(reported('double_pop_c'), [
      {'pop_from': 'quiz'},
    ]);
    expect(placements, ['nkmdl_quizgetc_rv']);
    ad.complete(false);
    await frames(tester);
    expect(reported('double_pop'), hasLength(1));
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(reported('double_pop_close'), isEmpty, reason: '广告失败面板关闭不伪造奖励框关闭');
  });

  testWidgets('Quiz页面只在真正切入时曝光，重建和广告前后台回切不重复', (tester) async {
    await seed();
    final flow = PCQuizController(random: Random(2));
    final active = ValueNotifier(false);
    addTearDown(flow.dispose);
    addTearDown(active.dispose);
    await mount(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (_, value, _) =>
            PCQuiz(controller: flow, bank: bank, active: value),
      ),
    );
    expect(reported('quiz_page'), isEmpty);
    active.value = true;
    await frames(tester);
    expect(reported('quiz_page'), hasLength(1));
    await PCLocalProvider.instance.init();
    await frames(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await frames(tester, 100);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    expect(reported('quiz_page'), hasLength(1));
    active.value = false;
    await frames(tester);
    active.value = true;
    await frames(tester);
    expect(reported('quiz_page'), hasLength(2));
  });

  testWidgets('普通wheel奖励曝光和关闭单次，新手及首页不混入double事件', (tester) async {
    await seed();
    final context = await mount(tester, const SizedBox());
    final wheel = context.tipShow2(
      const PCAwardDialog(
        award: 1,
        adsEnabled: false,
        analyticsSource: 'wheel',
      ),
    );
    await frames(tester);
    expect(reported('double_pop'), [
      {'pop_from': 'wheel'},
    ]);
    await tester.tap(find.byKey(const ValueKey('pcQuizCloseReward')));
    await frames(tester);
    expect(await wheel, false);
    expect(reported('double_pop_close'), hasLength(1));
    final ordinaryCount = events.length;
    final guide = context.tipShow2(
      const PCAwardDialog(award: 1, adsEnabled: false),
    );
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester);
    expect(await guide, true);
    expect(events.length, ordinaryCount);
  });

  Future<PCWithdrawalController> withdrawal({
    Future<bool> Function(String)? ad,
  }) async {
    final flow = PCWithdrawalController(
      scheduleMidnightTimer: false,
      requestAd: ad ?? (_) async => true,
    );
    addTearDown(flow.dispose);
    await flow.load();
    return flow;
  }

  Widget host(PCWithdrawalController flow) => PCWithdrawalFlowHost(
    controller: flow,
    canPresent: () => true,
    notificationsEnabled: () async => false,
    requestNotifications: () async => false,
    onGoQuiz: () {},
    onGoWheel: () {},
    child: const SizedBox.expand(),
  );

  testWidgets('钻石升级同一弹窗分别上报已确认的两组曝光与点击，连点不重复', (tester) async {
    await seed(level: 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_pig_upgrade_seen_level_v1', 0);
    final flow = await withdrawal();
    await mount(tester, host(flow));
    expect(
      reported('diamond_pig_getpop'),
      hasLength(1),
      reason: '$events next=${flow.next?.kind}',
    );
    expect(reported('collect_diamond_pop'), hasLength(1));
    await flow.refresh();
    await frames(tester);
    expect(reported('diamond_pig_getpop'), hasLength(1));
    expect(reported('collect_diamond_pop'), hasLength(1));
    final confirm = find.text('Confirm Withdrawal').last;
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await frames(tester);
    expect(reported('diamond_pig_getpop_c'), hasLength(1));
    expect(reported('collect_diamond_pop_c'), hasLength(1));
  });

  testWidgets('排队实际呈现只曝光一次，重复点击仅一个排队事件及正确广告位', (tester) async {
    await seed(level: 2);
    final ad = Completer<bool>();
    final placements = <String>[];
    final flow = await withdrawal(
      ad: (placement) {
        placements.add(placement);
        return ad.future;
      },
    );
    await mount(tester, host(flow));
    expect(reported('cash_queue_pop'), hasLength(1));
    await flow.refresh();
    await frames(tester);
    expect(reported('cash_queue_pop'), hasLength(1));
    final action = find.byKey(const ValueKey('pcWithdrawalSkipWait'));
    await tester.tap(action);
    await tester.tap(action, warnIfMissed: false);
    await frames(tester, 100);
    expect(reported('cash_queue_po_c'), hasLength(1));
    expect(placements, ['nkmdl_queue_rv']);
    ad.complete(true);
    await frames(tester);
    expect(find.byType(PCWithdrawalApprovalDialog), findsOneWidget);
    expect(reported('cash_queue_pop'), hasLength(1));
  });

  for (final title in ['quiz', 'spin', 'video']) {
    testWidgets('最后一步$title曝光和点击使用约定type，video映射ad', (tester) async {
      await seed(level: 2, rank: 1, task: title);
      final flow = await withdrawal();
      await mount(tester, host(flow));
      final parameters = {'type': title == 'video' ? 'ad' : title};
      expect(reported('one_last_step_pop'), [parameters]);
      await tester.tap(find.byKey(const ValueKey('pcWithdrawalTaskAction')));
      await frames(tester);
      expect(reported('one_last_step_pop_c'), [parameters]);
    });
  }

  testWidgets('余额不足按真实弹窗曝光与按钮点击分别上报', (tester) async {
    await seed();
    final flow = await withdrawal();
    await flow.requestCurrentPrompt(amount: 100);
    await mount(tester, host(flow));
    expect(
      reported('cash_not_pop'),
      hasLength(1),
      reason: 'insufficient events=$events prompt=${flow.next?.kind}',
    );
    await tester.tap(find.text('Keep Earning'));
    await frames(tester);
    expect(
      reported('cash_not_pop_c'),
      hasLength(1),
      reason: 'insufficient click events=$events',
    );
  });

  for (final saved in [false, true]) {
    testWidgets('确认账号点击type依据真实本地账号：$saved', (tester) async {
      await seed(account: saved);
      final context = await mount(tester, const SizedBox());
      final result = context.tipShow2(
        const PCConfirmAccountDialog(withdrawalTarget: 100),
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('pcConfirmAccountAction')));
      await frames(tester);
      expect(await result, true);
      expect(reported('process_confirm_account_pop_c'), [
        {'type': saved ? 'yes' : 'no'},
      ]);
    });
  }
}
