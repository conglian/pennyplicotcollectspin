import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_fake_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PCFakeAudio fake;
  setUp(() {
    SharedPreferences.setMockInitialValues({'pc_bg_music': false});
    fake = PCFakeAudio();
    PCAudioUtils.overrideForTesting(fake.audio);
  });
  tearDown(() async {
    await fake.audio.dispose();
    PCAudioUtils.overrideForTesting(null);
  });

  for (final reduced in [false, true]) {
    for (final type in PCQuizRewardType.values) {
      testWidgets(
        '${type.name} ${reduced ? '减少动画' : '正常动画'}收缩起点去背景但结束前继续拦截点击',
        (tester) async {
          tester.view.physicalSize = const Size(375, 812);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
          });
          var visible = true;
          var finished = 0;
          var underlyingTaps = 0;
          final pageBalance = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(375, 812),
                  disableAnimations: reduced,
                ),
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (_, rebuild) => Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => underlyingTaps++,
                          child: const ColoredBox(color: Colors.blue),
                        ),
                        Positioned(
                          left: 56,
                          top: 62,
                          child: SizedBox(
                            key: pageBalance,
                            width: 55,
                            height: 24,
                          ),
                        ),
                        if (visible)
                          Positioned.fill(
                            child: PCQuizRewardAnimation(
                              reward: PCQuizReward(
                                id: 'shrink-${type.name}',
                                type: type,
                                amount: 1,
                                questionIndex: 0,
                              ),
                              balance: 100,
                              targetKey: pageBalance,
                              onFinished: () {
                                finished++;
                                rebuild(() => visible = false);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final duration = reduced ? 300 : 1800;
          final shrinkAt = reduced ? 195 : 1170;
          final flightFrame = reduced ? 10 : 50;
          final cardFinder = find.byKey(
            const ValueKey('pcRewardCardBackground'),
          );
          Color? card() =>
              (tester.widget<DecoratedBox>(cardFinder).decoration
                      as BoxDecoration)
                  .color;

          var elapsed = 0;
          final flight = find.byType(Flow);
          if (reduced) {
            expect(flight, findsNothing);
          } else {
            elapsed = 1040;
            await tester.pump(Duration(milliseconds: elapsed));
            final pageCenter = tester.getCenter(find.byKey(pageBalance));
            final cardRect = tester.getRect(cardFinder);
            expect(cardRect.contains(pageCenter), isFalse);
            final sprites = find.descendant(
              of: flight,
              matching: find.byType(Image),
            );
            expect(
              sprites.evaluate().indexed.any((sprite) {
                final center = tester.getCenter(sprites.at(sprite.$1));
                return !cardRect.contains(center) &&
                    (center - pageCenter).distance < 22;
              }),
              isTrue,
              reason: '奖励图标应飞出卡片，抵达当前页面的余额',
            );
          }

          await tester.pump(Duration(milliseconds: shrinkAt - 1 - elapsed));
          expect(card()!.a, greaterThan(0));
          final startRect = tester.getRect(cardFinder);
          await tester.pump(const Duration(milliseconds: 1));
          expect(card(), Colors.transparent);
          expect(finished, 0);
          expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
          await tester.tapAt(const Offset(2, 2));
          expect(underlyingTaps, 0);

          await tester.pump(Duration(milliseconds: flightFrame));
          final flyingRect = tester.getRect(cardFinder);
          expect(flyingRect.height, lessThan(startRect.height));
          expect(flyingRect.center.dy, lessThan(startRect.center.dy));
          expect(card(), Colors.transparent);
          expect(finished, 0);
          await tester.tapAt(const Offset(2, 2));
          expect(underlyingTaps, 0);

          await tester.pump(
            Duration(milliseconds: duration - shrinkAt - flightFrame - 1),
          );
          expect(finished, 0);
          await tester.pump(const Duration(milliseconds: 17));
          expect(finished, 1);
          expect(find.byType(PCQuizRewardAnimation), findsNothing);
          await tester.tapAt(const Offset(2, 2));
          expect(underlyingTaps, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
