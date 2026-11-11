import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigBarrage.dart';
import 'package:pennypilotcollectspin/PCTool/PCRankData.dart';
import 'package:pennypilotcollectspin/PCTool/pc_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

const _user = PCUserData(
  id: 1,
  username: 'User ****1234 (Brazil)',
  totalEarning: 0.01,
  adsWatched: 2,
);

Widget _app({bool animate = false}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: !animate),
        child: SizedBox(
          width: 360,
          height: 120,
          child: PCPigBarrage(users: const [_user]),
        ),
      ),
    ),
  ),
);

List<String> _rowAmounts(WidgetTester tester, int row) => tester
    .widgetList<PCText>(
      find.descendant(
        of: find.byKey(ValueKey('pcPigBarrageTrack$row')),
        matching: find.byType(PCText),
      ),
    )
    .map((text) => text.text)
    .where((text) => text.startsWith(r'$'))
    .toList();

void _expectPayoutAmounts(WidgetTester tester, List<int> payoutAmounts) {
  final allowed = payoutAmounts
      .map((amount) => '\$${amount.toStringAsFixed(2)}')
      .toSet();
  for (var row = 0; row < 3; row++) {
    final amounts = _rowAmounts(tester, row);
    expect(amounts, hasLength(8));
    expect(amounts.every(allowed.contains), isTrue);
    expect(amounts.take(4), amounts.skip(4));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  testWidgets('三行弹幕金额只取本地提现四档，低收益用户不截断金额', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    _expectPayoutAmounts(tester, [100, 120, 150, 200]);
    expect(find.text(r'$0.01'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('有效远程提现配置覆盖本地四档，打开时读取当前生效配置', (tester) async {
    const remote = [310, 420, 530, 640];
    await PCNumberHelpers().pc_applyRemoteConfig(
      jsonEncode({'eq_range': remote}),
    );
    await tester.pumpWidget(_app());
    await tester.pump();

    _expectPayoutAmounts(tester, remote);
    expect(find.text(r'$100.00'), findsNothing);
    expect(find.text(r'$120.00'), findsNothing);
    expect(find.text(r'$150.00'), findsNothing);
    expect(find.text(r'$200.00'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('平移和父层重建不重新抽取金额，下次打开才读取新四档', (tester) async {
    await tester.pumpWidget(_app(animate: true));
    await tester.pump();
    final before = [for (var row = 0; row < 3; row++) _rowAmounts(tester, row)];
    final positions = [
      for (var row = 0; row < 3; row++)
        tester.getTopLeft(find.byKey(ValueKey('pcPigBarrageTrack$row'))),
    ];

    await tester.pump(const Duration(milliseconds: 250));
    for (var row = 0; row < 3; row++) {
      expect(_rowAmounts(tester, row), before[row]);
      final after = tester.getTopLeft(
        find.byKey(ValueKey('pcPigBarrageTrack$row')),
      );
      expect(after.dx, lessThan(positions[row].dx));
      expect(after.dy, positions[row].dy);
    }

    const remote = [510, 620, 730, 840];
    await PCNumberHelpers().pc_applyRemoteConfig(
      jsonEncode({'eq_range': remote}),
    );
    await tester.pumpWidget(_app(animate: true));
    tester.element(find.byType(PCPigBarrage)).markNeedsBuild();
    await tester.pump();
    for (var row = 0; row < 3; row++) {
      expect(_rowAmounts(tester, row), before[row]);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app());
    await tester.pump();
    _expectPayoutAmounts(tester, remote);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
