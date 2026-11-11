import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizBanner.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBannerController.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('无操作不触发，仅按答题次数显示；展示结束不会定时重弹，下一轮继续轮换文案', (tester) async {
    final flow = PCQuizBannerController(
      answerThreshold: () => 2,
      withdrawalTarget: () => 120,
    );
    addTearDown(flow.dispose);
    await flow.load();
    flow.setActive(true);
    await tester.pump(const Duration(minutes: 1));
    expect(flow.pendingMessage, isNull);
    flow.recordAnswer(questionIndex: 0, correct: false);
    await tester.pump(const Duration(seconds: 30));
    expect(flow.pendingMessage, isNull);
    flow.recordAnswer(questionIndex: 1, correct: false);
    await tester.pump(const Duration(milliseconds: 999));
    expect(flow.pendingMessage, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      flow.pendingMessage,
      'Keep Answering! Today Super Easy Cash Out \$120',
    );
    flow.beginPresentation();
    await tester.pump(const Duration(seconds: 15));
    expect(flow.pendingMessage, isNull);
    flow.finishPresentation();
    await tester.pump(const Duration(minutes: 1));
    expect(flow.pendingMessage, isNull);
    flow.recordAnswer(questionIndex: 2, correct: false);
    flow.recordAnswer(questionIndex: 3, correct: false);
    await tester.pump(const Duration(milliseconds: 999));
    expect(flow.pendingMessage, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      flow.pendingMessage,
      'Keep Going! \$120 Is Within Reach — One Question Away',
    );
    flow.beginPresentation();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt(PCQuizBannerController.cursorKey), 2);
  });

  for (final alreadyPending in [false, true]) {
    testWidgets('离开页面取消旧横幅（已触发：$alreadyPending），回来必须重新答题才可触发', (tester) async {
      final flow = PCQuizBannerController(answerThreshold: () => 2);
      addTearDown(flow.dispose);
      await flow.load();
      flow.setActive(true);
      flow.recordAnswer(questionIndex: 0, correct: false);
      flow.recordAnswer(questionIndex: 1, correct: false);
      await tester.pump(Duration(milliseconds: alreadyPending ? 1000 : 700));
      expect(flow.pendingMessage, alreadyPending ? isNotNull : isNull);
      flow.cancelPending();
      flow.setActive(false);
      await tester.pump(const Duration(seconds: 20));
      flow.setActive(true);
      await tester.pump(const Duration(minutes: 1));
      expect(flow.pendingMessage, isNull);
      flow.recordAnswer(questionIndex: 2, correct: false);
      await tester.pump(const Duration(seconds: 20));
      expect(flow.pendingMessage, isNull);
      flow.recordAnswer(questionIndex: 3, correct: false);
      await tester.pump(const Duration(seconds: 1));
      expect(flow.pendingMessage, isNotNull);
    });
  }

  testWidgets('达到配置答题次数，正确题等待领奖结束并满1秒；重复题号不计数', (tester) async {
    final flow = PCQuizBannerController(answerThreshold: () => 3);
    addTearDown(flow.dispose);
    await flow.load();
    flow.setActive(false);
    flow.recordAnswer(questionIndex: 0, correct: false);
    flow.recordAnswer(questionIndex: 0, correct: false);
    flow.recordAnswer(questionIndex: 1, correct: false);
    flow.setActive(true);
    await tester.pump(const Duration(seconds: 1));
    expect(flow.pendingMessage, isNull, reason: '同一题不能重复累计次数');
    flow.setActive(false);
    flow.recordAnswer(questionIndex: 2, correct: true);
    await tester.pump(const Duration(seconds: 20));
    expect(flow.pendingMessage, isNull);
    flow.rewardFinished();
    flow.setActive(true);
    await tester.pump(const Duration(milliseconds: 999));
    expect(flow.pendingMessage, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(flow.pendingMessage, isNotNull);
  });

  testWidgets('等待其他弹窗时暂停达标横幅，恢复后重新等1秒且不重复排队', (tester) async {
    final flow = PCQuizBannerController(answerThreshold: () => 1);
    addTearDown(flow.dispose);
    await flow.load();
    flow.recordAnswer(questionIndex: 0, correct: false);
    flow.setActive(true);
    await tester.pump(const Duration(milliseconds: 700));
    flow.setActive(false);
    await tester.pump(const Duration(seconds: 10));
    expect(flow.pendingMessage, isNull);
    flow.setActive(true);
    await tester.pump(const Duration(milliseconds: 999));
    expect(flow.pendingMessage, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    final pending = flow.pendingMessage;
    expect(pending, isNotNull);
    await tester.pump(const Duration(seconds: 10));
    expect(flow.pendingMessage, pending, reason: '只保留一个横幅请求');
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('答题横幅在 $width 宽从右屏外进入，停留后原路滑出才移除', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dismissed = <String>[];
      var backgroundTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => backgroundTaps++,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned.fill(
                  child: PCQuizBanner(
                    message: 'Keep Answering! Today Super Easy Cash Out \$120',
                    withdrawalTarget: 120,
                    onDismissed: dismissed.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
      final barrier = find.byKey(const ValueKey('pcQuizProcessBarrier'));
      expect(
        tester.widget<ModalBarrier>(barrier).color,
        Colors.black.withValues(alpha: .9),
      );
      expect(tester.getSize(banner).width, closeTo(width, .01));
      expect(tester.getSize(banner).height, closeTo(width * 332 / 360, .01));
      await tester.tapAt(const Offset(10, 10));
      expect(backgroundTaps, 0, reason: '入场时背景即被遮罩拦截');
      expect(tester.getTopLeft(banner).dx, greaterThanOrEqualTo(width));
      await tester.pump(const Duration(milliseconds: 175));
      final entryX = tester.getTopLeft(banner).dx;
      expect(entryX, inExclusiveRange(0, width), reason: 'entry midpoint');
      await tester.pump(const Duration(milliseconds: 175));
      expect(tester.getTopLeft(banner).dx, closeTo(0, .01));
      expect(tester.getCenter(banner).dy, closeTo(350, .01));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1999));
      expect(tester.getTopLeft(banner).dx, closeTo(0, .01));
      expect(dismissed, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 175));
      final exitX = tester.getTopLeft(banner).dx;
      expect(exitX, inExclusiveRange(0, width), reason: 'exit midpoint');
      expect(dismissed, isEmpty, reason: '退场中仍保留内容及展示权');
      await tester.tapAt(const Offset(10, 10));
      expect(backgroundTaps, 0, reason: '退场中仍拦截背景');
      await tester.pump(const Duration(milliseconds: 176));
      await tester.pump();
      expect(banner, findsNothing);
      expect(barrier, findsNothing);
      await tester.tapAt(const Offset(10, 10));
      expect(backgroundTaps, 1, reason: '完全退出后恢复页面点击');
      expect(dismissed, ['Keep Answering! Today Super Easy Cash Out \$120']);
      await tester.pump(const Duration(seconds: 3));
      expect(dismissed, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('提前收起仍沿右侧退出；覆盖期间立即隐藏，结束后不恢复旧横幅', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final message = ValueNotifier<String?>('Next to cash out!');
    final suppressed = ValueNotifier<bool>(false);
    final dismissed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([message, suppressed]),
            builder: (_, child) => Stack(
              children: [
                Positioned.fill(
                  child: PCQuizBanner(
                    message: message.value,
                    withdrawalTarget: 120,
                    suppressed: suppressed.value,
                    onDismissed: dismissed.add,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.getTopLeft(banner).dx, closeTo(0, .01));
    message.value = null;
    await tester.pump();
    expect(banner, findsOneWidget);
    expect(dismissed, isEmpty);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(banner).dx, greaterThan(0));
    suppressed.value = true;
    await tester.pump();
    expect(banner, findsNothing, reason: '全屏弹窗、离开页面或后台不展示旧横幅');
    await tester.pump(const Duration(milliseconds: 300));
    suppressed.value = false;
    await tester.pump();
    expect(banner, findsNothing);
    expect(dismissed, ['Next to cash out!']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    message.dispose();
    suppressed.dispose();
  });

  testWidgets('减少动画时保留两秒停留和单次结束回调', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dismissed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PCQuizBanner(
              message: 'Ready!',
              withdrawalTarget: 100,
              onDismissed: dismissed.add,
            ),
          ),
        ),
      ),
    );
    final banner = find.byKey(const ValueKey('pcQuizProcessBanner'));
    expect(tester.getTopLeft(banner).dx, 0);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(banner, findsOneWidget);
    expect(dismissed, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(banner, findsNothing);
    expect(dismissed, ['Ready!']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Overlay首次构建前被取消的空横幅仍单次归还展示权', (tester) async {
    final coordinator = PCDialogCoordinator();
    final release = coordinator.holdPresentation();
    final dismissed = <String>[];
    Widget build() => MaterialApp(
      home: Scaffold(
        body: PCQuizBanner(
          initialMessage: 'Queued banner',
          message: null,
          withdrawalTarget: 100,
          onDismissed: (message) {
            dismissed.add(message);
            release();
          },
        ),
      ),
    );
    await tester.pumpWidget(build());
    await tester.pump();
    expect(find.byKey(const ValueKey('pcQuizProcessBarrier')), findsNothing);
    expect(dismissed, ['Queued banner']);
    expect(coordinator.isBusy, false);
    await tester.pumpWidget(build());
    await tester.pump(const Duration(seconds: 5));
    expect(dismissed, ['Queued banner'], reason: '空横幅重建不能重复结算');
    await tester.pumpWidget(const SizedBox());
    coordinator.dispose();
    expect(tester.takeException(), isNull);
  });
}
