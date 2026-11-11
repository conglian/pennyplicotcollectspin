import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCCash.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigWheelPage.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'support/pc_number_test_assets.dart';
import 'dart:convert';
import 'dart:math';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCModel/PCNumbserModel.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';

class FixedRandom implements Random {
  FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor();
  @override
  bool nextBool() => value < .5;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final numbers = PCNumberHelpers();
  setUp(() async {
    PCRewardedAdService.instance.handler = (_) async => true;
    SharedPreferences.setMockInitialValues({});
    await numbers.pc_initNumberModel();
  });
  tearDown(() => PCRewardedAdService.instance.handler = null);
  test('本地 gp177 JSON 经生成模型往返，所有参数保持完整', () {
    final original = numbers.model;
    final roundTrip = PCAPCConfig.pc_fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );
    expect(roundTrip.toJson(), original.toJson());
    expect(roundTrip.eqRange, [100, 120, 150, 200]);
    expect(roundTrip.newAdConsole, 1);
    expect(roundTrip.quizConsole, 5);
    expect(numbers.pc_quizConsole, 5);
    expect(roundTrip.firstAdPrize, 6);
    expect(roundTrip.wheelRange, [5, 10]);
    expect(roundTrip.queueNumber.single.intAll, 388);
    expect(roundTrip.tixianTask.length, 9);
    expect(roundTrip.moneyPrize.length, 4);
    expect(numbers.pc_prizeForLevel(0, 92, random: FixedRandom(0)), 1);
    expect(numbers.pc_prizeForLevel(0, 92, random: FixedRandom(.999)), 2);
  });
  test('奖励按JSON取档，现金截断尾值，钻石和金砖末档继续累计两位小数', () {
    for (final level in [0, 1, 2]) {
      final rows = [
        numbers.model.moneyPrize,
        numbers.model.diamondPrize,
        numbers.model.goldPrize,
      ][level];
      for (final row in rows) {
        expect(
          numbers.pc_prizeForLevel(
            level,
            row.firstNumber.toDouble(),
            random: FixedRandom(0),
          ),
          row.prize.first,
        );
        expect(
          numbers.pc_prizeForLevel(
            level,
            row.endNumber - .01,
            random: FixedRandom(.9),
          ),
          (level == 1 && row.endNumber == 20) ||
                  (level == 2 && row.endNumber == 10)
              ? row.prize.last
              : .01,
        );
      }
    }
    expect(numbers.pc_prizeForLevel(1, 20), inInclusiveRange(.01, .05));
    expect(numbers.pc_prizeForLevel(2, 10), inInclusiveRange(.01, .02));
  });
  test('插屏概率按当前余额匹配，0%从不触发，边界归下一档', () {
    expect(
      numbers.pc_checkProbability(balance: 29.99, random: FixedRandom(0)),
      false,
    );
    expect(
      numbers.pc_checkProbability(balance: 30, random: FixedRandom(.29)),
      true,
    );
    expect(
      numbers.pc_checkProbability(balance: 30, random: FixedRandom(.30)),
      false,
    );
    expect(
      numbers.pc_checkProbability(balance: 60, random: FixedRandom(.49)),
      true,
    );
    expect(
      numbers.pc_checkProbability(balance: 90, random: FixedRandom(.79)),
      true,
    );
    expect(
      numbers.pc_checkProbability(balance: 10000, random: FixedRandom(0)),
      false,
    );
  });
  test('同名覆盖配置供提现、排队、转盘和新用户使用，异常字段退回本地', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNumberHelpers.configKey,
      jsonEncode({
        'eq_range': [80, 160],
        'wheel_range': [7, 13],
        'first_ad_prize': 9,
        'new_ad_console': 0,
        'quiz_console': 7,
        'queue_number': [
          {
            'int_all': 500,
            'int_current': 77,
            'int_all_delete': [2, 4],
            'int_current_delete': [3, 6],
          },
        ],
      }),
    );
    await PCLocalProvider.instance.init();
    expect(numbers.pc_eqRange, [80, 160]);
    expect(numbers.pc_wheelRange, [7, 13]);
    expect(numbers.pc_quizConsole, 7);
    expect(numbers.model.firstAdPrize, 9);
    expect(PCLocalProvider.instance.pc_current_ranking, 77);
    expect(PCLocalProvider.instance.pc_all_ranking, 500);
    expect(numbers.pc_tixianTasks.length, 9);
    final invalid = numbers.pc_parseConfig(
      '{"eq_range":[],"money_prize":[{}],"new_ad_console":2,"quiz_console":0}',
    );
    expect(invalid.eqRange, [100, 120, 150, 200]);
    expect(invalid.moneyPrize.length, 4);
    expect(invalid.newAdConsole, 1);
    expect(invalid.quizConsole, 5);
    expect(numbers.pc_parseConfig('{"quiz_console":"bad"}').quizConsole, 5);
    expect(PCAPCConfig.fromJson({}).quizConsole, 5);
  });
  test('首档门槛取JSON，钻石20后继续累计直到午夜才升级，金砖10后继续结算', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PCNumberHelpers.configKey, '{"eq_range":[80,160]}');
    await prefs.setDouble('pc_dollar_number', 79.99);
    var quiz = PCQuizController(random: FixedRandom(.999));
    await quiz.load();
    expect(quiz.stage, PCQuizRewardType.cash);
    final cash = (await quiz.answer(correct: true))!;
    expect(cash.amount, .01);
    await quiz.claim();
    expect(quiz.balance, 80);
    expect(prefs.getInt('pc_pig_level'), 1);
    quiz.dispose();
    await prefs.setDouble('pc_pig_level_index', 19.99);
    quiz = PCQuizController(random: FixedRandom(.999));
    await quiz.load();
    expect(quiz.stage, PCQuizRewardType.diamond);
    final diamond = (await quiz.answer(correct: true))!;
    expect(diamond.type, PCQuizRewardType.diamond);
    expect(diamond.amount, .05);
    await quiz.claim();
    expect(prefs.getInt('pc_pig_level'), 1);
    expect(prefs.getDouble('pc_pig_level_index'), 20.04);
    expect(quiz.diamonds, 20.04);
    expect((await quiz.answer(correct: true))!.type, PCQuizRewardType.diamond);
    await quiz.claim();
    expect(quiz.diamonds, 20.09);
    expect(quiz.balance, 80);
    await PCPigProgress.sync(prefs, now: PCPigProgress.diamondDeadline(prefs)!);
    expect(prefs.getInt('pc_pig_level'), 2);
    expect(prefs.getDouble('pc_quiz_diamonds'), 20.09);
    expect(prefs.getDouble('pc_pig_level_index'), 0);
    quiz.dispose();
    await prefs.setDouble('pc_pig_level_index', 9.99);
    quiz = PCQuizController();
    await quiz.load();
    final gold = (await quiz.answer(correct: true))!;
    expect(gold.type, PCQuizRewardType.gold);
    expect(gold.amount, inInclusiveRange(.01, .02));
    await quiz.claim();
    expect(quiz.isComplete, false);
    expect(prefs.getInt('pc_pig_level'), 2);
    expect(prefs.getDouble('pc_pig_level_index'), 9.99 + gold.amount);
    final extraGold = (await quiz.answer(correct: true))!;
    expect(extraGold.type, PCQuizRewardType.gold);
    expect(extraGold.amount, inInclusiveRange(.01, .02));
    await quiz.claim();
    expect(quiz.gold, greaterThan(10));
    expect(quiz.balance, 80);
    quiz.dispose();
  });
  test('冷启动兼容旧阶段和小数进度，余额降低也不会把金猪重置成粉猪', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pc_pig_level', 2);
    await prefs.setDouble('pc_pig_level_index', .12);
    await prefs.setDouble('pc_dollar_number', 1);
    final quiz = PCQuizController();
    await quiz.load();
    expect(quiz.stage, PCQuizRewardType.gold);
    expect(quiz.diamonds, 20);
    expect(quiz.gold, .12);
    await PCLocalProvider.instance.init();
    expect(PCLocalProvider.instance.pc_pig_level, 2);
    expect(PCLocalProvider.instance.pc_pig_level_index, .12);
    quiz.dispose();
  });
  for (final enabled in [0, 1]) {
    test('new_ad_console=$enabled 不再控制签到，激励成功领取远程首笔金额且仅一次', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PCNumberHelpers.configKey,
        '{"new_ad_console":$enabled,"first_ad_prize":7.5}',
      );
      await prefs.setString(
        PCNewUserGuideController.flowKey,
        '{"stage":"checkIn"}',
      );
      var requests = 0;
      final guide = PCNewUserGuideController(
        requestRewardedAd: (placement) async {
          expect(placement, 'nkmdl_signin_rv');
          requests++;
          return true;
        },
      );
      await guide.load();
      expect(await guide.claimCheckIn(), true);
      expect(guide.balance, 7.5);
      expect(guide.stage, PCNewUserStage.deposit);
      expect(guide.checkInDay, 1);
      expect(guide.config.showFirstAd, true);
      expect(await guide.claimCheckIn(), false);
      expect(guide.balance, 7.5);
      expect(requests, 1);
      guide.dispose();
    });
  }
  test('引导答题仍直接领取钻石，普通签到仅激励成功后给现金', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PCNewUserGuideController.flowKey, '{"stage":"quiz"}');
    await prefs.setInt('pc_pig_level', 1);
    await prefs.setDouble('pc_pig_level_index', 19.99);
    await prefs.setDouble('pc_dollar_number', 100);
    final guide = PCNewUserGuideController();
    await guide.load();
    await guide.answerQuiz(correct: true);
    expect(guide.quizReward.type, PCQuizRewardType.diamond);
    final diamondPrize = guide.quizReward.amount;
    expect(await guide.claimQuizReward(), true);
    expect(guide.balance, 100);
    expect(guide.diamonds, ((19.99 + diamondPrize) * 100).round() / 100);
    expect(guide.rewardType, PCQuizRewardType.diamond);
    guide.dispose();
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      '{"stage":"complete"}',
    );
    final daily = PCNewUserGuideController();
    await daily.load();
    expect(await daily.claimCheckIn(), true);
    expect(daily.balance, 106);
    daily.dispose();
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('配置档位和转盘数值在 $size 可展示和滚动', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PCNumberHelpers.configKey,
        '{"eq_range":[80,160,240,320,400],"wheel_range":[7,13]}',
      );
      await prefs.setDouble('pc_dollar_number', 40.25);
      final provider = PCLocalProvider.instance;
      await provider.init();
      Widget host(Widget child) => ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(home: child),
        ),
      );
      final withdrawal = PCWithdrawalController(scheduleMidnightTimer: false);
      await withdrawal.load();
      await tester.pumpWidget(host(PCCash(controller: withdrawal)));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Only \$39.75 left to withdraw \$80', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('\$400'), findsOneWidget);
      await tester.ensureVisible(find.text('\$400'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(find.text('\$400')).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(
          const Scaffold(body: PCPigWheelPage(imagePath: 'pc_wheel_center')),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is PCStrokeText && w.text == '\$7-13'),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      withdrawal.dispose();
    });
  }
}
