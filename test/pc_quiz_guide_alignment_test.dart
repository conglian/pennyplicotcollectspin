import 'support/pc_number_test_assets.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuideQuizDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuizContentPanel.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  for (final size in const [
    Size(320, 568),
    Size(360, 780),
    Size(430, 932),
    Size(768, 1024),
  ]) {
    testWidgets('答题引导在 $size 下与实际题板、题目及答案对齐，点击不穿透', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final provider = PCLocalProvider.instance;
      await provider.init();
      bool? answer;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) => MaterialApp(
              home: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    PCQuiz(),
                    Align(
                      alignment: Alignment.topRight,
                      child: Builder(
                        builder: (context) => TextButton(
                          onPressed: () async {
                            await PCGuideQuizDialog.prepareForPresentation();
                            if (!context.mounted) return;
                            answer = await context.tipShow2(
                              const PCGuideQuizDialog(index: 2),
                              scaleContent: false,
                            );
                          },
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: const SizedBox(height: 81),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final original = find.byKey(pcQuizContentTargetKey);
      var originalBounds = tester.getRect(original);
      if (size.width < 600) {
        expect(
          originalBounds.bottom,
          lessThanOrEqualTo(size.height - 81 + .01),
        );
      } else {
        expect(originalBounds.bottom, greaterThan(size.height - 81));
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Open'));
      await tester.pump();
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      originalBounds = tester.getRect(original);
      expect(originalBounds.bottom, lessThanOrEqualTo(size.height - 81 + .01));
      final instructions = tester.getRect(
        find.byKey(const ValueKey('pcQuizGuideInstructions')),
      );
      expect(instructions.top, greaterThanOrEqualTo(7.99));
      expect(instructions.bottom, lessThanOrEqualTo(originalBounds.top - 11.9));
      final guide = find.byKey(const ValueKey('pcQuizGuidePanel'));

      void expectAligned() {
        final highlighted = tester.getRect(guide);
        expect(highlighted.left, closeTo(originalBounds.left, .01));
        expect(highlighted.top, closeTo(originalBounds.top, .01));
        expect(highlighted.width, closeTo(originalBounds.width, .01));
        expect(highlighted.height, closeTo(originalBounds.height, .01));
        for (final key in [
          'pcQuizQuestion',
          'pcQuizAnswerA',
          'pcQuizAnswerB',
        ]) {
          final target = tester.getRect(
            find.descendant(of: guide, matching: find.byKey(ValueKey(key))),
          );
          expect(target.left, greaterThanOrEqualTo(originalBounds.left));
          expect(target.top, greaterThanOrEqualTo(originalBounds.top));
          expect(target.right, lessThanOrEqualTo(originalBounds.right));
          expect(target.bottom, lessThanOrEqualTo(originalBounds.bottom));
        }
      }

      // 入场时也不再缩放题板，避免短暂出现双层边框。
      expectAligned();
      await tester.pump(const Duration(milliseconds: 300));
      expectAligned();
      expect(tester.takeException(), isNull);
      final count = provider.pc_quiz_all_num;
      await tester.tap(
        find.descendant(
          of: guide,
          matching: find.byKey(const ValueKey('pcQuizAnswerB')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(answer, isNull);
      expect(find.byKey(const ValueKey('pcQuizWrong')), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: guide,
          matching: find.byKey(const ValueKey('pcQuizAnswerA')),
        ),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(answer, false);
      expect(provider.pc_quiz_all_num, count);
      answer = null;
      await tester.tap(find.text('Open'));
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.descendant(
          of: guide,
          matching: find.byKey(const ValueKey('pcQuizAnswerA')),
        ),
      );
      await tester.tap(
        find.descendant(
          of: guide,
          matching: find.byKey(const ValueKey('pcQuizAnswerB')),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(answer, isNull);
      expect(find.byKey(const ValueKey('pcQuizCorrect')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(answer, true);
      expect(provider.pc_quiz_all_num, count);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
