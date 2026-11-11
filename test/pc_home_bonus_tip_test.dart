import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCHomeBonusTip.dart';

void main() {
  testWidgets('进入首页显示两秒，同页重建不续期', (tester) async {
    final controller = PCHomeBonusTipController();
    addTearDown(controller.dispose);
    expect(controller.visible, isFalse);

    controller.setActive(true);
    expect(controller.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    controller.setActive(true);
    await tester.pump(const Duration(milliseconds: 499));
    expect(controller.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.visible, isFalse);
    expect(controller.active, isTrue);
  });

  testWidgets('切离立即隐藏，切回重播且旧计时不能吞掉新提示', (tester) async {
    final controller = PCHomeBonusTipController();
    addTearDown(controller.dispose);
    controller.setActive(true);
    await tester.pump(const Duration(milliseconds: 1500));
    controller.setActive(false);
    expect(controller.visible, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    controller.setActive(true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 1599));
    expect(controller.visible, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.visible, isFalse);
  });

  testWidgets('显式激活从当前时刻计满两秒，释放后无回调', (tester) async {
    final controller = PCHomeBonusTipController();
    var updates = 0;
    controller.addListener(() => updates++);
    controller.activate();
    await tester.pump(const Duration(seconds: 1));
    controller.activate();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(controller.visible, isTrue);
    controller.dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(updates, 1);
  });

  testWidgets('显示本地文字、支持独立背板并不拦截底层点击', (tester) async {
    final controller = PCHomeBonusTipController();
    addTearDown(controller.dispose);
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox(
                    width: 200,
                    height: 48,
                    child: ColoredBox(color: Colors.green),
                  ),
                ),
                PCHomeBonusTip(
                  controller: controller,
                  background: const ColoredBox(
                    key: ValueKey('tip-background'),
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('tip-background')), findsNothing);
    controller.activate();
    await tester.pump();
    expect(find.byKey(const ValueKey('tip-background')), findsOneWidget);
    expect(
      find.text(
        'Activated: +3% bonus tomorrow,\n'
        "don't forget to come back!",
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('tip-background'))),
    );
    expect(taps, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('tip-background')), findsNothing);
  });
}
