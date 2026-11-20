import 'dart:async';
import 'support/pc_number_test_assets.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCNewUserHomeFlow.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide1Dialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide2Dialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide3Dialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCCash/PCAccountFeedbackDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCCheckInDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuideQuizDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWithdrawPage.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/pc_shou_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('签到与三题引导在 $size 下按钮位于屏内且非整屏图片', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final page in [
        const PCCheckInDialog(
          rewards: [6, .15, .2, .3, .5, .8, 10],
          isNewUser: true,
        ),
        const PCGuideQuizDialog(index: 2),
      ]) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
        await tester.pump();
        if (page is PCGuideQuizDialog) {
          expect(find.byType(PCShouIcon), findsNothing);
          await tester.pump(const Duration(milliseconds: 1999));
          expect(find.byType(PCShouIcon), findsNothing);
          await tester.pump(const Duration(milliseconds: 1));
          expect(find.byType(PCShouIcon), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        expect(
          tester.widgetList<PCImg>(find.byType(PCImg)).length,
          greaterThan(3),
        );
        for (final button in find.byType(ParticleButton).evaluate()) {
          final rect = tester.getRect(find.byWidget(button.widget));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('美国表单默认 PayPal，仅有效邮箱可提交且空表单禁用按钮', (tester) async {
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PCWithdrawPage(
          countryCode: 'US',
          onSubmitted: (_) => submissions++,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('PayPal'), findsOneWidget);
    expect(find.text('Cash App'), findsOneWidget);
    expect(find.text('PiX'), findsNothing);
    expect(find.text('PagBank'), findsNothing);
    var confirm = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Confirm'), matching: find.byType(InkWell))
          .first,
    );
    expect(confirm.onTap, isNull);
    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.pump();
    confirm = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('Confirm'), matching: find.byType(InkWell))
          .first,
    );
    expect(confirm.onTap, isNotNull);
    // 大屏保持清晰字号，短窗口通过真实滚动到提交按钮。
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(submissions, 1);
    await tester.tap(find.text('Confirm'));
    expect(submissions, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final (size, navigationBar, keyboard, needsScroll) in [
    (const Size(320, 568), 48.0, 300.0, false),
    (const Size(430, 932), 24.0, 360.0, false),
    (const Size(320, 568), 48.0, 405.0, true),
  ]) {
    testWidgets('收款页在 $size 下避开导航栏和 ${keyboard.toInt()} 高的键盘', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final safeArea = FakeViewPadding(top: 24, bottom: navigationBar);
      tester.view.viewPadding = safeArea;
      tester.view.padding = safeArea;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      PCWithdrawDetails? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: PCWithdrawPage(onSubmitted: (value) => submitted = value),
        ),
      );
      final confirm = find.ancestor(
        of: find.text('Confirm'),
        matching: find.byType(InkWell),
      );
      final beforeKeyboard = tester.getRect(confirm);
      expect(beforeKeyboard.bottom, lessThan(size.height - navigationBar));
      expect(beforeKeyboard.height, greaterThanOrEqualTo(44));

      await tester.enterText(find.byType(TextField), 'test@example.com');
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      if (needsScroll) {
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
      }
      final aboveKeyboard = tester.getRect(confirm);
      expect(aboveKeyboard.height, beforeKeyboard.height);
      expect(aboveKeyboard.bottom, lessThanOrEqualTo(size.height - keyboard));
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.tap(confirm);
      await tester.pump();
      expect(submitted?.account, 'test@example.com');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('小屏所有地区只显示 PayPal 和 Cash App，切换后共用输入标题', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: PCWithdrawPage(countryCode: 'BR')),
    );
    await tester.pump();
    for (final name in ['PayPal', 'Cash App']) {
      final rect = tester.getRect(find.text(name));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    for (final name in ['PiX', 'PagBank']) {
      expect(find.text(name), findsNothing);
    }
    expect(find.text('Email/Phone Number'), findsOneWidget);
    final field = find.byType(TextField);
    expect(
      tester.widget<TextField>(field).keyboardType,
      TextInputType.emailAddress,
    );
    await tester.enterText(field, 'player@example.com');
    await tester.tap(find.text('Cash App'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Email/Phone Number'), findsOneWidget);
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.phone);
    await tester.enterText(field, '2025550123');
    await tester.tap(find.text('PayPal'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<TextField>(field).controller?.text,
      'player@example.com',
    );
    expect(tester.takeException(), isNull);
  });
  Future<void> showGuide(
    WidgetTester tester,
    PCNewUserGuideController controller, {
    NavigatorObserver? observer,
  }) async {
    await controller.load();
    await PCLocalProvider.instance.init();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          navigatorObservers: [?observer],
          home: PCNewUserHomeFlow(
            controller: controller,
            child: const Scaffold(),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Finder checkInClaim() => find
      .descendant(
        of: find.byType(PCCheckInDialog),
        matching: find.byType(ParticleButton),
      )
      .first;

  testWidgets('新手三题每答对一题都先显示免广告的领奖弹窗', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"quiz"}',
    });
    final events = <String>[];
    final originalReporter = PCAnalytics.reporter;
    PCAnalytics.reporter = (name, _) => events.add(name);
    addTearDown(() => PCAnalytics.reporter = originalReporter);
    final controller = PCNewUserGuideController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      controller.dispose();
    });

    await showGuide(tester, controller);
    for (var index = 0; index < 3; index++) {
      final question = find.byType(PCGuideQuizDialog);
      for (var frame = 0; frame < 6 && question.evaluate().isEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        question,
        findsOneWidget,
        reason: '第 ${index + 1} 题，当前阶段：${controller.stage}，已展示事件：$events',
      );
      expect(tester.widget<PCGuideQuizDialog>(question).index, index);
      await tester.tap(
        find.descendant(
          of: question,
          matching: find.byKey(const ValueKey('pcQuizAnswerA')),
        ),
      );
      await tester.pump();
      if (index == 0) {
        // 反馈期间路由被外部关闭，Flutter 不会返回答案，但点击已有效。
        await tester.pump(const Duration(milliseconds: 500));
        Navigator.of(tester.element(question)).pop();
      } else {
        await tester.pump(const Duration(seconds: 1));
      }
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(controller.stage, PCNewUserStage.quizReward);
      expect(question, findsNothing);
      final award = tester.widget<PCAwardDialog>(find.byType(PCAwardDialog));
      expect(award.adsEnabled, false);
      expect(award.showAdBadge, false);
      expect(award.award, greaterThan(0));
      await tester.tap(find.text('Claim').last);
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 180));
      }
      expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
      expect(question, findsNothing);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(PCQuizRewardAnimation), findsNothing);
      expect(controller.correctMask, (1 << (index + 1)) - 1);
    }
    expect(controller.stage, PCNewUserStage.withdrawalEligibility);
    expect(
      events.where((event) => event == 'new_quiz_correct_pop'),
      hasLength(3),
    );
    expect(tester.takeException(), isNull);
  });

  Future<void> tapDuringCheckInExit(
    WidgetTester tester,
    Element checkInElement,
    ModalRoute<dynamic> checkInRoute,
    VoidCallback oldClaim,
    _CheckInNavigationObserver observer,
  ) async {
    // 到账完成后只推进微小帧，确保旧签到仍处于250ms退场中。
    for (var frame = 0; frame < 20 && checkInRoute.isCurrent; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(checkInElement.mounted, isTrue);
    expect(checkInRoute.animation!.status, AnimationStatus.reverse);
    expect(checkInRoute.isCurrent, isFalse);
    // 模拟已经派发的旧点击回调，不能再次pop首页或下一步引导。
    oldClaim();
    oldClaim();
    await tester.pump(const Duration(milliseconds: 1));
    expect(observer.popped, [same(checkInRoute)]);
    expect(tester.takeException(), isNull);
  }

  testWidgets('新用户签到有AD标识且真实激励成功到账一次，连点退场后继续到账和佣金说明', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"checkIn"}',
      'gp177_pig_number': '{"new_ad_console":1}',
    });
    var requests = 0;
    final ad = Completer<bool>();
    final controller = PCNewUserGuideController(
      requestRewardedAd: (placement) {
        expect(placement, 'nkmdl_signin_rv');
        requests++;
        return ad.future;
      },
    );
    final observer = _CheckInNavigationObserver();
    await showGuide(tester, controller, observer: observer);
    expect(find.byType(PCCheckInDialog), findsOneWidget);
    final checkInElement = tester.element(find.byType(PCCheckInDialog));
    final checkInRoute = ModalRoute.of(checkInElement)!;
    final oldClaim = tester.widget<ParticleButton>(checkInClaim()).onTap;
    expect(
      tester.widget<PCCheckInDialog>(find.byType(PCCheckInDialog)).showAdBadge,
      true,
    );
    await tester.tap(checkInClaim());
    await tester.pump();
    await tester.tap(checkInClaim());
    expect(controller.balance, 0);
    expect(controller.checkInDay, 0);
    expect(requests, 1);
    ad.complete(true);
    await tapDuringCheckInExit(
      tester,
      checkInElement,
      checkInRoute,
      oldClaim,
      observer,
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(controller.balance, 6);
    expect(controller.checkInDay, 1);
    expect(requests, 1);
    expect(observer.popped, [same(checkInRoute)]);
    expect(find.byType(PCCheckInDialog), findsNothing);
    expect(find.byType(PCGuide1Dialog), findsOneWidget);
    expect(await controller.claimCheckIn(), false, reason: '当前签到已结算，旧请求不能再次领奖');
    expect(controller.balance, 6);
    expect(controller.checkInDay, 1);
    expect(requests, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    // 到账页先完整退场，再由引导调度器保存进度、排队下一弹窗；
    // 新路由在下一帧绘制，不能沿用 pop 即完成时的旧帧预算。
    await tester.pump();
    expect(find.byType(PCGuide2Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    controller.dispose();
  });

  for (final throwsAd in [false, true]) {
    testWidgets('新用户签到激励${throwsAd ? '异常' : '失败'}同路由显示失败，用户关闭才继续quiz且不发奖', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        PCNewUserGuideController.progressKey: 3,
        PCNewUserGuideController.flowKey: '{"stage":"checkIn"}',
        'gp177_pig_number': '{"new_ad_console":0}',
        'pc_dollar_number': 12.34,
      });
      var requests = 0;
      final ad = Completer<bool>();
      final controller = PCNewUserGuideController(
        requestRewardedAd: (placement) {
          expect(placement, 'nkmdl_signin_rv');
          requests++;
          return ad.future;
        },
      );
      final observer = _CheckInNavigationObserver();
      await showGuide(tester, controller, observer: observer);
      final route = ModalRoute.of(
        tester.element(find.byType(PCCheckInDialog)),
      )!;
      expect(
        tester
            .widget<PCCheckInDialog>(find.byType(PCCheckInDialog))
            .showAdBadge,
        true,
      );
      await tester.tap(checkInClaim());
      await tester.pump();
      if (throwsAd) {
        ad.completeError(StateError('SDK unavailable'));
      } else {
        ad.complete(false);
      }
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(PCAdLoadingFailedDialog))),
        same(route),
      );
      expect(find.byType(PCGuideQuizDialog), findsNothing);
      expect(find.byType(PCGuide1Dialog), findsNothing);
      expect(controller.stage, PCNewUserStage.quiz);
      expect(controller.balance, 12.34);
      expect(controller.checkInDay, 0);
      expect(observer.popped, isEmpty);
      await tester.tap(find.text('Try Again').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(find.byType(PCCheckInDialog), findsNothing);
      expect(find.byType(PCGuideQuizDialog), findsOneWidget);
      expect(controller.balance, 12.34);
      expect(controller.checkInDay, 0);
      expect(requests, 1, reason: '失败面板Try Again仅关闭，不重新请求');
      expect(observer.popped, [same(route)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      controller.dispose();
    });
  }

  testWidgets('新用户签到正常取消不显示失败、不发奖并持久化续接答题，连点仅请求一次', (tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"checkIn"}',
      'pc_dollar_number': 12.34,
    });
    final ad = Completer<PCAdOutcome>();
    var requests = 0;
    PCRewardedAdService.instance.bindOutcomeHandler((placement) {
      expect(placement, 'nkmdl_signin_rv');
      requests++;
      return ad.future;
    });
    addTearDown(() => PCRewardedAdService.instance.handler = null);
    final controller = PCNewUserGuideController();
    await showGuide(tester, controller);
    await tester.tap(checkInClaim());
    await tester.pump();
    await tester.tap(checkInClaim());
    expect(requests, 1);
    ad.complete(PCAdOutcome.cancelled);
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(find.byType(PCCheckInDialog), findsNothing);
    expect(find.byType(PCGuide1Dialog), findsNothing);
    expect(find.byType(PCGuideQuizDialog), findsOneWidget);
    expect(controller.stage, PCNewUserStage.quiz);
    expect(controller.balance, 12.34);
    expect(controller.checkInDay, 0);
    final restored = PCNewUserGuideController();
    await restored.load();
    expect(restored.stage, PCNewUserStage.quiz);
    expect(restored.checkInDay, 0);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    controller.dispose();
    restored.dispose();
  });

  testWidgets('签到广告成功后保存异常只提示存储错误，不切广告失败面板', (tester) async {
    var requests = 0;
    PCRewardedAdService.instance.bindOutcomeHandler((_) async {
      requests++;
      return PCAdOutcome.success;
    });
    addTearDown(() => PCRewardedAdService.instance.handler = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PCCheckInDialog(
            rewards: const [6, .15, .2, .3, .5, .8, 10],
            onClaimOutcome: () async {
              expect(
                (await PCRewardedAdService.instance.requestOutcome(
                  'nkmdl_signin_rv',
                )).isSuccess,
                isTrue,
              );
              throw StateError('store unavailable');
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(checkInClaim());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(requests, 1);
    expect(find.byType(PCCheckInDialog), findsOneWidget);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(
      find.text('Unable to save progress. Please try again.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('普通签到激励失败同路由显示失败，Try Again仅退出且可再次签到', (tester) async {
    late BuildContext context;
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
    });
    var requests = 0;
    final controller = PCNewUserGuideController(
      requestRewardedAd: (_) async {
        requests++;
        return false;
      },
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold();
          },
        ),
      ),
    );
    final closed = context.tipShow2(
      PCCheckInDialog(
        rewards: controller.config.checkInRewards,
        onClaim: controller.claimCheckIn,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final route = ModalRoute.of(tester.element(find.byType(PCCheckInDialog)))!;
    expect(
      tester.widget<PCCheckInDialog>(find.byType(PCCheckInDialog)).showAdBadge,
      true,
    );
    await tester.tap(checkInClaim());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(PCAdLoadingFailedDialog))),
      same(route),
    );
    expect(controller.stage, PCNewUserStage.complete);
    expect(controller.balance, 0);
    expect(controller.checkInDay, 0);
    await tester.tap(find.text('Try Again').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await closed, false);
    expect(controller.canCheckIn, true);
    expect(requests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('冷启动恢复官方通知时保留收款页背景，继续后回首页', (tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey:
          '{"stage":"officialNotice","confirmedUser":"t***.com"}',
    });
    final controller = PCNewUserGuideController();
    await controller.load();
    await PCLocalProvider.instance.init();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: PCNewUserHomeFlow(
            controller: controller,
            child: const Scaffold(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(PCWithdrawPage), findsOneWidget);
    expect(find.byType(PCAccountFeedbackDialog), findsOneWidget);
    await tester.tap(find.text('Continue'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(PCWithdrawPage), findsNothing);
    expect(find.byType(PCGuide3Dialog), findsOneWidget);
    expect(controller.stage, PCNewUserStage.growBonus);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    controller.dispose();
  });
}

class _CheckInNavigationObserver extends NavigatorObserver {
  final List<Route<dynamic>> popped = [];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
    super.didPop(route, previousRoute);
  }
}
