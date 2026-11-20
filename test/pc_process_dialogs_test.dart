import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCDiamondReminderDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCOfficialCollectNoticeDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCQuizRankingDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCReviewProgressDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/pc_GradientNumber.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_text.dart';

void main() {
  Future<void> host(
    WidgetTester tester,
    void Function(BuildContext) onContext, {
    bool reduced = false,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          onContext(context);
          return const Scaffold(body: Text('home'));
        },
      ),
    ),
  );

  testWidgets('审核卡展示精确钻石及滚动进度，完成后保留至手动Continue', (tester) async {
    late BuildContext context;
    await host(tester, (value) => context = value);
    var resolved = false;
    final closed = context
        .tipShow2(
          const PCReviewProgressDialog(
            collected: 7.25,
            fromProgress: 30,
            toProgress: 40,
          ),
          scaleContent: false,
        )
        .then((value) {
          resolved = true;
          return value;
        });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('7.25/20'), findsOneWidget);
    final roller = tester.widget<PCGradientNumberRoller>(
      find.byKey(const ValueKey('pcReviewProgressNumber')),
    );
    expect(roller.currentValue, 30);
    expect(roller.value, 40);
    expect(roller.showDolas, isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(PCReviewProgressDialog), findsOneWidget);
    expect(resolved, isFalse, reason: '审核动画结束不能自动关闭页面');
    expect(PCDialogCoordinator.instance.isBusy, isTrue);
    await tester.tap(find.byKey(const ValueKey('pcProcessContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await closed, isTrue);
    expect(find.byType(PCReviewProgressDialog), findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('减少动画的审核卡立即到目标，仍由用户关闭而不自动退出', (tester) async {
    late BuildContext context;
    await host(tester, (value) => context = value, reduced: true);
    final closed = context.tipShow2(
      const PCReviewProgressDialog(
        collected: 7.25,
        fromProgress: 40,
        toProgress: 75,
      ),
      scaleContent: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<PCProcessDiamondRing>(find.byType(PCProcessDiamondRing))
          .progress,
      .75,
    );
    expect(
      tester
          .widget<PCGradientNumberRoller>(
            find.byKey(const ValueKey('pcReviewProgressNumber')),
          )
          .duration,
      0,
    );
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(PCReviewProgressDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcProcessClose')));
    await tester.pumpAndSettle();
    expect(await closed, isFalse);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('审核卡动画中手动关闭，不能误关闭随后显示的钻石提醒', (tester) async {
    late BuildContext context;
    await host(tester, (value) => context = value);
    final closed = context.tipShow2(
      const PCReviewProgressDialog(
        collected: 2,
        fromProgress: 10,
        toProgress: 20,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('pcProcessClose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await closed, isFalse);
    final next = context.tipShow2(
      const PCDiamondReminderDialog(remaining: 5.75),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4000));
    expect(find.byType(PCDiamondReminderDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcProcessContinue')));
    await tester.pumpAndSettle();
    expect(await next, isTrue);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('钻石提醒数量动态，Continue为true，关闭为false', (tester) async {
    late BuildContext context;
    await host(tester, (value) => context = value);
    for (final proceed in [true, false]) {
      final closed = context.tipShow2(
        const PCDiamondReminderDialog(remaining: 2.45),
      );
      // 待审核图标持续旋转，页面显示后不会settle。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Only ×2.45 diamonds left'), findsOneWidget);
      expect(find.text('Collect ×2.45 Diamonds'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 950));
      expect(find.text('17.55/20'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey(proceed ? 'pcProcessContinue' : 'pcProcessClose')),
      );
      await tester.pumpAndSettle();
      expect(await closed, proceed);
    }
  });

  testWidgets('官方通知只展示剩余钻石，按钮只关闭，不出现美元', (tester) async {
    late BuildContext context;
    await host(tester, (value) => context = value);
    final closed = context.tipShow2(
      const PCOfficialCollectNoticeDialog(remaining: 8.75),
    );
    await tester.pumpAndSettle();
    expect(find.text('Official Notice'), findsOneWidget);
    expect(find.text('×8.75'), findsOneWidget);
    expect(find.text(' diamonds left'), findsOneWidget);
    expect(
      tester
          .widgetList<PCText>(find.byType(PCText))
          .any((text) => text.text.contains(r'$')),
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('pcProcessContinue')));
    await tester.pumpAndSettle();
    expect(await closed, isFalse);
  });

  testWidgets('本人排行上移时不缩放，到第一位完成后循环放大缩小，真实次数不改变', (tester) async {
    late BuildContext context;
    await host(tester, (value) => context = value);
    final closed = context.tipShow2(
      const PCQuizRankingDialog(
        answerCount: 35,
        account: 'myaccount@example.com',
        seed: 21,
      ),
      scaleContent: false,
    );
    await tester.pump();
    // 第一帧队列push，第二帧创建排行State并建立800ms计时起点。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final self = find.byKey(const ValueKey('pcQuizRankRow_self'));
    expect(
      find.descendant(of: self, matching: find.text('myaccount@example.com')),
      findsOneWidget,
    );
    final before = tester.getTopLeft(self).dy;
    final otherRows = List.generate(
      3,
      (i) => find.byKey(ValueKey('pcQuizRankRow_other$i')),
    );
    final initialPosition = otherRows
        .where((row) => tester.getTopLeft(row).dy < before)
        .length;
    expect(initialPosition, anyOf(2, 3));
    double rowScale(String id) => tester
        .widget<Transform>(find.byKey(ValueKey('pcQuizRankScale_$id')))
        .transform
        .entry(0, 0);
    void expectOtherRowsUnscaled() {
      for (var index = 0; index < 3; index++) {
        expect(rowScale('other$index'), 1, reason: '其他用户行不能参与本人的庆祝缩放');
      }
    }

    expect(rowScale('self'), 1);
    expectOtherRowsUnscaled();
    final otherCounts = otherRows
        .map(
          (row) => tester
              .widgetList<PCText>(
                find.descendant(of: row, matching: find.byType(PCText)),
              )
              .map((text) => int.tryParse(text.text))
              .whereType<int>()
              .single,
        )
        .toList();
    expect(otherCounts.every((count) => count >= 29 && count <= 32), isTrue);
    for (var step = 0; step < initialPosition; step++) {
      // 第一步800ms触发（已有300ms入场），后续每步之间保留200ms停顿。
      await tester.pump(Duration(milliseconds: step == 0 ? 500 : 200));
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.byKey(const ValueKey('pcQuizRankPosition_self')),
            )
            .top,
        232.0 + 88 * (initialPosition - step - 1),
      );
      expect(rowScale('self'), 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rowScale('self'), 1, reason: '600ms上移动画中段不能提前开始放大');
      expectOtherRowsUnscaled();
      await tester.pump(const Duration(milliseconds: 299));
      expect(rowScale('self'), 1, reason: '最后一次位移结束前1ms仍不得庆祝缩放');
      await tester.pump(const Duration(milliseconds: 1));
      expect(rowScale('self'), 1, reason: '到达第一位时应从原始尺寸开始庆祝');
    }
    // 最后位移的完成回调在下一绘制帧交接给庆祝Ticker；先单独冲刷这帧，
    // 再计缩放时长，避免把onEnd启动帧当作已运行275ms的动画帧。
    await tester.pump(const Duration(milliseconds: 1));
    final after = tester.getTopLeft(self).dy;
    final pulse =
        tester
                .widget<AnimatedBuilder>(
                  find.descendant(
                    of: find.byKey(const ValueKey('pcQuizRankPosition_self')),
                    matching: find.byType(AnimatedBuilder),
                  ),
                )
                .animation
            as AnimationController;
    expect(pulse.isAnimating, isTrue, reason: '最后位移完成后应启动庆祝Ticker');
    expect(after, lessThan(before));
    expect(otherRows.every((row) => tester.getTopLeft(row).dy > after), isTrue);
    expect(
      find.descendant(of: self, matching: find.text('35')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 275));
    expect(rowScale('self'), greaterThan(1));
    expectOtherRowsUnscaled();
    await tester.pump(const Duration(milliseconds: 825));
    expect(rowScale('self'), closeTo(1.04, .0001));
    await tester.pump(const Duration(milliseconds: 550));
    // Flutter的easeInOutSine是Cubic近似曲线，半周期约为1.02011。
    expect(rowScale('self'), closeTo(1.02, .0002));
    expect(
      rowScale('self'),
      allOf(greaterThan(1), lessThan(1.04)),
      reason: '达到1.04峰值后应缩小，且尚未回到原始尺寸',
    );
    expectOtherRowsUnscaled();
    await tester.pump(const Duration(milliseconds: 550));
    expect(rowScale('self'), closeTo(1, .0001));
    await tester.pump(const Duration(milliseconds: 550));
    expect(rowScale('self'), greaterThan(1), reason: '放大→缩小后应继续下一轮，而非只播放一次');
    expectOtherRowsUnscaled();
    await tester.tap(find.byKey(const ValueKey('pcQuizRankContinue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await closed, isTrue);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(430, 932),
  ]) {
    testWidgets('4种流程弹窗在$size适配安全区域和长账号', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dialog in const <Widget>[
        PCQuizRankingDialog(
          answerCount: 125,
          account: 'longlonglongaccount@example.com',
          seed: 1,
        ),
        PCReviewProgressDialog(
          collected: 19.99,
          fromProgress: 70,
          toProgress: 80,
        ),
        PCDiamondReminderDialog(remaining: .01),
        PCOfficialCollectNoticeDialog(remaining: 12.95),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  disableAnimations: true,
                ),
                child: dialog,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${dialog.runtimeType}不应溢出',
        );
        if (dialog is PCQuizRankingDialog) {
          final backgroundRect = tester.getRect(
            find.byKey(const ValueKey('pcQuizRankFullscreenBackground')),
          );
          expect(
            backgroundRect,
            Offset.zero & size,
            reason: '背景必须覆盖包含安全区域的完整viewport',
          );
          final fireworks = tester.getRect(
            find.byKey(const ValueKey('pcQuizRankFireworks')),
          );
          expect(fireworks.left, closeTo(0, .0001));
          expect(
            fireworks.top,
            closeTo(0, .0001),
            reason: '烟花应从屏幕顶部开始，不得被顶部24安全区向下推',
          );
          expect(fireworks.width, closeTo(size.width, .0001));
          expect(
            fireworks.height,
            closeTo(size.width * 200 / 360, .0001),
            reason: '全宽烟花保持360:200设计比例，不拉伸或横向裁剪',
          );
          for (final id in ['self', 'other0', 'other1', 'other2']) {
            expect(
              tester
                  .widget<Transform>(
                    find.byKey(ValueKey('pcQuizRankScale_$id')),
                  )
                  .transform
                  .entry(0, 0),
              1,
              reason: '减少动画时各排行行保持原始尺寸',
            );
          }
          await tester.pump(const Duration(milliseconds: 1100));
          expect(
            tester
                .widget<Transform>(
                  find.byKey(const ValueKey('pcQuizRankScale_self')),
                )
                .transform
                .entry(0, 0),
            1,
            reason: '减少动画时只显示静态高亮，不应恢复循环缩放',
          );
        }
        final button = find.byKey(
          ValueKey(
            dialog is PCQuizRankingDialog
                ? 'pcQuizRankContinue'
                : 'pcProcessContinue',
          ),
        );
        final rect = tester.getRect(button);
        final background = find.byKey(
          ValueKey(
            dialog is PCQuizRankingDialog
                ? 'pcQuizRankButtonBackground'
                : 'pcProcessButtonBackground',
          ),
        );
        // 粒子按钮的外部热区正确不代表内部背景撑满，必须核对实际绘制层。
        expect(
          tester.getSize(background),
          dialog is PCQuizRankingDialog
              ? const Size(268, 64)
              : const Size(264, 52),
        );
        expect(
          tester.getRect(background),
          rect,
          reason: '${dialog.runtimeType}按钮背景必须填满整个点击区域',
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 20));
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
