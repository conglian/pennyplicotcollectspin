import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> show(WidgetTester tester, PCAwardDialog dialog) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: dialog),
      ),
    );
    addTearDown(() async => tester.pumpWidget(const SizedBox()));
    expect(tester.takeException(), isNull);
  }

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

  for (final (type, artwork, amount, remaining) in [
    (PCQuizRewardType.diamond, 'pc_award_diamond', .69, 3.45),
    (PCQuizRewardType.gold, 'pc_award_gold', 2.75, 2.75),
    (PCQuizRewardType.gold, 'pc_award_gold', .02, -1.0),
  ]) {
    testWidgets('${type.name}获得框使用美元差额且保留真实奖品$amount', (tester) async {
      await show(
        tester,
        PCAwardDialog(
          award: amount,
          balance: 100,
          withdrawalTarget: 125,
          remainingCollectible: remaining,
          reward: PCQuizReward(
            id: 'copy-${type.name}-$remaining',
            type: type,
            amount: amount,
            questionIndex: 0,
          ),
        ),
      );
      expect(
        find.text('Only \$25 Left To Withdraw', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('\$100'), findsOneWidget);
      expect(find.text('×${PCQuizReward.format(amount)}'), findsNWidgets(2));
      expect(
        find.byWidgetPredicate((w) => w is PCImg && w.name == artwork),
        findsOneWidget,
      );
      expect(find.textContaining('Diamonds Left'), findsNothing);
      expect(find.textContaining('Gold Bricks Left'), findsNothing);
      expect(find.text('To Withdraw \$125'), findsNothing);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(768, 1024),
  ]) {
    for (final type in PCQuizRewardType.values) {
      testWidgets('${type.name}动态Only文案在$size内保持单行、金色渐变和按钮可见', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(
          tester,
          PCAwardDialog(
            award: .2,
            balance: 56.25,
            withdrawalTarget: 1200,
            remainingCollectible: 99,
            reward: PCQuizReward(
              id: 'layout-${type.name}',
              type: type,
              amount: .2,
              questionIndex: 0,
            ),
          ),
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
    }
  }
}
