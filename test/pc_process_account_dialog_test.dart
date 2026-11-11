import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessBannerArtwork.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCConfirmAccountDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessAccountConfirmedDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessAccountDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWithdrawPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(
    WidgetTester tester,
    Widget dialog,
    ValueChanged<Object?> result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: dialog is PCConfirmAccountDialog),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result(
                await Navigator.of(
                  context,
                ).push<Object?>(MaterialPageRoute(builder: (_) => dialog)),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 430.0]) {
    testWidgets('账号邀请$width宽动态金额与确认关闭返回值', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Object? result;
      await show(
        tester,
        const PCConfirmAccountDialog(withdrawalTarget: 135),
        (value) => result = value,
      );
      expect(find.text("You're About To Withdraw \$135!"), findsOneWidget);
      expect(tester.takeException(), isNull);
      final button = find.byKey(const ValueKey('pcConfirmAccountAction'));
      final background = find.byWidgetPredicate(
        (widget) =>
            widget is PCImg && widget.name == 'pc_process_account_button',
      );
      expect(tester.getSize(button), const Size(268, 64));
      expect(tester.getSize(background), const Size(268, 64));
      expect(tester.getCenter(button), tester.getCenter(background));
      expect(
        find.byKey(const ValueKey('pcConfirmAccountGlow')),
        findsNothing,
      ); // 减少动画使用原静图。
      await tester.tap(find.byKey(const ValueKey('pcConfirmAccountAction')));
      await tester.pumpAndSettle();
      expect(result, true);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pcConfirmAccountClose')));
      await tester.pumpAndSettle();
      expect(result, false);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('资料表单$width宽四渠道可选，默认PayPal，返回而不保存', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Object? result;
      await show(
        tester,
        const PCProcessAccountDialog(initialPaymentIndex: 2),
        (value) => result = value,
      );
      for (final name in ['PayPal', 'Cash App', 'PiX', 'PagBank']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Email:'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pcProcessMethod1')));
      await tester.pumpAndSettle();
      expect(find.text('Phone Number:'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pcProcessAccountInput')),
        '1234567890',
      );
      await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
      await tester.pumpAndSettle();
      expect(result, isA<PCWithdrawDetails>());
      expect((result as PCWithdrawDetails).method, PCWithdrawMethod.cashApp);
      expect((result as PCWithdrawDetails).account, '1234567890');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('账号邀请循环播放本地旋转光圈，大小与静图一致且不挡按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: PCConfirmAccountDialog(withdrawalTarget: 100),
        ),
      ),
    );
    await tester.pump();
    final animation = tester.widget<LottieBuilder>(
      find.byKey(const ValueKey('pcConfirmAccountGlow')),
    );
    expect(animation.repeat, isTrue);
    expect(
      tester.getSize(find.byKey(const ValueKey('pcConfirmAccountGlow'))),
      const Size(220, 220),
    );
    final button = find.byKey(const ValueKey('pcConfirmAccountAction'));
    expect(tester.getSize(button), const Size(268, 64));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('新输入拒绝空账号、短邮箱和错误手机号；合法邮箱可提交', (tester) async {
    Object? result;
    await show(
      tester,
      const PCProcessAccountDialog(),
      (value) => result = value,
    );
    for (final invalid in ['', 'a@b.co', 'not-an-email']) {
      await tester.enterText(
        find.byKey(const ValueKey('pcProcessAccountInput')),
        invalid,
      );
      await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
      await tester.pump();
      expect(find.byType(PCProcessAccountDialog), findsOneWidget);
      expect(result, isNull);
      expect(
        find.text('Please enter the correct withdrawal account number'),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.enterText(
      find.byKey(const ValueKey('pcProcessAccountInput')),
      'player@example.com',
    );
    await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
    await tester.pumpAndSettle();
    expect((result as PCWithdrawDetails).method, PCWithdrawMethod.paypal);
    expect((result as PCWithdrawDetails).account, 'player@example.com');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('已有脱敏资料只显示原渠道，未经修改可直接确认，关闭不返回资料', (tester) async {
    Object? result;
    await show(
      tester,
      const PCProcessAccountDialog(
        initialAccount: 'a***7890',
        initialPaymentIndex: 1,
        hasSavedAccount: true,
      ),
      (value) => result = value,
    );
    expect(find.text('PiX'), findsOneWidget);
    for (final name in ['PayPal', 'Cash App', 'PagBank']) {
      expect(find.text(name), findsNothing);
    }
    expect(find.text('a***7890'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
    await tester.pumpAndSettle();
    expect((result as PCWithdrawDetails).method, PCWithdrawMethod.pix);
    expect((result as PCWithdrawDetails).account, 'a***7890');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pcProcessAccountClose')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final pair in [
    (1, PCWithdrawMethod.pix, 'PiX'),
    (2, PCWithdrawMethod.cashApp, 'Cash App'),
  ]) {
    testWidgets('缓存渠道${pair.$1}正确回填${pair.$3}', (tester) async {
      Object? result;
      await show(
        tester,
        PCProcessAccountDialog(
          initialAccount: 'a***7890',
          initialPaymentIndex: pair.$1,
          hasSavedAccount: true,
        ),
        (value) => result = value,
      );
      expect(find.text(pair.$3), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pcProcessAccountApply')));
      await tester.pumpAndSettle();
      expect((result as PCWithdrawDetails).method, pair.$2);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final width in [320.0, 430.0]) {
    testWidgets('账号确认横幅$width宽从屏外平移、中心完整停2秒、原路退场只pop一次', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final observer = _PopObserver();
      var returned = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) =>
                          const PCProcessAccountConfirmedDialog(
                            withdrawalTarget: 135,
                          ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                  returned++;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
      final key = find.byKey(const ValueKey('pcProcessAccountConfirmedSlide'));
      final artwork = find.byType(PCProcessBannerArtwork);
      final initialX = tester.widget<Transform>(key).transform.storage[12];
      expect(initialX, lessThan(-width));
      expect(tester.getRect(artwork).right, lessThanOrEqualTo(0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Transform>(key).transform.storage[12],
        closeTo(0, .001),
      );
      final centered = tester.getRect(artwork);
      expect(centered.center.dx, closeTo(width / 2, .001));
      expect(centered.center.dy, closeTo(350, .001));
      expect(centered.width / centered.height, closeTo(360 / 332, .001));
      expect(
        find.textContaining('Payout Details Confirmed', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining(r'$135', findRichText: true), findsWidgets);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(returned, 0);
      expect(observer.popCount, 0);
      expect(
        tester.widget<Transform>(key).transform.storage[12],
        closeTo(0, .001),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 200));
      final leavingX = tester.widget<Transform>(key).transform.storage[12];
      expect(leavingX, lessThan(0));
      expect(leavingX, greaterThan(initialX));
      expect(
        tester.getRect(artwork).center.dy,
        closeTo(centered.center.dy, .001),
      );
      expect(observer.popCount, 0);
      await tester.pumpAndSettle();
      expect(returned, 1);
      expect(observer.popCount, 1);
      expect(find.byType(PCProcessAccountConfirmedDialog), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(observer.popCount, 1);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('减少动画直接中心显示，仍停留2秒且只关闭自身一次', (tester) async {
    final observer = _PopObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) =>
                      const PCProcessAccountConfirmedDialog(
                        withdrawalTarget: 200,
                      ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();
    final key = find.byKey(const ValueKey('pcProcessAccountConfirmedSlide'));
    expect(tester.widget<Transform>(key).transform.storage[12], 0);
    expect(find.textContaining(r'$200', findRichText: true), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(observer.popCount, 0);
    expect(tester.widget<Transform>(key).transform.storage[12], 0);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(observer.popCount, 1);
    expect(find.byType(PCProcessAccountConfirmedDialog), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(observer.popCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('预览可调整停留时间；提前关闭会取消计时，不误关后续页面', (tester) async {
    final observer = _PopObserver();
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            source = context;
            return const Scaffold(body: Text('Source'));
          },
        ),
      ),
    );
    Navigator.of(source).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const PCProcessAccountConfirmedDialog(
          withdrawalTarget: 100,
          displayDuration: Duration(seconds: 5),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(observer.popCount, 0);
    Navigator.of(source).pop();
    await tester.pumpAndSettle();
    expect(observer.popCount, 1);
    Navigator.of(source).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const Scaffold(body: Text('Next Page')),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(observer.popCount, 1);
    expect(find.text('Next Page'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PopObserver extends NavigatorObserver {
  int popCount = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}
