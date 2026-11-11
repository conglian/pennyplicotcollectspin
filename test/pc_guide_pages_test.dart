import 'support/pc_number_test_assets.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide1Page.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide2Page.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide3Page.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCNewUserGuideFlow.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 小猪持续循环动画不会 settle；推进有限帧，等待布局、点击和本地保存完成。
Future<void> _pumpGuide(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2000));
  await tester.pump();
}

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
    for (var index = 1; index <= 3; index++) {
      testWidgets('引导$index在${size.width}×${size.height}下分层布局且按钮可点击', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        void next() => taps++;
        final page = switch (index) {
          1 => PCGuide1Page(onNext: next),
          2 => PCGuide2Page(onNext: next),
          _ => PCGuide3Page(onNext: next),
        };
        await tester.pumpWidget(MaterialApp(home: page));
        await _pumpGuide(tester);
        expect(tester.takeException(), isNull);

        final images = tester.widgetList<PCImg>(find.byType(PCImg)).toList();
        expect(
          images.where((image) => image.name == 'pc_guide_intro_bg'),
          hasLength(1),
        );
        expect(images.length, greaterThan(4));
        final button = find.byType(ParticleButton);
        final buttonBounds = tester.getRect(button);
        expect(buttonBounds.top, greaterThanOrEqualTo(0));
        expect(buttonBounds.bottom, lessThanOrEqualTo(size.height));

        await tester.tap(button);
        await _pumpGuide(tester);
        expect(taps, 1);
      });
    }
  }

  testWidgets('引导页面按控制器顺序切换，第三步只发送一次完成回调', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final controller = PCNewUserGuideController();
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PCNewUserGuideFlow(
          controller: controller,
          onCompleted: () => completions++,
        ),
      ),
    );
    await _pumpGuide(tester);
    expect(find.byType(PCGuide1Page), findsOneWidget);
    await tester.tap(find.byType(ParticleButton));
    await _pumpGuide(tester);
    expect(find.byType(PCGuide2Page), findsOneWidget);
    await tester.tap(find.byType(ParticleButton));
    await _pumpGuide(tester);
    expect(find.byType(PCGuide3Page), findsOneWidget);
    await tester.tap(find.byType(ParticleButton));
    await _pumpGuide(tester);
    expect(controller.isIntroComplete, isTrue);
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
