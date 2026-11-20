import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCBalanceHeader.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    PCAwardDialog dialog, {
    bool animate = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !animate),
          child: child!,
        ),
        home: Scaffold(body: dialog),
      ),
    );
    addTearDown(() async => tester.pumpWidget(const SizedBox()));
    expect(tester.takeException(), isNull);
  }

  testWidgets('光圈循环旋转，主图和按钮呼吸，点击框位置固定', (tester) async {
    await show(
      tester,
      const PCAwardDialog(
        award: 1,
        reward: PCQuizReward(
          id: 'motion',
          type: PCQuizRewardType.diamond,
          amount: 1,
          questionIndex: 0,
        ),
      ),
      animate: true,
    );
    await tester.pump();
    final rays = tester.widget<RotationTransition>(
      find.byKey(const ValueKey('pcCollectibleAwardRays')),
    );
    final artwork = find.byKey(const ValueKey('pcAwardArtwork'));
    final claim = find.byKey(const ValueKey('pcQuizClaimReward'));
    double scale(Finder finder) => tester
        .widget<Transform>(
          find.descendant(of: finder, matching: find.byType(Transform)).first,
        )
        .transform
        .storage[0];
    final hitRect = tester.getRect(claim);
    final restingScale = scale(artwork);
    final restingButtonScale = scale(claim);
    await tester.pump(const Duration(milliseconds: 550));
    expect(rays.turns.value, greaterThan(0));
    expect(scale(artwork), greaterThan(restingScale));
    expect(scale(claim), greaterThan(restingButtonScale));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(scale(artwork), lessThan(restingScale));
    expect(scale(claim), lessThan(restingButtonScale));
    expect(tester.getRect(claim), hitRect);
    await tester.pump(const Duration(seconds: 5));
    expect(rays.turns.value, closeTo(.65 / 6, .001));
  });

  for (final (balance, target, remaining) in [
    (56.0, 60.0, '4'),
    (56.0, 100.0, '44'),
    (56.25, 150.0, '93.75'),
    (99.8, 100.0, '0.2'),
    (106.0, 100.0, '0'),
  ]) {
    testWidgets('现金获得框余额$balance、门槛$target显示动态美元差额$remaining', (tester) async {
      await show(
        tester,
        PCAwardDialog(award: .2, balance: balance, withdrawalTarget: target),
      );
      expect(
        find.text('Only \$$remaining Left To Withdraw', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('\$${PCQuizReward.format(balance)}'), findsOneWidget);
      expect(find.text('+\$0.2'), findsNWidgets(2));
    });
  }

  testWidgets('未传余额的引导获得框顶部及Only差额均读取缓存美元', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_dollar_number': 56.25,
    });
    await PCLocalProvider.instance.init();
    await tester.pump(const Duration(milliseconds: 100));
    await show(tester, const PCAwardDialog(award: .2, withdrawalTarget: 80));
    expect(
      find.text('Only \$23.75 Left To Withdraw', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('\$56.25'), findsOneWidget);
  });

  for (final (type, artwork, amount, collected, target, main, secondary) in [
    (
      PCQuizRewardType.diamond,
      'pc_collectible_award_diamond',
      .69,
      3.45,
      20,
      'Collect',
      'Give Up',
    ),
    (
      PCQuizRewardType.gold,
      'pc_collectible_award_gold',
      2.75,
      2.75,
      10,
      'Claim Double',
      'Claim',
    ),
    (
      PCQuizRewardType.gold,
      'pc_collectible_award_gold',
      .02,
      16.0,
      10,
      'Claim Double',
      'Claim',
    ),
  ]) {
    testWidgets('${type.name} 原稿使用实时收集进度和实际奖励 $amount', (tester) async {
      await show(
        tester,
        PCAwardDialog(
          award: amount,
          balance: 100,
          withdrawalTarget: 125,
          collectibleCount: collected,
          reward: PCQuizReward(
            id: 'copy-${type.name}-$collected',
            type: type,
            amount: amount,
            questionIndex: 0,
          ),
        ),
      );
      expect(
        find.text('Just $target Diamonds To\nCash Out!', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Left To Withdraw'), findsNothing);
      final header = tester.widget<PCCollectibleBalanceHeader>(
        find.byType(PCCollectibleBalanceHeader),
      );
      expect(header.collected, collected);
      expect(header.withdrawalTarget, 125);
      expect(find.text('×${PCQuizReward.format(amount)}'), findsNWidgets(2));
      expect(find.text(main), findsNWidgets(2));
      expect(find.text(secondary), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is PCImg && w.name == artwork),
        findsOneWidget,
      );
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(768, 1024),
  ]) {
    testWidgets('美元 Only 文案在 $size 保持单行、金色渐变和按钮可见', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(
        tester,
        const PCAwardDialog(award: .2, balance: 56.25, withdrawalTarget: 1200),
      );
      final summary = find.text(
        'Only \$1143.75 Left To Withdraw',
        findRichText: true,
      );
      expect(summary, findsOneWidget);
      final text = tester.widget<RichText>(summary);
      expect(text.maxLines, 1);
      TextSpan? amount;
      text.text.visitChildren((span) {
        if (span is TextSpan && span.text == '\$1143.75') amount = span;
        return true;
      });
      expect(amount?.style?.foreground?.shader, isNotNull);
      expect(text.text.style?.fontSize, 20);
      expect(text.text.style?.height, 32 / 20);
      expect(find.text('\$56.25'), findsOneWidget);
      final rect = tester.getRect(summary);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      final claim = tester.getRect(
        find.byKey(const ValueKey('pcQuizClaimReward')),
      );
      expect(claim.bottom, lessThanOrEqualTo(size.height));
      expect(claim.height, greaterThanOrEqualTo(44));
    });

    for (final (type, secondaryKey) in [
      (PCQuizRewardType.diamond, 'pcQuizCloseReward'),
      (PCQuizRewardType.gold, 'pcAwardSingleClaim'),
    ]) {
      testWidgets('${type.name} 原稿在 $size 两个操作均可点击', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await show(
          tester,
          PCAwardDialog(
            award: .2,
            withdrawalTarget: 1200,
            reward: PCQuizReward(
              id: 'layout-${type.name}',
              type: type,
              amount: .2,
              questionIndex: 0,
            ),
          ),
        );
        final primary = tester.getRect(
          find.byKey(const ValueKey('pcQuizClaimReward')),
        );
        final secondary = tester.getRect(find.byKey(ValueKey(secondaryKey)));
        expect(primary.bottom, lessThanOrEqualTo(secondary.top));
        expect(secondary.bottom, lessThanOrEqualTo(size.height - 34));
        expect(primary.height, greaterThanOrEqualTo(44));
        expect(secondary.height, greaterThanOrEqualTo(44));
      });
    }
  }
}
