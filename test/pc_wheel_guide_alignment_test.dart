import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCWheelGuideDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCAdaptiveLayout.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';

void main() {
  testWidgets('导航切换时高清图连续缩放，反向点击从当前位置接续', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [320.0, 430.0, 768.0]) {
      tester.view.physicalSize = Size(width, 900);
      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(width),
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) => CustomNavBarWidget(
                [
                  pcNavBarItem('pc_earn', 'Earn'),
                  pcNavBarItem('pc_quiz', 'Quiz', unselectedMaxSize: 83),
                  pcNavBarItem('pc_wheel', 'Wheel'),
                  pcNavBarItem('pc_cash', 'Cash'),
                ],
                selectedIndex: selectedIndex,
                onItemSelected: (index) =>
                    setState(() => selectedIndex = index),
              ),
            ),
          ),
        ),
      );
      Finder tabIcon(int index) => find.descendant(
        of: find.byType(PCNavBarItemView).at(index),
        matching: find.byType(Image),
      );
      final earnIcon = tabIcon(0);
      final cashIcon = tabIcon(3);
      final initialEarn = tester.getRect(earnIcon);
      final initialCash = tester.getRect(cashIcon);
      final asset = tester.widget<Image>(cashIcon).image as AssetImage;
      expect(asset.assetName, endsWith('pc_cash_selected_hd.png'));
      expect(initialCash.width, closeTo(44, .01));
      expect(
        initialEarn.width,
        closeTo(78.125 * PCAdaptiveLayout.navigationScale(width), .01),
      );

      await tester.tap(cashIcon);
      await tester.pump();
      expect(tester.getRect(earnIcon), initialEarn);
      expect(tester.getRect(cashIcon), initialCash);
      expect(tester.widget<Image>(cashIcon).image, asset);

      await tester.pump(const Duration(milliseconds: 110));
      final shrinking = tester.getRect(earnIcon);
      final growing = tester.getRect(cashIcon);
      expect(
        shrinking.width,
        inExclusiveRange(initialCash.width, initialEarn.width),
      );
      expect(
        growing.width,
        inExclusiveRange(initialCash.width, initialEarn.width),
      );
      expect(
        shrinking.width + growing.width,
        closeTo(initialEarn.width + initialCash.width, .01),
      );

      await tester.tap(earnIcon);
      await tester.pump();
      expect(tester.getRect(earnIcon), shrinking);
      expect(tester.getRect(cashIcon), growing);
      await tester.pumpAndSettle();
      expect(tester.getRect(earnIcon), initialEarn);
      expect(tester.getRect(cashIcon), initialCash);

      await tester.tap(cashIcon);
      await tester.pumpAndSettle();
      expect(tester.getRect(cashIcon).width, closeTo(initialEarn.width, .01));
      expect(tester.getRect(earnIcon).width, closeTo(initialCash.width, .01));
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 780),
    const Size(430, 932),
  ]) {
    testWidgets('转盘引导高亮与实际导航按钮在 $size 下完全对齐', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PigsTabController.currentIndex.value = 0;
      final items = [
        'Earn',
        'Quiz',
        'Wheel',
        'Cash',
      ].map((title) => pcNavBarItem('pc_wheel', title)).toList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.tipShow2(const PCWheelGuideDialog()),
                child: const Text('Open'),
              ),
            ),
            bottomNavigationBar: CustomNavBarWidget(
              items,
              selectedIndex: 0,
              onItemSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      final actual = tester.getRect(find.byKey(pcWheelNavigationTargetKey));
      final highlighted = tester.getRect(
        find.byKey(const ValueKey('pcWheelGuideTarget')),
      );
      expect(highlighted.left, closeTo(actual.left, .01));
      expect(highlighted.top, closeTo(actual.top, .01));
      expect(highlighted.size, actual.size);
      expect(highlighted.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('pcWheelGuideTarget')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
