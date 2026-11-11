import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCCash/PCDiamondPigUpgradeDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCCash/PCGoldPigUpgradeDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCCash/PCPigUpgradeWidgets.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigUpgradeController.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigProgress.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigUpgradeHost.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'support/pc_number_test_assets.dart';

void usePortraitQuizViewport(WidgetTester tester) {
  // 答题页只支持竖屏，避免测试默认的800×600横屏把答案放到滚动区外。
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

  test('美元领取达到100才提示钻石猪，确认后冷启动不重复', () async {
    SharedPreferences.setMockInitialValues({'pc_dollar_number': 99.99});
    final quiz = PCQuizController();
    final upgrades = PCPigUpgradeController();
    await quiz.load();
    await quiz.answer(correct: true);
    await upgrades.refresh();
    expect(upgrades.pendingLevel, isNull);
    await quiz.claim();
    await upgrades.refresh();
    expect(quiz.balance, 100);
    expect(upgrades.pendingLevel, 1);
    await upgrades.acknowledge(1);
    final restored = PCPigUpgradeController();
    await restored.refresh();
    expect(restored.pendingLevel, isNull);
    quiz.dispose();
    upgrades.dispose();
    restored.dispose();
  });

  test('20钻后当天继续钻石，午夜才提示金猪，未确认冷启恢复且旧确认不回退', () async {
    SharedPreferences.setMockInitialValues({
      'pc_dollar_number': 100.0,
      PCPigUpgradeController.seenKey: 1,
      PCQuizController.storageKey: jsonEncode({'diamonds': 19.99}),
    });
    final quiz = PCQuizController();
    final upgrades = PCPigUpgradeController();
    await quiz.load();
    await upgrades.refresh();
    expect(upgrades.pendingLevel, isNull);
    await quiz.answer(correct: true);
    await quiz.claim();
    await upgrades.refresh();
    expect(quiz.diamonds, greaterThanOrEqualTo(20));
    expect(quiz.stage.name, 'diamond');
    expect(upgrades.pendingLevel, isNull);
    await quiz.answer(correct: true);
    await quiz.claim();
    expect(quiz.diamonds, greaterThan(20));
    final exactDiamonds = quiz.diamonds;
    final prefs = await SharedPreferences.getInstance();
    await PCPigProgress.sync(prefs, now: PCPigProgress.diamondDeadline(prefs)!);
    await upgrades.refresh();
    expect(quiz.diamonds, exactDiamonds);
    expect(quiz.balance, 100);
    expect(upgrades.pendingLevel, 2);
    final restored = PCPigUpgradeController();
    await restored.refresh();
    expect(restored.pendingLevel, 2);
    await restored.acknowledge(2);
    await restored.acknowledge(1);
    await upgrades.refresh();
    expect(upgrades.pendingLevel, isNull);
    quiz.dispose();
    upgrades.dispose();
    restored.dispose();
  });

  test('不足20钻石的旧档隔天仍为钻石猪，保留3.5且不提示金猪', () async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'pc_pig_level': 1,
      'pc_quiz_diamonds': 3.5,
      'pc_pig_level_index': 3.5,
      'pc_dollar_number': 100.0,
      'pc_pig_upgrade_date_1': DateTime(
        today.year,
        today.month,
        today.day - 1,
        12,
      ).toIso8601String(),
      PCPigUpgradeController.seenKey: 1,
    });
    final quiz = PCQuizController();
    final upgrades = PCPigUpgradeController();
    await quiz.load();
    await upgrades.refresh();
    expect(quiz.stage.name, 'diamond');
    expect(quiz.diamonds, 3.5);
    expect(quiz.gold, 0);
    expect(upgrades.pendingLevel, isNull);
    await quiz.refreshBalance();
    expect(quiz.diamonds, 3.5);
    quiz.dispose();
    upgrades.dispose();
  });

  test('到账日志中断恢复也恢复升级提示，嵌套暂缓安全释放', () async {
    SharedPreferences.setMockInitialValues({
      'pc_dollar_number': 99.99,
      PCQuizController.journalKey: jsonEncode({
        'balanceAfter': 100.0,
        'flow': {'diamonds': 0.0, 'gold': 0.0},
      }),
    });
    final quiz = PCQuizController();
    await quiz.load();
    final upgrades = PCPigUpgradeController();
    await upgrades.refresh();
    expect(upgrades.pendingLevel, 1);
    final first = upgrades.holdPresentation(),
        second = upgrades.holdPresentation();
    first();
    first();
    expect(upgrades.isBlocked, isTrue);
    second();
    expect(upgrades.isBlocked, isFalse);
    quiz.dispose();
    upgrades.dispose();
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(430, 932),
  ]) {
    for (final safe in [
      EdgeInsets.zero,
      const EdgeInsets.only(top: 24, bottom: 34),
    ]) {
      testWidgets('两张升级弹窗在$size安全区$safe内不重叠，底部按钮完整且可点击', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(
          top: safe.top,
          bottom: safe.bottom,
        );
        tester.view.viewPadding = FakeViewPadding(
          top: safe.top,
          bottom: safe.bottom,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 300));
        });
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return const Scaffold(body: Text('Underlying quiz page'));
              },
            ),
          ),
        );

        Rect safeRect(Finder finder, String description) {
          final rect = tester.getRect(finder);
          expect(rect.width, greaterThan(0), reason: description);
          expect(rect.height, greaterThan(0), reason: description);
          expect(rect.left, greaterThanOrEqualTo(-.01), reason: description);
          expect(
            rect.right,
            lessThanOrEqualTo(size.width + .01),
            reason: description,
          );
          expect(
            rect.top,
            greaterThanOrEqualTo(safe.top - .01),
            reason: description,
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(size.height - safe.bottom + .01),
            reason: description,
          );
          return rect;
        }

        Future<dynamic> present(int level) => context.tipShow2(
          level == 1
              ? const PCDiamondPigUpgradeDialog(
                  amount: 120,
                  account: 'a.long.account@example.com',
                  paymentAsset: 'pc_act_2',
                )
              : PCGoldPigUpgradeDialog(
                  amount: 120,
                  account: 'a.long.account@example.com',
                  paymentAsset: 'pc_act_2',
                  date: DateTime(2026, 10, 22),
                  gold: 2.5,
                ),
          scaleContent: false,
        );

        for (final level in [1, 2]) {
          final closed = present(level);
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('a.long.account@example.com'), findsOneWidget);
          final action = safeRect(find.byType(PCPigUpgradeButton), '底部主按钮');
          final buttonBackground = find.byWidgetPredicate(
            (widget) => widget is PCImg && widget.name == 'pc_btn_bg',
          );
          expect(tester.getSize(buttonBackground), const Size(268, 64));
          expect(tester.getRect(buttonBackground), action);
          if (level == 2) {
            expect(find.text('2.5/10'), findsOneWidget);
            expect(find.text('10/22/2026'), findsOneWidget);
            final header = safeRect(
              find.byKey(const ValueKey('pcGoldUpgradeHeader')),
              '含对勾、文案与丝带的顶部整体图片',
            );
            expect(
              tester
                  .widget<PCImg>(
                    find.byKey(const ValueKey('pcGoldUpgradeHeader')),
                  )
                  .name,
              'pc_gold_upgrade_header',
            );
            final hero = tester.getRect(find.byType(PCPigUpgradeHero));
            expect(header.bottom, lessThanOrEqualTo(hero.top));
            expect(find.byType(PCPigUpgradeRibbon), findsNothing);
            expect(find.text('✅ Advertiser PayOut Sent'), findsNothing);
            final viewport = safeRect(
              find.byKey(const ValueKey('pcGoldUpgradeContent')),
              '上部可滚动内容视口',
            );
            expect(
              tester
                  .widget<SingleChildScrollView>(
                    find.byKey(const ValueKey('pcGoldUpgradeContent')),
                  )
                  .clipBehavior,
              isNot(Clip.none),
              reason: '滚动内容必须裁剪，不能绘制到独立底部按钮区',
            );
            final footer = safeRect(
              find.byKey(const ValueKey('pcGoldUpgradeFooter')),
              '独立底部操作区',
            );
            final later = safeRect(
              find.byKey(const ValueKey('pcGoldUpgradeLater')),
              'Maybe Later完整点击区域',
            );
            expect(later.height, greaterThanOrEqualTo(44));
            expect(viewport.bottom, lessThanOrEqualTo(footer.top));
            expect(action.bottom, lessThanOrEqualTo(later.top));
            await tester.ensureVisible(find.byType(PCPigUpgradeAccountCard));
            await tester.pump();
            final account = safeRect(
              find.byType(PCPigUpgradeAccountCard),
              '滚动后完整显示收款资料卡',
            );
            expect(account.top, greaterThanOrEqualTo(viewport.top - .01));
            expect(account.bottom, lessThanOrEqualTo(viewport.bottom + .01));
            await tester.ensureVisible(
              find.byKey(const ValueKey('pcGoldUpgradeProgress')),
            );
            await tester.pump();
            final progress = safeRect(
              find.byKey(const ValueKey('pcGoldUpgradeProgress')),
              '滚动后完整显示10金砖进度卡',
            );
            expect(progress.top, greaterThanOrEqualTo(viewport.top - .01));
            expect(progress.bottom, lessThanOrEqualTo(viewport.bottom + .01));
            expect(
              tester.getRect(find.byType(PCPigUpgradeAccountCard)).bottom,
              lessThanOrEqualTo(progress.top),
            );
            if (size.height >= 900) {
              expect(
                action.top - progress.bottom,
                allOf(greaterThanOrEqualTo(7.99), lessThanOrEqualTo(24)),
                reason: '大屏内容应自然收紧，金砖卡到主按钮之间不能出现大段空白',
              );
            }
            expect(tester.getRect(find.byType(PCPigUpgradeButton)), action);
            expect(
              tester.getRect(find.byKey(const ValueKey('pcGoldUpgradeLater'))),
              later,
            );
          } else {
            final hero = safeRect(find.byType(PCPigUpgradeHero), '钻石猪与动态金额牌');
            final account = safeRect(
              find.byType(PCPigUpgradeAccountCard),
              '钻石猪收款资料卡',
            );
            expect(hero.bottom, lessThanOrEqualTo(account.top));
            expect(account.bottom, lessThanOrEqualTo(action.top));
            final ribbon = safeRect(find.byType(PCPigUpgradeRibbon), '钻石猪动态丝带');
            expect(ribbon.bottom, lessThanOrEqualTo(hero.top));
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(PCPigUpgradeButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(await closed, isTrue);
          expect(find.text('Underlying quiz page'), findsOneWidget);
          expect(PCDialogCoordinator.instance.isBusy, isFalse);
        }

        final laterClosed = present(2);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        safeRect(find.text('Maybe Later'), '重新显示后Maybe Later仍完整可点');
        await tester.tap(find.text('Maybe Later'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(await laterClosed, isFalse);
        expect(find.text('Underlying quiz page'), findsOneWidget);
        expect(PCDialogCoordinator.instance.isBusy, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));
      });
    }
  }

  testWidgets('领奖动画结束才展示钻石升级，确认后不再弹出', (tester) async {
    usePortraitQuizViewport(tester);
    SharedPreferences.setMockInitialValues({
      'pc_dollar_number': 99.99,
      'pc_account_id': 'tester@example.com',
    });
    final provider = PCLocalProvider.instance;
    await provider.init();
    final quiz = PCQuizController(onSync: provider.init);
    final bank = PCQuizBank.fromQuestions([
      const PCQuizQuestion(
        question: 'A?',
        a: 'Correct',
        b: 'Wrong',
        answer: 'a',
      ),
    ]);
    var continued = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) => MaterialApp(
            home: PCPigUpgradeHost(
              canPresent: () => true,
              onContinue: () => continued++,
              child: PCQuiz(controller: quiz, bank: bank, active: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byType(PCAwardDialog), findsOneWidget);
    await tester.tap(find.text('Claim').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
    expect(find.byType(PCDiamondPigUpgradeDialog), findsNothing);
    // tipShow 会先等 250ms 完整退场，再播放 1.8s 到账动画；保留
    // 前面的“到账期间不得弹升级”断言，这里独立等待完整动画时长。
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 升级 Host 在动画结束后经 post-frame + 弹窗队列 push，下一帧才绘制。
    await tester.pump();
    expect(find.byType(PCQuizRewardAnimation), findsNothing);
    expect(find.byType(PCDiamondPigUpgradeDialog), findsOneWidget);
    await tester.tap(find.text('Confirm Withdrawal').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(continued, 1);
    expect(PCPigUpgradeController.instance.pendingLevel, isNull);
    // 关闭升级后立即继续答题，不能等下一次手势计时才恢复按钮。
    await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(quiz.correctCount, 2);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(PCAwardDialog))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await PCPigUpgradeController.instance.refresh();
    await tester.pump();
    expect(find.byType(PCDiamondPigUpgradeDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    quiz.dispose();
  });

  testWidgets('金猪Maybe Later只关闭并持久化，不跳转', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_pig_level': 2,
      PCPigUpgradeController.seenKey: 1,
    });
    final upgrades = PCPigUpgradeController();
    var continued = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PCPigUpgradeHost(
          controller: upgrades,
          canPresent: () => true,
          onContinue: () => continued++,
          child: const Scaffold(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PCGoldPigUpgradeDialog), findsOneWidget);
    await tester.tap(find.text('Maybe Later'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(continued, 0);
    expect(upgrades.pendingLevel, isNull);
    final restored = PCPigUpgradeController();
    await restored.refresh();
    expect(restored.pendingLevel, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    upgrades.dispose();
    restored.dispose();
  });

  for (final background in [false, true]) {
    testWidgets('${background ? '前后台恢复' : '切换Tab返回'}后连续点击必须立即答题', (
      tester,
    ) async {
      usePortraitQuizViewport(tester);
      SharedPreferences.setMockInitialValues({'pc_new_guide_end': true});
      final provider = PCLocalProvider.instance;
      await provider.init();
      final quiz = PCQuizController(onSync: provider.init);
      final bank = PCQuizBank.fromQuestions([
        const PCQuizQuestion(
          question: 'A?',
          a: 'Correct',
          b: 'Wrong',
          answer: 'a',
        ),
      ]);
      PigsTabController.switchTo(1);
      final page = PCQuiz(controller: quiz, bank: bank);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, child) => MaterialApp(
              home: ValueListenableBuilder<int>(
                valueListenable: PigsTabController.currentIndex,
                builder: (_, index, child) => IndexedStack(
                  index: index,
                  children: [const SizedBox(), page],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (background) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else {
        PigsTabController.switchTo(0);
        await tester.pump();
        PigsTabController.switchTo(1);
      }
      await tester.pump();
      // 每次间隔少于提示的5秒，不能靠手势计时的偶然重建恢复按钮。
      await tester.tap(find.byKey(const ValueKey('pcQuizAnswerA')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      expect(quiz.correctCount, 1);
      expect(find.byType(PCAwardDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(PCAwardDialog))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      PigsTabController.switchTo(0);
      quiz.dispose();
    });
  }
}
