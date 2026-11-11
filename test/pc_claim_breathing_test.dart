import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCCheckInDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizContentPanel.dart';
import 'package:pennypilotcollectspin/PCTool/PCBreathing.dart';
import 'package:pennypilotcollectspin/PCTool/PCNoticeMessage.dart';
import 'package:pennypilotcollectspin/PCTool/PCNotificationCard.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';

void main() {
  var cleanupRegistered = false;
  setUp(() => cleanupRegistered = false);

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool reduced = false,
    bool tickers = true,
  }) async {
    if (!cleanupRegistered) {
      cleanupRegistered = true;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
              enabled: tickers,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  Widget button({
    required VoidCallback onTap,
    bool enabled = true,
    bool breathing = true,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        key: const ValueKey('claimHitBox'),
        width: 200,
        height: 60,
        child: ParticleButton(
          enabled: enabled,
          breathing: breathing,
          onTap: onTap,
          child: const ColoredBox(
            key: ValueKey('claimVisual'),
            color: Colors.green,
            child: Center(child: Text('Claim')),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const SizedBox(key: ValueKey('layoutBelowClaim'), width: 200, height: 20),
    ],
  );

  double scale(WidgetTester tester, [Finder? scope]) => tester
      .widget<Transform>(
        find.descendant(
          of: scope ?? find.byType(PCBreathing),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .storage[0];

  Offset offset(WidgetTester tester, [Finder? scope]) {
    final matrix = tester
        .widget<Transform>(
          find.descendant(
            of: scope ?? find.byType(PCBreathing),
            matching: find.byType(Transform),
          ),
        )
        .transform;
    return Offset(matrix.storage[12], matrix.storage[13]);
  }

  Rect visualRect(WidgetTester tester) {
    final box = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('claimVisual')),
    );
    return Rect.fromPoints(
      box.localToGlobal(Offset.zero),
      box.localToGlobal(box.size.bottomRight(Offset.zero)),
    );
  }

  testWidgets('Claim围绕中心0.94至1.06纯缩放，布局和原点击框不变，边缘连按不会漏点击', (tester) async {
    var calls = 0;
    await mount(tester, button(onTap: () => calls++));
    final hitBox = find.byKey(const ValueKey('claimHitBox'));
    final below = find.byKey(const ValueKey('layoutBelowClaim'));
    final originalHitBox = tester.getRect(hitBox);
    final originalBelow = tester.getRect(below);
    expect(scale(tester), 1);
    expect(offset(tester), Offset.zero);
    expect(visualRect(tester), originalHitBox);

    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester), closeTo(1.06, .000001));
    expect(offset(tester), Offset.zero);
    expect(tester.getRect(hitBox), originalHitBox);
    expect(
      tester.getSize(find.byKey(const ValueKey('claimVisual'))),
      const Size(200, 60),
    );
    expect(tester.getRect(below), originalBelow);
    final grown = visualRect(tester);
    expect(grown.width, closeTo(originalHitBox.width * 1.06, .000001));
    expect(grown.height, closeTo(originalHitBox.height * 1.06, .000001));
    expect(grown.center.dx, closeTo(originalHitBox.center.dx, .000001));
    expect(grown.center.dy, closeTo(originalHitBox.center.dy, .000001));
    final outside = Offset(
      originalHitBox.left - 2,
      originalHitBox.center.dy - 2,
    );
    expect(originalHitBox.contains(outside), isFalse);
    expect(grown.contains(outside), isTrue);
    await tester.tapAt(outside);
    expect(calls, 0); // 视觉超出原框的部分不扩大点击范围。
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester), closeTo(1, .000001));
    expect(offset(tester), Offset.zero);
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester), closeTo(.94, .000001));
    expect(offset(tester), Offset.zero);
    final shrunk = visualRect(tester);
    expect(shrunk.width, closeTo(originalHitBox.width * .94, .000001));
    expect(shrunk.height, closeTo(originalHitBox.height * .94, .000001));
    expect(shrunk.center.dx, closeTo(originalHitBox.center.dx, .000001));
    expect(shrunk.center.dy, closeTo(originalHitBox.center.dy, .000001));
    final edges = [
      Offset(originalHitBox.left + .1, originalHitBox.center.dy),
      Offset(originalHitBox.right - .1, originalHitBox.center.dy),
      Offset(originalHitBox.center.dx, originalHitBox.top + .1),
      Offset(originalHitBox.center.dx, originalHitBox.bottom - .1),
    ];
    for (final point in edges) {
      expect(shrunk.contains(point), isFalse);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(calls, 4);
    for (var i = 0; i < 8; i++) {
      await tester.tapAt(originalHitBox.center);
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(calls, 12);
    await tester.pump(const Duration(milliseconds: 310));
    expect(scale(tester), closeTo(1, .000001));
    expect(offset(tester), Offset.zero);
    expect(tester.getRect(hitBox), originalHitBox);
    expect(tester.getRect(below), originalBelow);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Claim禁用仍不可点击，停止呼吸并恢复原尺寸，重新启用后可继续点击', (tester) async {
    var calls = 0;
    void onTap() => calls++;
    await mount(tester, button(onTap: onTap));
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester), greaterThan(1));
    expect(offset(tester), Offset.zero);
    await mount(tester, button(onTap: onTap, enabled: false));
    expect(scale(tester), 1);
    expect(offset(tester), Offset.zero);
    await tester.pump(const Duration(seconds: 2));
    expect(scale(tester), 1);
    expect(offset(tester), Offset.zero);
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('claimHitBox'))),
    );
    await tester.pump();
    expect(calls, 0);
    expect(tester.hasRunningAnimations, isFalse);
    await mount(tester, button(onTap: onTap));
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester), greaterThan(1));
    expect(offset(tester), Offset.zero);
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('claimHitBox'))),
    );
    expect(calls, 1);
  });

  for (final reduced in [true, false]) {
    testWidgets('${reduced ? '减少动画' : 'TickerMode关闭'}保持静态、可点击，恢复后继续呼吸', (
      tester,
    ) async {
      var calls = 0;
      void onTap() => calls++;
      await mount(tester, button(onTap: onTap));
      await tester.pump(const Duration(milliseconds: 550));
      expect(scale(tester), greaterThan(1));
      expect(offset(tester), Offset.zero);
      await mount(
        tester,
        button(onTap: onTap),
        reduced: reduced,
        tickers: reduced,
      );
      expect(scale(tester), 1);
      expect(offset(tester), Offset.zero);
      await tester.pump(const Duration(seconds: 3));
      expect(scale(tester), 1);
      expect(offset(tester), Offset.zero);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('claimHitBox'))),
      );
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 600));
      await mount(tester, button(onTap: onTap));
      await tester.pump(const Duration(milliseconds: 550));
      expect(scale(tester), greaterThan(1));
      expect(offset(tester), Offset.zero);
    });
  }

  testWidgets('ParticleButton默认不启用呼吸，不改变其它按钮动画或点击', (tester) async {
    var calls = 0;
    await mount(
      tester,
      ParticleButton(
        onTap: () => calls++,
        child: const SizedBox(width: 200, height: 60, child: Text('Ordinary')),
      ),
    );
    expect(find.byType(PCBreathing), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.text('Ordinary'));
    expect(calls, 1);
  });

  testWidgets('获得框Claim启用呼吸，领奖在途停止呼吸且不重复提交，失败后恢复', (tester) async {
    final pending = Completer<bool>();
    var claims = 0;
    await mount(
      tester,
      PCAwardDialog(
        award: 1,
        balance: 20,
        adsEnabled: false,
        onClaim: () {
          claims++;
          return pending.future;
        },
      ),
    );
    final claim = find.byKey(const ValueKey('pcQuizClaimReward'));
    expect(tester.widget<ParticleButton>(claim).breathing, isTrue);
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester, claim), greaterThan(1));
    expect(offset(tester, claim), Offset.zero);
    await tester.tap(claim);
    await tester.pump();
    expect(claims, 1);
    expect(tester.widget<ParticleButton>(claim).breathing, isFalse);
    await tester.tapAt(tester.getCenter(claim));
    await tester.pump();
    expect(claims, 1);
    pending.complete(false);
    await tester.pump();
    expect(tester.widget<ParticleButton>(claim).breathing, isTrue);
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester, claim), greaterThan(1));
    expect(offset(tester, claim), Offset.zero);
  });

  testWidgets('签到可领取时CLAIM有呼吸，已领取时禁用且无呼吸', (tester) async {
    const rewards = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0];
    await mount(tester, const PCCheckInDialog(rewards: rewards));
    final claim = find.widgetWithText(ParticleButton, 'CLAIM \$1.00 NOW');
    expect(tester.widget<ParticleButton>(claim).breathing, isTrue);
    await tester.pump(const Duration(milliseconds: 550));
    expect(scale(tester, claim), greaterThan(1));
    expect(offset(tester, claim), Offset.zero);
    await mount(
      tester,
      const PCCheckInDialog(rewards: rewards, canClaim: false),
    );
    final unavailable = find.widgetWithText(
      ParticleButton,
      'COME BACK TOMORROW',
    );
    expect(tester.widget<ParticleButton>(unavailable).enabled, isFalse);
    expect(tester.widget<ParticleButton>(unavailable).breathing, isFalse);
    expect(find.byType(PCBreathing), findsNothing);
  });

  testWidgets('通知仅非compact的goal Claim呼吸，账户及compact Withdraw保持原状', (
    tester,
  ) async {
    for (final (kind, compact, breathing) in [
      (PCNoticeKind.goal, false, true),
      (PCNoticeKind.goal, true, false),
      (PCNoticeKind.account, false, false),
    ]) {
      await mount(
        tester,
        SizedBox(
          width: 328,
          child: PCNotificationCard(
            message: PCNoticeMessage(kind: kind, balance: 20, target: 100),
            compact: compact,
            onAction: () {},
          ),
        ),
      );
      final claim = find.byKey(const ValueKey('pcNoticeAction'));
      expect(tester.widget<ParticleButton>(claim).breathing, breathing);
      if (breathing) {
        await tester.pump(const Duration(milliseconds: 550));
        expect(scale(tester, claim), greaterThan(1));
        expect(offset(tester, claim), Offset.zero);
      } else {
        expect(find.byType(PCBreathing), findsNothing);
      }
    }
  });

  testWidgets('答题恢复按钮仅Claim文案呼吸，点击仍调用原回调', (tester) async {
    var claims = 0;
    for (final label in ['Claim Reward', 'Continue']) {
      await mount(
        tester,
        SizedBox(
          width: PCQuizContentPanel.designWidth,
          height: PCQuizContentPanel.designHeight,
          child: PCQuizContentPanel(
            question: 'Question',
            optionA: 'A',
            optionB: 'B',
            hintAnswer: null,
            resumeLabel: label,
            onResumeReward: () => claims++,
          ),
        ),
      );
      final claim = find.byKey(const ValueKey('pcQuizResumeReward'));
      expect(
        tester.widget<ParticleButton>(claim).breathing,
        label.contains('Claim'),
      );
      if (label.contains('Claim')) {
        await tester.pump(const Duration(milliseconds: 550));
        expect(scale(tester, claim), greaterThan(1));
        expect(offset(tester, claim), Offset.zero);
      } else {
        expect(find.byType(PCBreathing), findsNothing);
      }
      await tester.tap(claim);
    }
    expect(claims, 2);
  });
}
