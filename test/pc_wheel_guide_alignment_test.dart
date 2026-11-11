import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCWheelGuideDialog.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';

void main() {
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
      final items = ['Earn', 'Quiz', 'Wheel', 'Cash']
          .map(
            (title) => PersistentBottomNavBarItem(
              icon: const PCImg(name: 'pc_wheel_n'),
              inactiveIcon: const PCImg(name: 'pc_wheel_s'),
              title: title,
              activeColorPrimary: Colors.transparent,
              inactiveColorPrimary: Colors.transparent,
            ),
          )
          .toList();
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
