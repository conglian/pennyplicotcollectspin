import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizRewardAnimation.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
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
          Color backdrop() => tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('pcRewardBackdrop')),
              )
              .color;
          Color? card() =>
              (tester
                          .widget<DecoratedBox>(
                            find.byKey(
                              const ValueKey('pcRewardCardBackground'),
                            ),
                          )
                          .decoration
                      as BoxDecoration)
                  .color;

          await tester.pump(Duration(milliseconds: shrinkAt - 1));
          expect(backdrop(), pcDialogBackdrop);
          expect(card()!.a, greaterThan(0));
          final startRect = tester.getRect(
            find.byKey(const ValueKey('pcRewardCardBackground')),
          );
          await tester.pump(const Duration(milliseconds: 1));
          expect(backdrop(), Colors.transparent);
          expect(card(), Colors.transparent);
          expect(finished, 0);
          expect(find.byType(PCQuizRewardAnimation), findsOneWidget);
          await tester.tapAt(const Offset(2, 2));
          expect(underlyingTaps, 0);

          await tester.pump(Duration(milliseconds: flightFrame));
          final flyingRect = tester.getRect(
            find.byKey(const ValueKey('pcRewardCardBackground')),
          );
          expect(flyingRect.height, lessThan(startRect.height));
          expect(flyingRect.center.dy, lessThan(startRect.center.dy));
          expect(backdrop(), Colors.transparent);
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
