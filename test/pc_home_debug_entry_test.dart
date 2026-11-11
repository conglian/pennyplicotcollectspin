import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCHomeDebugDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  testWidgets('首页Debug真实入口绝对设置余额与转盘次数，保存后立即刷新并可重新打开', (tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_bg_music': false,
      'pc_dollar_number': 10.0,
      'pc_pig_level': 0,
      'pc_pig_upgrade_seen_level_v1': 2,
    });
    final prefs = await SharedPreferences.getInstance();
    PigsTabController.currentIndex.value = 0;
    await PCNumberHelpers().pc_initNumberModel();
    await PCNewUserGuideController.instance.load();
    await PCLocalProvider.instance.init();
    final wheel = PCWheelController();
    await wheel.load();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(wheel.dispose);
    addTearDown(PCWithdrawalController.instance.dispose);

    Future<void> frames() async {
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    }

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: PCLocalProvider.instance,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const MaterialApp(home: PChome()),
        ),
      ),
    );
    await frames();
    await tester.tap(find.byKey(const ValueKey('pcHomeDebugButton')));
    await frames();
    expect(find.byType(PCHomeDebugDialog), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pcDebugCash')), '24.50');
    await tester.enterText(
      find.byKey(const ValueKey('pcDebugWheelChances')),
      '7',
    );
    await tester.tap(find.byKey(const ValueKey('pcDebugSubmit')));
    await frames();
    expect(find.byType(PCHomeDebugDialog), findsNothing);
    expect(prefs.getDouble('pc_dollar_number'), 24.5);
    expect(PCLocalProvider.instance.pc_dollar_number, 24.5);
    expect(PCLocalProvider.instance.pc_wheel_number, 7);
    expect(wheel.spins, 7);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);

    await tester.tap(find.byKey(const ValueKey('pcHomeDebugButton')));
    await frames();
    final dialog = tester.widget<PCHomeDebugDialog>(
      find.byType(PCHomeDebugDialog),
    );
    expect(dialog.cash, 24.5);
    expect(dialog.wheelChances, 7);
    await tester.tap(find.byKey(const ValueKey('pcDebugCancel')));
    await frames();
    await tester.pumpWidget(const SizedBox());
    await frames();
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });
}
