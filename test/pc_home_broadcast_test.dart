import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCRankData.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  testWidgets('首页轮播仅显示脱敏账号及本地提现档位，排行榜保留明文', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_dollar_number': 20.0,
      PCNumberHelpers.configKey: '{"eq_range":[50,80,130]}',
    });
    final provider = PCLocalProvider.instance;
    await provider.init();
    final numbers = PCNumberHelpers();
    expect(numbers.pc_eqRange, [50, 80, 130]);
    expect(numbers.pc_homeBroadcastAmounts, [100, 120, 150, 200]);
    final ranking = await PCUserDataManager.getPCUserData();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => const MaterialApp(home: PChome()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(ranking[3].username), findsOneWidget);
    final messagePattern = RegExp(
      r'^Congrats! User \d{2}\*{3}\d{2} just cashed out \$(100|120|150|200)!$',
    );
    final messages = find.textContaining('just cashed out', findRichText: true);
    for (var cycle = 0; cycle < 4; cycle++) {
      final rendered = tester.widgetList<RichText>(messages).toList();
      expect(rendered, hasLength(2)); // 正文和描边共用同一条文案。
      for (final line in rendered) {
        expect(line.text.toPlainText(), matches(messagePattern));
      }
      await tester.pump(const Duration(seconds: 7));
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
