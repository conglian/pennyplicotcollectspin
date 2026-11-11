import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCDiamondReminderDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCReviewProgressDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalReviewVerificationDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCReviewPresentationController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_GradientText.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    double collected = 7.25,
    int progress = 40,
    bool reduced = false,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced, padding: padding),
            child: PCWithdrawalReviewVerificationDialog(
              collected: collected,
              reviewProgress: progress,
            ),
          ),
        ),
      ),
    );
  }

  PCProcessDiamondRing ring(WidgetTester tester) =>
      tester.widget<PCProcessDiamondRing>(find.byType(PCProcessDiamondRing));

  void expectProgressInSync(WidgetTester tester) {
    final label = tester.widget<PCGradientText>(find.byType(PCGradientText));
    expect(label.text, '${(ring(tester).progress * 100).round()}%');
  }

  Future<BuildContext> routeHost(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    return context;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  tearDown(() {
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('两种审核页共享首次展示记录，后续两次及冷启动均为前两项对号', (tester) async {
    final context = await routeHost(tester);
    for (var appearance = 0; appearance < 3; appearance++) {
      final presentation = PCReviewPresentationController();
      final dialog = appearance == 0
          ? PCWithdrawalReviewVerificationDialog(
              collected: 0,
              reviewPresentation: presentation,
            )
          : PCReviewProgressDialog(
              collected: appearance * 4,
              fromProgress: 40,
              toProgress: appearance == 1 ? 75 : 89,
              reviewPresentation: presentation,
            );
      final result = context.tipShow2(
        dialog,
        scaleContent: false,
        onPresented: presentation.recordPresentation,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final completed = appearance == 0 ? 1 : 2;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is PCImg && widget.name == 'pc_process_review_check',
        ),
        findsNWidgets(completed),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is PCImg && widget.name == 'pc_process_review_loading',
        ),
        findsNWidgets(3 - completed),
      );
      final rotations = find.descendant(
        of: find.byType(PCProcessReviewChecklist),
        matching: find.byType(RotationTransition),
      );
      final previous = tester
          .widget<RotationTransition>(rotations.first)
          .turns
          .value;
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.widget<RotationTransition>(rotations.first).turns.value,
        isNot(previous),
        reason: '待审核图标应持续旋转，而非静态加载图',
      );
      // 同一真实展示的重复回调、进度动画重建都不能把第一次提前计为第二次。
      await presentation.recordPresentation();
      await tester.pump(const Duration(seconds: 4));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(PCReviewPresentationController.storageKey),
        completed,
      );
      expect(presentation.value, completed);
      await tester.tap(
        find.byKey(
          ValueKey(appearance == 0 ? 'pcWithdrawalClose' : 'pcProcessClose'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await result, isFalse);
      presentation.dispose();
    }
  });

  testWidgets('排队后失效的审核路由不消费首次展示记录', (tester) async {
    final context = await routeHost(tester);
    final release = PCDialogCoordinator.instance.holdPresentation();
    final presentation = PCReviewPresentationController();
    final result = context.tipShow2(
      PCWithdrawalReviewVerificationDialog(
        collected: 0,
        reviewPresentation: presentation,
      ),
      canPresent: () => false,
      onPresented: presentation.recordPresentation,
    );
    await tester.pump();
    release();
    await tester.pump();
    expect(await result, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(PCReviewPresentationController.storageKey),
      isFalse,
    );
    presentation.dispose();
  });

  testWidgets('首次审核验证从0非匀速增长到40，实际钻石不变且不自动关闭', (tester) async {
    await mount(tester);
    expect(ring(tester).progress, 0);
    expectProgressInSync(tester);
    expect(ring(tester).collected, 7.25);
    expect(find.text('7.25/20'), findsOneWidget);
    await tester.pump();
    final samples = <double>[0];
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      samples.add(ring(tester).progress);
      expectProgressInSync(tester);
      expect(ring(tester).collected, 7.25);
    }
    expect(samples[1], greaterThan(0));
    expect(samples.last, lessThan(.4));
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
    }
    final deltas = List.generate(
      samples.length - 1,
      (i) => samples[i + 1] - samples[i],
    );
    expect(
      deltas.any((delta) => (delta - deltas.first).abs() > .00001),
      isTrue,
      reason: '等时间间隔的进度增量应有快慢变化，而非匀速动画',
    );
    await tester.pump(const Duration(seconds: 6));
    expect(ring(tester).progress, .4);
    expectProgressInSync(tester);
    expect(ring(tester).collected, 7.25);
    expect(find.byType(PCWithdrawalReviewVerificationDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('减少动画直接展示目标40但不改变钻石数量', (tester) async {
    await mount(tester, reduced: true, collected: 19.99);
    await tester.pump();
    expect(ring(tester).progress, .4);
    expectProgressInSync(tester);
    expect(ring(tester).collected, 19.99);
    expect(find.text('19.99/20'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(PCWithdrawalReviewVerificationDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final proceed in [false, true]) {
    testWidgets('进度未完成时${proceed ? 'Continue' : '关闭'}立即返回并释放展示权，不影响下一弹窗', (
      tester,
    ) async {
      final context = await routeHost(tester);
      final closed = context.tipShow2(
        const PCWithdrawalReviewVerificationDialog(collected: 2.5),
        scaleContent: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ring(tester).progress, lessThan(.4));
      await tester.tap(
        find.byKey(
          ValueKey(
            proceed ? 'pcWithdrawalVerificationContinue' : 'pcWithdrawalClose',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(await closed, proceed);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
      final next = context.tipShow2(
        const PCDiamondReminderDialog(remaining: 5.75),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(PCDiamondReminderDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('pcProcessContinue')));
      await tester.pumpAndSettle();
      expect(await next, isTrue);
    });
  }

  testWidgets('动画中直接卸载不遗留Ticker或关闭回调', (tester) async {
    await mount(tester);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('${size.width.toInt()}宽屏幕动画后仍保留卡片和安全区内操作', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const insets = EdgeInsets.only(top: 24, bottom: 34);
      await mount(tester, collected: 12.5, padding: insets);
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));

      expect(ring(tester).progress, .4);
      expectProgressInSync(tester);
      expect(find.text('12.5/20'), findsOneWidget);
      final panel = tester.getRect(
        find.byKey(const ValueKey('pcWithdrawalWhitePanel')),
      );
      final close = tester.getRect(
        find.byKey(const ValueKey('pcWithdrawalClose')),
      );
      final action = tester.getRect(
        find.byKey(const ValueKey('pcWithdrawalVerificationContinue')),
      );
      final viewport = Rect.fromLTRB(
        0,
        insets.top,
        size.width,
        size.height - insets.bottom,
      );
      expect(viewport.contains(panel.topLeft), isTrue);
      expect(viewport.contains(panel.bottomRight), isTrue);
      expect(panel.contains(close.center), isTrue);
      expect(panel.contains(action.center), isTrue);
      expect(action.overlaps(close), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
