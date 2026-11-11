import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigMotion.dart';

void main() {
  testWidgets('主猪沿金猪升级的轻跳呼吸节奏运动，原位置仍可点击且卸载释放ticker', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 168,
            height: 140,
            child: PCPigMotion.hero(
              child: GestureDetector(
                onTap: () => taps++,
                child: const ColoredBox(
                  key: ValueKey('pig'),
                  color: Colors.pink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final pig = find.byKey(const ValueKey('pig'));
    final resting = tester.getRect(pig);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(pig), isNot(resting));
    await tester.tap(pig);
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('减少动画使主猪静止，运行中开关也立即停止并复位', (tester) async {
    var reduced = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, update) {
            rebuild = update;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const Center(
                child: SizedBox(
                  width: 168,
                  height: 140,
                  child: PCPigMotion.hero(
                    child: ColoredBox(key: ValueKey('pig'), color: Colors.pink),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final pig = find.byKey(const ValueKey('pig'));
    final resting = tester.getRect(pig);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getRect(pig), resting);
    rebuild(() => reduced = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(pig), isNot(resting));
    rebuild(() => reduced = true);
    await tester.pump();
    expect(tester.getRect(pig), resting);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getRect(pig), resting);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
