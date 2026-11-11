import 'support/pc_number_test_assets.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首次进入引导1，保存后冷启动恢复引导2，再恢复引导3', () async {
    final first = PCNewUserGuideController();
    await first.load();
    expect(first.currentStep, PCNewUserGuideStep.guide1);
    await first.completeStep(PCNewUserGuideStep.guide1);
    first.dispose();

    final second = PCNewUserGuideController();
    await second.load();
    expect(second.currentStep, PCNewUserGuideStep.guide2);
    await second.completeStep(PCNewUserGuideStep.guide2);
    second.dispose();

    final third = PCNewUserGuideController();
    await third.load();
    expect(third.currentStep, PCNewUserGuideStep.guide3);
    await third.completeStep(PCNewUserGuideStep.guide3);
    third.dispose();

    final completed = PCNewUserGuideController();
    await completed.load();
    expect(completed.isIntroComplete, isTrue);
    expect(completed.currentStep, PCNewUserGuideStep.afterIntro);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('pc_new_guide_end'), isNull);
    completed.dispose();
  });

  test('连续点击和旧页面回调不会跳过中间步骤', () async {
    final controller = PCNewUserGuideController();
    await controller.load();
    await Future.wait([
      controller.completeStep(PCNewUserGuideStep.guide1),
      controller.completeStep(PCNewUserGuideStep.guide1),
    ]);
    expect(controller.currentStep, PCNewUserGuideStep.guide2);
    await controller.completeStep(PCNewUserGuideStep.guide1);
    await controller.completeStep(PCNewUserGuideStep.guide3);
    expect(controller.currentStep, PCNewUserGuideStep.guide2);
    expect(controller.completedSteps, 1);
    controller.dispose();
  });

  test('超出当前版本范围的进度从第一步恢复，不误判全部完成', () async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 99,
    });
    final controller = PCNewUserGuideController();
    await controller.load();
    expect(controller.currentStep, PCNewUserGuideStep.guide1);
    expect(controller.isIntroComplete, isFalse);
    controller.dispose();
  });
}
