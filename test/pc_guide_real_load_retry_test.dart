import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCNewUserGuideFlow.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  Future<SharedPreferences> saved(
    int steps,
    String stage,
    double balance,
  ) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: steps,
      PCNewUserGuideController.flowKey: jsonEncode({'stage': stage}),
      PCNewUserGuideController.balanceKey: balance,
    });
    return SharedPreferences.getInstance();
  }

  test('真实控制器重建loading Future，旧读取晚返回不覆盖重试后已推进的存档', () async {
    final oldPrefs = await saved(0, 'welcome', 1);
    final currentPrefs = await saved(1, 'quiz', 42);
    final firstRead = Completer<SharedPreferences>();
    var reads = 0;
    final controller = PCNewUserGuideController(
      preferencesLoader: () => ++reads == 1
          ? firstRead.future
          : Future<SharedPreferences>.value(currentPrefs),
    );
    addTearDown(controller.dispose);
    final original = controller.load();
    expect(identical(original, controller.load()), isTrue);
    final retry = controller.retryLoad();
    expect(identical(original, retry), isFalse);
    await retry;
    expect(reads, 2);
    expect(controller.isLoaded, isTrue);
    expect(controller.completedSteps, 1);
    expect(controller.stage, PCNewUserStage.quiz);
    await controller.completeStep(PCNewUserGuideStep.guide2);
    expect(controller.completedSteps, 2);
    firstRead.complete(oldPrefs);
    await original;
    expect(controller.completedSteps, 2);
    expect(controller.stage, PCNewUserStage.quiz);
    expect(controller.balance, 42);
    expect(currentPrefs.getInt(PCNewUserGuideController.progressKey), 2);
    expect(oldPrefs.getInt(PCNewUserGuideController.progressKey), 0);
  });

  testWidgets('真实控制器在引导重试按钮点击后重新加载，恢复真实完成状态且不受旧读覆盖', (tester) async {
    final oldPrefs = await saved(0, 'welcome', 1);
    final currentPrefs = await saved(3, 'complete', 42);
    final firstRead = Completer<SharedPreferences>();
    var reads = 0, completions = 0;
    final controller = PCNewUserGuideController(
      preferencesLoader: () => ++reads == 1
          ? firstRead.future
          : Future<SharedPreferences>.value(currentPrefs),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PCNewUserGuideFlow(
          controller: controller,
          onCompleted: () => completions++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Tap to try again'), findsOneWidget);
    await tester.tap(find.text('Tap to try again'));
    await tester.pump();
    expect(reads, 2);
    expect(controller.isLoaded, isTrue);
    expect(controller.isIntroComplete, isTrue);
    expect(controller.isComplete, isTrue);
    expect(completions, 1);
    firstRead.complete(oldPrefs);
    await tester.pump();
    expect(controller.completedSteps, 3);
    expect(completions, 1);
    expect(controller.balance, 42);
    await tester.pumpWidget(const SizedBox());
  });
}
